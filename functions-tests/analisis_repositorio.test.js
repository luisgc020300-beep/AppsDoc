// functions-tests/analisis_repositorio.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const tar = require('tar-stream');
const zlib = require('zlib');
const {
  _esArchivoIrrelevante,
  _priorizarArchivos,
  _listarEntradasTar,
  _extraerContenidoTar,
  _construirPromptAnalisis,
  _parsearAnalisisRepositorio,
} = require('../functions/index.js');

function codigoDe(fn) {
  try {
    fn();
    return null;
  } catch (e) {
    return e.code;
  }
}

// ---------------------------------------------------------------------------
// _esArchivoIrrelevante / _priorizarArchivos -- puras, sin tar ni red.
// ---------------------------------------------------------------------------

test('_esArchivoIrrelevante descarta directorios de dependencias/builds', () => {
  assert.equal(_esArchivoIrrelevante('node_modules/foo/index.js'), true);
  assert.equal(_esArchivoIrrelevante('apps/pro/node_modules/bar.js'), true);
  assert.equal(_esArchivoIrrelevante('.git/HEAD'), true);
  assert.equal(_esArchivoIrrelevante('build/app/outputs/apk/app.apk'), true);
  assert.equal(_esArchivoIrrelevante('lib/main.dart'), false);
});

test('_esArchivoIrrelevante descarta extensiones binarias', () => {
  assert.equal(_esArchivoIrrelevante('assets/icon.png'), true);
  assert.equal(_esArchivoIrrelevante('fonts/Inter.ttf'), true);
  assert.equal(_esArchivoIrrelevante('lib/widgets/boton.dart'), false);
});

test('_esArchivoIrrelevante descarta lockfiles aunque no terminen en una extensión del denylist', () => {
  assert.equal(_esArchivoIrrelevante('package-lock.json'), true);
  assert.equal(_esArchivoIrrelevante('pubspec.lock'), true);
  assert.equal(_esArchivoIrrelevante('package.json'), false);
});

test('_esArchivoIrrelevante nunca deja pasar secretos ni credenciales', () => {
  assert.equal(_esArchivoIrrelevante('.env'), true);
  assert.equal(_esArchivoIrrelevante('.env.production'), true);
  assert.equal(_esArchivoIrrelevante('android/app/google-services.json'), true);
  assert.equal(_esArchivoIrrelevante('lib/firebase_options.dart'), true);
  assert.equal(_esArchivoIrrelevante('config/credentials.json'), true);
  assert.equal(_esArchivoIrrelevante('scripts/deploy_secret.sh'), true);
  assert.equal(_esArchivoIrrelevante('android/release.keystore'), true);
});

test('_priorizarArchivos antepone README/pubspec.yaml/package.json al resto y recorta al máximo', () => {
  const rutas = ['lib/a.dart', 'lib/b.dart', 'README.md', 'lib/c.dart', 'pubspec.yaml'];
  const resultado = _priorizarArchivos(rutas, 3);

  assert.equal(resultado.length, 3);
  assert.ok(resultado.includes('README.md'));
  assert.ok(resultado.includes('pubspec.yaml'));
});

test('_priorizarArchivos no trata como ancla un README anidado en profundidad', () => {
  const rutas = ['ejemplos/demo/sub/README.md', 'lib/main.dart'];
  const resultado = _priorizarArchivos(rutas, 2);

  // Ninguno es ancla real (el README está a 3 niveles) -- se conserva el
  // orden original, no se reordena.
  assert.deepEqual(resultado, rutas);
});

// ---------------------------------------------------------------------------
// _listarEntradasTar / _extraerContenidoTar -- requieren un tarball real,
// pero generado en memoria (sin red, sin GitHub).
// ---------------------------------------------------------------------------

function construirTarballDePrueba(archivos) {
  return new Promise((resolve, reject) => {
    const pack = tar.pack();
    for (const a of archivos) pack.entry({ name: a.name }, a.content);
    pack.finalize();

    const gzip = zlib.createGzip();
    const trozos = [];
    pack.pipe(gzip);
    gzip.on('data', (c) => trozos.push(c));
    gzip.on('end', () => resolve(Buffer.concat(trozos)));
    gzip.on('error', reject);
  });
}

