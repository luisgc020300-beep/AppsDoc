// functions-tests/expediente.test.js
// Fase 10: expediente integral -- funciones puras del pipeline por etapas.
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  _agruparPorModulo,
  _elegirModulosAProcesar,
  _construirPromptModulo,
  _parsearAnalisisModulo,
  _construirPromptSintesis,
  _parsearExpediente,
} = require('../functions/index.js');

function codigoDe(fn) {
  try {
    fn();
    return null;
  } catch (e) {
    return e.code;
  }
}

test('_agruparPorModulo: clasifica pantallas, servicios y modelos por carpeta de lib/', () => {
  const grupos = _agruparPorModulo([
    'lib/screens/proyectos/proyecto_detail_screen.dart',
    'lib/pestañas/inicio_tab.dart',
    'lib/services/proyecto_service.dart',
    'lib/models/proyecto.dart',
  ]);
  assert.deepEqual(grupos.pantallas, ['lib/screens/proyectos/proyecto_detail_screen.dart', 'lib/pestañas/inicio_tab.dart']);
  assert.deepEqual(grupos.servicios, ['lib/services/proyecto_service.dart']);
  assert.deepEqual(grupos.modelos, ['lib/models/proyecto.dart']);
});

test('_agruparPorModulo: clasifica backend, tests, documentación y configuración', () => {
  const grupos = _agruparPorModulo([
    'functions/index.js',
    'test/models/proyecto_test.dart',
    'functions-tests/limite.test.js',
    'README.md',
    'docs/arquitectura.md',
    'pubspec.yaml',
    'firebase.json',
  ]);
  assert.deepEqual(grupos.backend, ['functions/index.js']);
  assert.deepEqual(grupos.tests, ['test/models/proyecto_test.dart', 'functions-tests/limite.test.js']);
  assert.deepEqual(grupos.documentacion, ['README.md', 'docs/arquitectura.md']);
  assert.deepEqual(grupos.configuracion, ['pubspec.yaml', 'firebase.json']);
});

test('_agruparPorModulo: una ruta que no encaja en ningún módulo conocido cae en "otros"', () => {
  const grupos = _agruparPorModulo(['assets/icon/app_icon.png', 'android/app/src/main/AndroidManifest.xml']);
  assert.deepEqual(grupos.otros, ['assets/icon/app_icon.png', 'android/app/src/main/AndroidManifest.xml']);
});

test('_agruparPorModulo: lista vacía devuelve todos los grupos vacíos', () => {
  const grupos = _agruparPorModulo([]);
  for (const clave of Object.keys(grupos)) {
    assert.deepEqual(grupos[clave], [], `el grupo "${clave}" debería estar vacío`);
  }
});

test('_agruparPorModulo: invariante -- toda ruta de entrada aparece en exactamente un grupo, nunca se descarta', () => {
  const rutas = [
    'lib/screens/a.dart',
    'lib/services/b.dart',
    'lib/models/c.dart',
    'functions/index.js',
    'test/d_test.dart',
    'README.md',
    'pubspec.yaml',
    'assets/img.png',
  ];
  const grupos = _agruparPorModulo(rutas);
  const todasLasClasificadas = Object.values(grupos).flat();
  assert.equal(todasLasClasificadas.length, rutas.length);
  for (const ruta of rutas) {
    assert.ok(todasLasClasificadas.includes(ruta), `"${ruta}" debería aparecer clasificada en algún grupo`);
  }
});

test('_agruparPorModulo: no filtra nada por su cuenta -- un nombre de archivo sensible que ya debería haberse filtrado antes sigue clasificándose, no se elimina aquí', () => {
  // Esto confirma el invariante de diseño: el filtrado de _esArchivoIrrelevante
  // ocurre UNA sola vez, antes de llamar a _agruparPorModulo. Esta función no
  // vuelve a comprobar el denylist -- si algo sensible llega hasta aquí, es un
  // fallo en el llamador, no algo que _agruparPorModulo deba corregir.
  const grupos = _agruparPorModulo(['lib/config/.env']);
  const todas = Object.values(grupos).flat();
  assert.deepEqual(todas, ['lib/config/.env']);
});

test('_agruparPorModulo: reconoce pantallas/servicios/modelos aunque no estén en la raíz del repo (monorepo real, p.ej. packages/ui_core/lib/screens/x.dart)', () => {
  const grupos = _agruparPorModulo([
    'packages/repara_ui/lib/screens/login_screen.dart',
    'packages/repara_core/lib/services/pago_service.dart',
    'apps/repara_hogar/lib/models/vivienda.dart',
  ]);
  assert.deepEqual(grupos.pantallas, ['packages/repara_ui/lib/screens/login_screen.dart']);
  assert.deepEqual(grupos.servicios, ['packages/repara_core/lib/services/pago_service.dart']);
  assert.deepEqual(grupos.modelos, ['apps/repara_hogar/lib/models/vivienda.dart']);
});

test('_agruparPorModulo: un archivo de test dentro de una carpeta "models" se clasifica como test, no como modelo', () => {
  // test/models/proyecto_test.dart tiene "models" como segmento de ruta,
  // pero es inequívocamente un test -- la detección de test debe ganar.
  const grupos = _agruparPorModulo(['test/models/proyecto_test.dart']);
  assert.deepEqual(grupos.tests, ['test/models/proyecto_test.dart']);
  assert.deepEqual(grupos.modelos, []);
});

test('_elegirModulosAProcesar: usa los módulos con nombre que tengan contenido', () => {
  const grupos = { pantallas: ['a.dart'], servicios: [], modelos: ['b.dart'], backend: [], configuracion: [], documentacion: [], tests: ['c.dart'], otros: ['d.dart'] };
  assert.deepEqual(_elegirModulosAProcesar(grupos), ['pantallas', 'modelos']);
});

test('_elegirModulosAProcesar: si ningún módulo con nombre tiene contenido, cae a "otros" como último recurso', () => {
  const grupos = { pantallas: [], servicios: [], modelos: [], backend: [], configuracion: [], documentacion: [], tests: [], otros: ['raro.xyz'] };
  assert.deepEqual(_elegirModulosAProcesar(grupos), ['otros']);
});

test('_elegirModulosAProcesar: si no hay absolutamente nada, devuelve una lista vacía', () => {
  const grupos = { pantallas: [], servicios: [], modelos: [], backend: [], configuracion: [], documentacion: [], tests: [], otros: [] };
  assert.deepEqual(_elegirModulosAProcesar(grupos), []);
});

// ---------------------------------------------------------------------------
// _construirPromptModulo / _parsearAnalisisModulo -- puras.
// ---------------------------------------------------------------------------

test('_construirPromptModulo incluye el nombre del módulo y el contenido de sus archivos', () => {
  const prompt = _construirPromptModulo({
    nombreModulo: 'pantallas',
    archivosConContenido: new Map([['lib/screens/login_screen.dart', 'class LoginScreen {}']]),
  });

  assert.match(prompt, /Módulo "pantallas"/);
  assert.match(prompt, /--- lib\/screens\/login_screen\.dart ---\nclass LoginScreen \{\}/);
});

test('_construirPromptModulo sin archivos con contenido lo indica explícitamente', () => {
  const prompt = _construirPromptModulo({ nombreModulo: 'backend', archivosConContenido: new Map() });
  assert.match(prompt, /no se pudo leer contenido/i);
});

function bloqueModulo(input) {
  return [{ type: 'tool_use', name: 'registrar_analisis_modulo', input }];
}

test('_parsearAnalisisModulo extrae resumen, elementos y tecnologías', () => {
  const r = _parsearAnalisisModulo(
    bloqueModulo({
      resumenModulo: 'Pantallas de autenticación y perfil.',
      elementosDetectados: [{ nombre: 'LoginScreen', descripcion: 'Email y contraseña', tipo: 'pantalla', evidencia: 'lib/screens/login_screen.dart' }],
      tecnologiasDetectadas: ['Flutter'],
    }),
  );

  assert.equal(r.resumenModulo, 'Pantallas de autenticación y perfil.');
  assert.equal(r.elementosDetectados.length, 1);
  assert.equal(r.elementosDetectados[0].tipo, 'pantalla');
  assert.deepEqual(r.tecnologiasDetectadas, ['Flutter']);
});

test('_parsearAnalisisModulo descarta elementos sin nombre y trata listas ausentes como vacías', () => {
  const r = _parsearAnalisisModulo(
    bloqueModulo({ resumenModulo: 'X', elementosDetectados: [{ descripcion: 'sin nombre' }] }),
  );
  assert.deepEqual(r.elementosDetectados, []);
  assert.deepEqual(r.tecnologiasDetectadas, []);
});