test('_listarEntradasTar quita el prefijo owner-repo-sha/ de cada ruta', async () => {
  const buffer = await construirTarballDePrueba([
    { name: 'owner-repo-abc123/README.md', content: '# Hola' },
    { name: 'owner-repo-abc123/lib/main.dart', content: 'void main() {}' },
  ]);

  const entradas = await _listarEntradasTar(buffer);

  assert.deepEqual(
    entradas.map((e) => e.path).sort(),
    ['README.md', 'lib/main.dart'].sort(),
  );
});

test('_extraerContenidoTar solo lee el contenido de las rutas pedidas', async () => {
  const buffer = await construirTarballDePrueba([
    { name: 'repo-x/README.md', content: '# Proyecto de prueba' },
    { name: 'repo-x/node_modules/paquete/index.js', content: 'ruido que no debe leerse' },
    { name: 'repo-x/lib/main.dart', content: 'void main() {}' },
  ]);

  const contenidos = await _extraerContenidoTar(buffer, ['README.md', 'lib/main.dart'], 100000);

  assert.equal(contenidos.size, 2);
  assert.equal(contenidos.get('README.md'), '# Proyecto de prueba');
  assert.equal(contenidos.get('lib/main.dart'), 'void main() {}');
  assert.equal(contenidos.has('node_modules/paquete/index.js'), false);
});

test('_extraerContenidoTar trunca un archivo que supera el máximo por archivo', async () => {
  const contenidoLargo = 'a'.repeat(25000);
  const buffer = await construirTarballDePrueba([{ name: 'repo-x/lib/grande.dart', content: contenidoLargo }]);

  const contenidos = await _extraerContenidoTar(buffer, ['lib/grande.dart'], 100000);

  const resultado = contenidos.get('lib/grande.dart');
  assert.ok(resultado.length < contenidoLargo.length);
  assert.ok(resultado.endsWith('(truncado)'));
});

test('_extraerContenidoTar deja de capturar contenido una vez agotado el presupuesto total', async () => {
  const buffer = await construirTarballDePrueba([
    { name: 'repo-x/a.dart', content: 'x'.repeat(50) },
    { name: 'repo-x/b.dart', content: 'y'.repeat(50) },
    { name: 'repo-x/c.dart', content: 'z'.repeat(50) },
  ]);

  const contenidos = await _extraerContenidoTar(buffer, ['a.dart', 'b.dart', 'c.dart'], 60);

  // La comprobación de presupuesto es "antes de empezar cada archivo", no
  // una previsión de cuánto va a añadir -- con presupuesto 60 y archivos
  // de 50, entran a y b (0<60 y 50<60), y en ese punto el acumulado (100)
  // ya supera el presupuesto, así que c se descarta.
  assert.equal(contenidos.size, 2);
  assert.ok(contenidos.has('a.dart'));
  assert.ok(contenidos.has('b.dart'));
  assert.equal(contenidos.has('c.dart'), false);
});

// ---------------------------------------------------------------------------
// _construirPromptAnalisis -- pura.
// ---------------------------------------------------------------------------

test('_construirPromptAnalisis incluye árbol, contenido y lo ya registrado', () => {
  const prompt = _construirPromptAnalisis({
    proyecto: { nombre: 'REPARA' },
    rutasArbol: ['README.md', 'lib/main.dart'],
    archivosConContenido: new Map([['README.md', '# REPARA']]),
    funcionalidadesExistentes: ['Login'],
    documentosExistentes: ['Arquitectura general'],
    tareasExistentes: ['Escribir tests'],
    analisisAnterior: null,
  });

  assert.match(prompt, /Repositorio del proyecto "REPARA"/);
  assert.match(prompt, /- README\.md/);
  assert.match(prompt, /--- README\.md ---\n# REPARA/);
  assert.match(prompt, /- Login/);
  assert.match(prompt, /- Arquitectura general/);
  assert.match(prompt, /- Escribir tests/);
});

test('_construirPromptAnalisis incluye el análisis anterior cuando se le pasa', () => {
  const prompt = _construirPromptAnalisis({
    proyecto: { nombre: 'REPARA' },
    rutasArbol: [],
    archivosConContenido: new Map(),
    funcionalidadesExistentes: [],
    documentosExistentes: [],
    tareasExistentes: [],
    analisisAnterior: 'Resumen del análisis previo.',
  });

  assert.match(prompt, /análisis automático anterior/i);
  assert.match(prompt, /Resumen del análisis previo\./);
});

// ---------------------------------------------------------------------------
// _parsearAnalisisRepositorio -- pura, incluida la deduplicación.
// ---------------------------------------------------------------------------

function bloqueHerramienta(input) {
  return [{ type: 'tool_use', name: 'registrar_analisis_repositorio', input }];
}

function analisisCanon(overrides = {}) {
  return {
    resumen: 'Es una app Flutter de gestión de proyectos.',
    arquitecturaDetectada: 'App Flutter con Firebase.',
    tecnologias: ['Flutter', 'Dart', 'Firebase'],
    documentos: [{ titulo: 'Arquitectura', categoria: 'arquitectura', contenido: '# Arquitectura' }],
    funcionalidades: [
      { nombre: 'Login', descripcion: 'Email y contraseña', estadoSugerido: 'completada', confianza: 'alta', evidencia: 'lib/login.dart' },
    ],
    hallazgos: [{ titulo: 'Falta manejo de errores', descripcion: '', gravedad: 'media' }],
    tareas: [{ titulo: 'Añadir tests', descripcion: '' }],
    ideas: [{ titulo: 'Modo offline', descripcion: '' }],
    ...overrides,
  };
}

test('_parsearAnalisisRepositorio extrae todas las secciones', () => {
  const r = _parsearAnalisisRepositorio(bloqueHerramienta(analisisCanon()));

  assert.equal(r.resumen, 'Es una app Flutter de gestión de proyectos.');
  assert.equal(r.arquitecturaDetectada, 'App Flutter con Firebase.');
  assert.deepEqual(r.tecnologias, ['Flutter', 'Dart', 'Firebase']);
  assert.equal(r.documentos.length, 1);
  assert.equal(r.funcionalidades.length, 1);
  assert.equal(r.funcionalidades[0].estadoSugerido, 'completada');
  assert.equal(r.hallazgos.length, 1);
  assert.equal(r.tareas.length, 1);
  assert.equal(r.ideas.length, 1);
});

test('_parsearAnalisisRepositorio descarta funcionalidades/documentos/tareas que ya existen (comparación insensible a mayúsculas y espacios)', () => {
  const r = _parsearAnalisisRepositorio(bloqueHerramienta(analisisCanon()), {
    funcionalidadesExistentes: ['  login  '],
    documentosExistentes: ['ARQUITECTURA'],
    tareasExistentes: ['añadir tests'],
  });

  assert.equal(r.funcionalidades.length, 0);
  assert.equal(r.documentos.length, 0);
  assert.equal(r.tareas.length, 0);
  // Los hallazgos e ideas no se deduplican contra esas listas (no tienen
  // equivalente "ya registrado" comparable por título de la misma forma).
  assert.equal(r.hallazgos.length, 1);
  assert.equal(r.ideas.length, 1);
});

test('_parsearAnalisisRepositorio nunca inventa un estadoSugerido fuera del enum', () => {
  const r = _parsearAnalisisRepositorio(
    bloqueHerramienta(
      analisisCanon({
        funcionalidades: [
          { nombre: 'X', estadoSugerido: 'terminadisima', confianza: 'extrema', evidencia: '' },
        ],
      }),
    ),
  );

  assert.equal(r.funcionalidades[0].estadoSugerido, 'planificada');
  assert.equal(r.funcionalidades[0].confianza, 'baja');
});

test('_parsearAnalisisRepositorio sin resumen lanza internal', () => {
  assert.equal(
    codigoDe(() => _parsearAnalisisRepositorio(bloqueHerramienta(analisisCanon({ resumen: '  ' })))),
    'internal',
  );
});

test('_parsearAnalisisRepositorio sin el bloque de la herramienta lanza internal', () => {
  assert.equal(codigoDe(() => _parsearAnalisisRepositorio([{ type: 'text', text: 'respuesta libre' }])), 'internal');
});