test('_parsearAnalisisModulo sin el bloque de la herramienta lanza internal', () => {
  assert.equal(codigoDe(() => _parsearAnalisisModulo([{ type: 'text', text: 'respuesta libre' }])), 'internal');
});

// ---------------------------------------------------------------------------
// _construirPromptSintesis -- pura.
// ---------------------------------------------------------------------------

test('_construirPromptSintesis incluye los resúmenes de módulo condensados, nunca contenido crudo de archivo', () => {
  const prompt = _construirPromptSintesis({
    proyecto: { nombre: 'REPARA' },
    resumenesPorModulo: {
      pantallas: {
        resumenModulo: 'Pantallas de autenticación.',
        elementosDetectados: [{ nombre: 'LoginScreen', descripcion: 'Login', tipo: 'pantalla', evidencia: 'lib/screens/login_screen.dart' }],
        tecnologiasDetectadas: ['Flutter'],
      },
    },
    funcionalidadesExistentes: ['Login'],
    documentosExistentes: ['Arquitectura general'],
    progresoPorcentaje: 45,
    expedienteAnterior: null,
  });

  assert.match(prompt, /Síntesis del proyecto "REPARA"/);
  assert.match(prompt, /Módulo: pantallas/);
  assert.match(prompt, /Pantallas de autenticación\./);
  assert.match(prompt, /LoginScreen/);
  assert.match(prompt, /- Login/);
  assert.match(prompt, /- Arquitectura general/);
  assert.match(prompt, /45%/);
  // Nunca debe colarse el "--- ruta ---" que usa _construirPromptModulo para
  // volcar contenido crudo de archivo -- la síntesis solo ve lo condensado.
  assert.doesNotMatch(prompt, /---\s*lib\//);
});

test('_construirPromptSintesis incluye el expediente anterior cuando se le pasa', () => {
  const prompt = _construirPromptSintesis({
    proyecto: { nombre: 'REPARA' },
    resumenesPorModulo: {},
    funcionalidadesExistentes: [],
    documentosExistentes: [],
    progresoPorcentaje: 0,
    expedienteAnterior: 'Resumen del expediente confirmado anterior.',
  });

  assert.match(prompt, /expediente confirmado anterior/i);
  assert.match(prompt, /Resumen del expediente confirmado anterior\./);
});

// ---------------------------------------------------------------------------
// _parsearExpediente -- pura, con clamp conservador de cada enum.
// ---------------------------------------------------------------------------

function bloqueExpediente(input) {
  return [{ type: 'tool_use', name: 'registrar_expediente', input }];
}

function expedienteCanon(overrides = {}) {
  return {
    descripcionGeneral: {
      resumen: 'App Flutter de gestión de proyectos personales.',
      propuestaValor: 'Centraliza toda la documentación técnica en un sitio.',
      publicoObjetivo: 'Desarrolladores independientes.',
      estadoMadurez: 'en desarrollo activo',
    },
    pantallas: [
      {
        nombre: 'Detalle de proyecto',
        descripcionFuncion: 'Muestra toda la información de un proyecto.',
        archivoPrincipal: 'lib/screens/proyectos/proyecto_detail_screen.dart',
        navegacion: 'Se accede desde el listado de proyectos.',
        pantallasRelacionadas: ['Listado de proyectos'],
      },
    ],
    catalogoFuncionalidades: [
      { nombre: 'Login', descripcion: 'Email y contraseña', confianza: 'verificada', evidencia: 'lib/screens/auth/login_screen.dart', archivosRelacionados: [] },
    ],
    arquitectura: { resumen: 'Flutter + Firebase.', patrones: ['Servicios estáticos'], tecnologias: ['Flutter', 'Firebase'] },
    calidad: { resumen: 'Código razonablemente organizado.', hallazgos: [{ titulo: 'Duplicidad en X', descripcion: '', gravedad: 'media', evidencia: 'lib/x.dart' }] },
    seguridad: { resumen: 'Sin problemas confirmados; no se auditó exhaustivamente.', hallazgos: [] },
    valoracionEconomica: {
      conservador: { costeDesarrolloEstimado: 5000, costeReconstruccionEstimado: 4000, valorProductoEstimado: 3000, moneda: 'EUR', razonamiento: 'Alcance reducido.' },
      intermedio: { costeDesarrolloEstimado: 10000, costeReconstruccionEstimado: 8000, valorProductoEstimado: 7000, moneda: 'EUR', razonamiento: 'Escenario medio.' },
      optimista: { costeDesarrolloEstimado: 20000, costeReconstruccionEstimado: 15000, valorProductoEstimado: 15000, moneda: 'EUR', razonamiento: 'Con tracción real.' },
      supuestos: ['Tarifa de mercado media de un desarrollador freelance.'],
      limitaciones: 'No se dispone de datos de mercado reales.',
      nivelConfianza: 'media',
    },
    potencialUsuarios: {
      conservador: { usuariosEstimados: 50, razonamiento: 'Solo el propio equipo.' },
      intermedio: { usuariosEstimados: 500, razonamiento: 'Adopción moderada.' },
      optimista: { usuariosEstimados: 5000, razonamiento: 'Con marketing dedicado.' },
      segmentoObjetivo: 'Desarrolladores independientes.',
      supuestos: ['Sin competencia directa con gamificación.'],
      limitaciones: 'Estimación especulativa, sin datos de demanda real.',
      nivelConfianza: 'baja',
    },
    analisisProgresoValor: 'El progreso es moderado; el valor comercial depende más de la demanda que del progreso técnico.',
    ...overrides,
  };
}

test('_parsearExpediente extrae todas las secciones', () => {
  const r = _parsearExpediente(bloqueExpediente(expedienteCanon()), { progresoPorcentaje: 45 });

  assert.equal(r.descripcionGeneral.resumen, 'App Flutter de gestión de proyectos personales.');
  assert.equal(r.pantallas.length, 1);
  assert.equal(r.catalogoFuncionalidades.length, 1);
  assert.equal(r.catalogoFuncionalidades[0].confianza, 'verificada');
  assert.equal(r.arquitectura.tecnologias.length, 2);
  assert.equal(r.calidad.hallazgos.length, 1);
  assert.equal(r.seguridad.hallazgos.length, 0);
  assert.equal(r.valoracionEconomica.conservador.costeDesarrolloEstimado, 5000);
  assert.equal(r.valoracionEconomica.nivelConfianza, 'media');
  assert.equal(r.potencialUsuarios.optimista.usuariosEstimados, 5000);
  assert.equal(r.potencialUsuarios.nivelConfianza, 'baja');
  // El porcentaje de progreso lo inyecta el backend, nunca se confía en que
  // la IA lo repita correctamente -- viene del segundo argumento, no de `input`.
  assert.equal(r.progresoValor.progresoPorcentajeLeido, 45);
  assert.match(r.progresoValor.analisisTexto, /El progreso es moderado/);
});

test('_parsearExpediente clampa una confianza de funcionalidad desconocida a "pendiente"', () => {
  const r = _parsearExpediente(
    bloqueExpediente(
      expedienteCanon({
        catalogoFuncionalidades: [{ nombre: 'X', confianza: 'inventada', evidencia: '' }],
      }),
    ),
  );
  assert.equal(r.catalogoFuncionalidades[0].confianza, 'pendiente');
});

test('_parsearExpediente clampa una gravedad de hallazgo desconocida a "media"', () => {
  const r = _parsearExpediente(
    bloqueExpediente(expedienteCanon({ calidad: { resumen: '', hallazgos: [{ titulo: 'X', gravedad: 'catastrofica', evidencia: '' }] } })),
  );
  assert.equal(r.calidad.hallazgos[0].gravedad, 'media');
});

test('_parsearExpediente clampa un nivelConfianza desconocido a "baja" tanto en valoración económica como en potencial de usuarios', () => {
  const r = _parsearExpediente(
    bloqueExpediente(
      expedienteCanon({
        valoracionEconomica: { ...expedienteCanon().valoracionEconomica, nivelConfianza: 'altisima' },
        potencialUsuarios: { ...expedienteCanon().potencialUsuarios, nivelConfianza: 'desconocida' },
      }),
    ),
  );
  assert.equal(r.valoracionEconomica.nivelConfianza, 'baja');
  assert.equal(r.potencialUsuarios.nivelConfianza, 'baja');
});

test('_parsearExpediente sin descripción general (resumen vacío) lanza internal', () => {
  assert.equal(
    codigoDe(() =>
      _parsearExpediente(bloqueExpediente(expedienteCanon({ descripcionGeneral: { ...expedienteCanon().descripcionGeneral, resumen: '  ' } }))),
    ),
    'internal',
  );
});

test('_parsearExpediente sin el bloque de la herramienta lanza internal', () => {
  assert.equal(codigoDe(() => _parsearExpediente([{ type: 'text', text: 'respuesta libre' }])), 'internal');
});
