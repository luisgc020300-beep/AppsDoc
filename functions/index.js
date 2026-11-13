// functions/index.js
//
// Backend de IA de AppsDoc (Fase 7): dos Cloud Functions callable que
// proxean a la API de Anthropic. La clave de Anthropic vive solo en
// Secret Manager (_anthropicKey) -- nunca llega al cliente Flutter, mismo
// patrón que generarPlanIA/jarvisChat en RiskRunner.
//
// Ninguna de las dos escribe en Firestore salvo el propio contador de uso
// diario: ambas PROPONEN (responden con texto o con una extracción
// estructurada), el cliente es quien decide confirmar y persistir con los
// servicios ya existentes (AuditoriaService/TareaService), que ya dejan su
// propio rastro en el historial -- por eso aquí no hace falta volver a
// escribir historial ("No modificar datos automáticamente sin
// confirmación", pedido explícito de esta fase).
//
// Las funciones puras (prefijo "_") están exportadas para poder testearlas
// directamente desde functions-tests/ sin depender del Emulator Suite --
// mismo criterio que ProgresoService en el cliente Flutter: separar
// cálculo puro de I/O (Firestore, fetch a Anthropic).
'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const tar = require('tar-stream');
const zlib = require('zlib');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const _anthropicKey = defineSecret('ANTHROPIC_API_KEY');
const REGION = 'europe-west1';
const MODELO = 'claude-sonnet-5-5';
// Overridable solo para que functions-tests pueda apuntar a un servidor de
// prueba en vez de a la Anthropic real -- en producción siempre es la URL
// por defecto.
const ANTHROPIC_API_URL = `${process.env.ANTHROPIC_API_URL_BASE || 'https://api.anthropic.com'}/v1/messages`;
// Overridable para poder probar el límite con un tope bajo sin tocar el
// valor real de producción.
const LIMITE_DIARIO = Number(process.env.APPSDOC_LIMITE_DIARIO_IA) || 40;

// ---------------------------------------------------------------------------
// Validación de entrada -- pura, sin I/O.
// ---------------------------------------------------------------------------

function _validarPreguntaInput(data) {
  const proyectoId = data && data.proyectoId;
  const pregunta = data && data.pregunta;
  if (typeof proyectoId !== 'string' || proyectoId.trim() === '') {
    throw new HttpsError('invalid-argument', 'Falta el identificador del proyecto.');
  }
  if (typeof pregunta !== 'string' || pregunta.trim() === '') {
    throw new HttpsError('invalid-argument', 'La pregunta no puede estar vacía.');
  }
  if (pregunta.trim().length > 4000) {
    throw new HttpsError('invalid-argument', 'La pregunta es demasiado larga (máx. 4000 caracteres).');
  }
  const githubResumen =
    data.githubResumen && typeof data.githubResumen === 'object' && !Array.isArray(data.githubResumen)
      ? data.githubResumen
      : null;
  return { proyectoId: proyectoId.trim(), pregunta: pregunta.trim(), githubResumen };
}

function _validarExtraccionInput(data) {
  const proyectoId = data && data.proyectoId;
  const texto = data && data.texto;
  if (typeof proyectoId !== 'string' || proyectoId.trim() === '') {
    throw new HttpsError('invalid-argument', 'Falta el identificador del proyecto.');
  }
  if (typeof texto !== 'string' || texto.trim() === '') {
    throw new HttpsError('invalid-argument', 'El texto pegado no puede estar vacío.');
  }
  if (texto.trim().length > 20000) {
    throw new HttpsError('invalid-argument', 'El texto pegado es demasiado largo (máx. 20000 caracteres).');
  }
  return { proyectoId: proyectoId.trim(), texto: texto.trim() };
}

// ---------------------------------------------------------------------------
// Límite de uso diario. _evaluarLimite() es la decisión pura; la
// transacción de Firestore que la envuelve es la única parte con I/O.
// ---------------------------------------------------------------------------

// `peso` deja que una operación mucho más cara que una pregunta suelta (p.ej.
// generarExpediente, con varias llamadas a Anthropic dentro) consuma más de
// una unidad de la cuota diaria compartida. Por defecto 1, así que las
// llamadas existentes (sin tercer argumento) se comportan exactamente igual
// que antes: actual>=limiteDiario con +1 es lo mismo que actual+1>limiteDiario.
function _evaluarLimite(peticionesHoy, limiteDiario, peso = 1) {
  const actual = typeof peticionesHoy === 'number' ? peticionesHoy : 0;
  if (actual + peso > limiteDiario) {
    return { permitido: false, nuevoContador: actual };
  }
  return { permitido: true, nuevoContador: actual + peso };
}

async function _comprobarYRegistrarUso(uid, hoyISO, peso = 1) {
  const ref = db.collection('usuarios').doc(uid).collection('usoIA').doc(hoyISO);
  const permitido = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const decision = _evaluarLimite(snap.exists ? snap.data().peticiones : 0, LIMITE_DIARIO, peso);
    if (decision.permitido) tx.set(ref, { peticiones: decision.nuevoContador }, { merge: true });
    return decision.permitido;
  });
  if (!permitido) {
    throw new HttpsError('resource-exhausted', `Límite diario de ${LIMITE_DIARIO} peticiones a la IA alcanzado. Inténtalo de nuevo mañana.`);
  }
}

// ---------------------------------------------------------------------------
// Contexto del proyecto. _construirContexto() es pura: recibe los datos ya
// leídos de Firestore como objetos planos (fechas ya convertidas a ISO) y
// devuelve el bloque de texto para el system prompt -- testeable con
// listas en memoria, sin tocar Firestore.
// ---------------------------------------------------------------------------

function _construirContexto({ proyecto, funcionalidades, documentos, tareas, ideas, auditorias, historial, githubResumen }) {
  const lineas = [];
  lineas.push(`Proyecto: ${proyecto.nombre}`);
  if (proyecto.descripcion) lineas.push(`Descripción: ${proyecto.descripcion}`);
  lineas.push(`Estado: ${proyecto.estado}`);
  lineas.push(`Progreso hacia publicar: ${proyecto.progresoPorcentaje}%`);

  lineas.push('', '## Funcionalidades');
  lineas.push(
    funcionalidades.length
      ? funcionalidades.map((f) => `- [${f.estado}] ${f.nombre}${f.descripcion ? `: ${f.descripcion}` : ''}`).join('\n')
      : '(ninguna todavía)',
  );

  lineas.push('', '## Documentación');
  lineas.push(
    documentos.length
      ? documentos
          .map((d) => {
            const contenido = (d.contenido || '').slice(0, 500);
            const truncado = (d.contenido || '').length > 500 ? '…' : '';
            return `- [${d.categoria}] ${d.titulo}${contenido ? `: ${contenido}${truncado}` : ''}`;
          })
          .join('\n')
      : '(ninguna todavía)',
  );

  lineas.push('', '## Tareas');
  lineas.push(
    tareas.length
      ? tareas
          .map((t) => `- [${t.estado}][prioridad ${t.prioridad}] ${t.titulo}${t.fechaLimite ? ` (vence: ${t.fechaLimite})` : ''}`)
          .join('\n')
      : '(ninguna todavía)',
  );

  lineas.push('', '## Ideas');
  lineas.push(
    ideas.length
      ? ideas.map((i) => `- [${i.estado}] ${i.titulo}${i.descripcion ? `: ${i.descripcion}` : ''}`).join('\n')
      : '(ninguna todavía)',
  );

  lineas.push('', '## Auditorías y hallazgos');
  if (auditorias.length) {
    for (const a of auditorias) {
      lineas.push(`- ${a.fecha} [${a.origen}] resultado: ${a.resultado} -- ${a.resumen}`);
      for (const h of a.hallazgos || []) {
        lineas.push(`    · [${h.gravedad}][${h.estado}] ${h.titulo}${h.descripcion ? `: ${h.descripcion}` : ''}`);
      }
    }
  } else {
    lineas.push('(ninguna todavía)');
  }

  lineas.push('', '## Historial reciente');
  lineas.push(
    historial.length
      ? historial.map((e) => `- ${e.fecha} [${e.entidad}] ${e.descripcion}`).join('\n')
      : '(sin actividad todavía)',
  );

  lineas.push('', '## Repositorio de GitHub');
  lineas.push(
    githubResumen
      ? `Rama principal: ${githubResumen.ramaPrincipal}. Último commit: "${githubResumen.ultimoCommitMensaje}" (${githubResumen.ultimoCommitFecha}). Actualizado: ${githubResumen.actualizadoEn}.`
      : '(sin repositorio conectado, o sin datos disponibles en este momento)',
  );

  return lineas.join('\n');
}

function _fechaISO(timestamp) {
  return timestamp && typeof timestamp.toDate === 'function' ? timestamp.toDate().toISOString() : null;
}

/// Lee las seis subcolecciones de un proyecto bajo el uid del que llama
/// (nunca un uid distinto -- esa es la comprobación de propiedad: no hay
/// forma de que esta ruta devuelva datos de otro usuario) y construye el
/// bloque de contexto. Lanza 'not-found' si el proyecto no existe.
async function _leerContextoProyecto(uid, proyectoId, githubResumen) {
  const proyectoRef = db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId);
  const proyectoSnap = await proyectoRef.get();
  if (!proyectoSnap.exists) {
    throw new HttpsError('not-found', 'El proyecto no existe.');
  }
  const p = proyectoSnap.data();

  const [funcSnap, docSnap, tareaSnap, ideaSnap, audSnap, histSnap] = await Promise.all([
    proyectoRef.collection('funcionalidades').get(),
    proyectoRef.collection('documentos').get(),
    proyectoRef.collection('tareas').get(),
    proyectoRef.collection('ideas').get(),
    proyectoRef.collection('auditorias').get(),
    proyectoRef.collection('historial').orderBy('fecha', 'desc').limit(20).get(),
  ]);

  const proyecto = {
    nombre: p.nombre || '',
    descripcion: p.descripcion || '',
    estado: p.estado || '',
    progresoPorcentaje: p.progresoPorcentaje || 0,
  };
  const funcionalidades = funcSnap.docs.map((d) => ({
    nombre: d.data().nombre,
    descripcion: d.data().descripcion,
    estado: d.data().estado,
  }));
  const documentos = docSnap.docs.map((d) => ({
    titulo: d.data().titulo,
    categoria: d.data().categoria,
    contenido: d.data().contenido,
  }));
  const tareas = tareaSnap.docs.map((d) => ({
    titulo: d.data().titulo,
    estado: d.data().estado,
    prioridad: d.data().prioridad,
    fechaLimite: _fechaISO(d.data().fechaLimite),
  }));
  const ideas = ideaSnap.docs.map((d) => ({
    titulo: d.data().titulo,
    descripcion: d.data().descripcion,
    estado: d.data().estado,
  }));
  const auditorias = audSnap.docs.map((d) => {
    const a = d.data();
    return {
      fecha: _fechaISO(a.fecha),
      origen: a.origen,
      resultado: a.resultado,
      resumen: a.resumen,
      hallazgos: Array.isArray(a.hallazgos)
        ? a.hallazgos.map((h) => ({ titulo: h.titulo, descripcion: h.descripcion, gravedad: h.gravedad, estado: h.estado }))
        : [],
    };
  });
  const historial = histSnap.docs.map((d) => ({
    fecha: _fechaISO(d.data().fecha),
    entidad: d.data().entidad,
    descripcion: d.data().descripcion,
  }));

  return _construirContexto({ proyecto, funcionalidades, documentos, tareas, ideas, auditorias, historial, githubResumen });
}

// ---------------------------------------------------------------------------
// Llamada a Anthropic (único punto con fetch real) y parseo de su
// respuesta -- el parseo es puro y testeable con bloques de contenido ya
// armados a mano, sin red.
// ---------------------------------------------------------------------------

async function _llamarAnthropic(apiKey, body) {
  let res;
  try {
    res = await fetch(ANTHROPIC_API_URL, {
      method: 'POST',
      headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
  } catch (e) {
    console.error('Anthropic fetch error:', e);
    throw new HttpsError('unavailable', 'No se pudo contactar con el servicio de IA.');
  }
  if (!res.ok) {
    const texto = await res.text().catch(() => '');
    console.error(`Anthropic error ${res.status}:`, texto);
    throw new HttpsError('internal', `Error del servicio de IA (${res.status}).`);
  }
  return res.json();
}

function _parsearRespuestaTexto(contentBlocks) {
  const bloque = (contentBlocks || []).find((b) => b.type === 'text');
  if (!bloque || typeof bloque.text !== 'string' || bloque.text.trim() === '') {
    throw new HttpsError('internal', 'La IA no devolvió una respuesta de texto.');
  }
  return bloque.text;
}

const GRAVEDADES_VALIDAS = ['baja', 'media', 'alta', 'critica'];

function _parsearPropuestaExtraida(contentBlocks) {
  const bloque = (contentBlocks || []).find((b) => b.type === 'tool_use' && b.name === 'extraer_auditoria');
  if (!bloque || typeof bloque.input !== 'object' || bloque.input === null) {
    throw new HttpsError('internal', 'La IA no devolvió una extracción válida.');
  }
  const input = bloque.input;
  const resumen = typeof input.resumen === 'string' ? input.resumen.trim() : '';
  if (!resumen) {
    throw new HttpsError('internal', 'La IA no devolvió un resumen.');
  }
  const hallazgos = Array.isArray(input.hallazgos)
    ? input.hallazgos
        .filter((h) => h && typeof h.titulo === 'string' && h.titulo.trim() !== '')
        .map((h) => ({
          titulo: h.titulo.trim(),
          descripcion: typeof h.descripcion === 'string' ? h.descripcion.trim() : '',
          gravedad: GRAVEDADES_VALIDAS.includes(h.gravedad) ? h.gravedad : 'media',
        }))
    : [];
  const tareas = Array.isArray(input.tareas)
    ? input.tareas
        .filter((t) => t && typeof t.titulo === 'string' && t.titulo.trim() !== '')
        .map((t) => ({
          titulo: t.titulo.trim(),
          descripcion: typeof t.descripcion === 'string' ? t.descripcion.trim() : '',
        }))
    : [];
  return { resumen, hallazgos, tareas };
}

const HERRAMIENTA_EXTRAER_AUDITORIA = {
  name: 'extraer_auditoria',
  description:
    'Registra el resultado de analizar el texto de una auditoría pegada por el usuario: un resumen breve, los hallazgos detectados y las tareas accionables derivadas de esos hallazgos.',
  input_schema: {
    type: 'object',
    properties: {
      resumen: { type: 'string', description: 'Resumen breve (2-4 frases) de la auditoría pegada.' },
      hallazgos: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            titulo: { type: 'string' },
            descripcion: { type: 'string' },
            gravedad: { type: 'string', enum: GRAVEDADES_VALIDAS },
          },
          required: ['titulo', 'gravedad'],
        },
      },
      tareas: {
        type: 'array',
        items: {
          type: 'object',
          properties: { titulo: { type: 'string' }, descripcion: { type: 'string' } },
          required: ['titulo'],
        },
      },
    },
    required: ['resumen', 'hallazgos', 'tareas'],
  },
};

function _systemPregunta(contexto) {
  return `Eres el asistente de IA de AppsDoc para este proyecto concreto. AppsDoc es la herramienta personal del usuario para llevar el control de sus propios proyectos de software.

Tienes acceso al estado completo del proyecto (a continuación). Responde SOLO con base en estos datos -- si algo no está en el contexto, dilo explícitamente en vez de inventarlo. Eres conciso (máximo 3-4 párrafos salvo que se pida más detalle explícitamente) y respondes siempre en español.

No puedes modificar ningún dato del proyecto: solo informas, resumes y sugieres. Si el usuario te pide que hagas un cambio, explícale que debe confirmarlo él mismo desde la app.

=== ESTADO ACTUAL DEL PROYECTO ===
${contexto}
=== FIN DEL ESTADO DEL PROYECTO ===`;
}

const SYSTEM_EXTRAER =
  'Debes responder SIEMPRE llamando a la herramienta "extraer_auditoria" -- nunca con texto libre, ni para explicar ni para pedir aclaraciones. Vas a recibir el texto de una auditoría o revisión de un proyecto de software, normalmente pegada tal cual desde otra conversación con Claude. Analízalo y usa la herramienta "extraer_auditoria" para devolver: un resumen breve, la lista de hallazgos (con título, descripción y gravedad baja/media/alta/critica) y una lista de tareas accionables derivadas de esos hallazgos. No inventes hallazgos que no estén respaldados por el texto. Responde siempre en español, usando la herramienta -- nunca con texto libre.';

// ---------------------------------------------------------------------------
// Callables
// ---------------------------------------------------------------------------

exports.preguntarAsistente = onCall({ region: REGION, secrets: [_anthropicKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { proyectoId, pregunta, githubResumen } = _validarPreguntaInput(request.data || {});

  const contexto = await _leerContextoProyecto(uid, proyectoId, githubResumen);

  const hoyISO = new Date().toISOString().slice(0, 10);
  await _comprobarYRegistrarUso(uid, hoyISO);

  const apiKey = _anthropicKey.value();
  if (!apiKey) throw new HttpsError('internal', 'API key no configurada en el servidor.');

  const data = await _llamarAnthropic(apiKey, {
    model: MODELO,
    max_tokens: 1536,
    thinking: { type: 'adaptive' },
    system: _systemPregunta(contexto),
    messages: [{ role: 'user', content: pregunta }],
  });

  return { respuesta: _parsearRespuestaTexto(data.content) };
});

exports.extraerAuditoria = onCall({ region: REGION, secrets: [_anthropicKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
  const uid = request.auth.uid;
  const { proyectoId, texto } = _validarExtraccionInput(request.data || {});

  // Propiedad: el proyecto debe existir bajo el propio uid del que llama.
  // La extracción en sí no depende del resto del contexto del proyecto,
  // pero igualmente no se acepta un proyectoId sin comprobar que es suyo.
  const proyectoSnap = await db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId).get();
  if (!proyectoSnap.exists) throw new HttpsError('not-found', 'El proyecto no existe.');

  const hoyISO = new Date().toISOString().slice(0, 10);
  await _comprobarYRegistrarUso(uid, hoyISO);

  const apiKey = _anthropicKey.value();
  if (!apiKey) throw new HttpsError('internal', 'API key no configurada en el servidor.');

  // tool_choice "auto", no forzado ("tool"/"any"): la API de Anthropic
  // rechaza con 400 el tool_choice forzado en los modelos actuales
  // ("tool_choice: type \"tool\" and \"any\" are not supported for this
  // model"). La estructura se garantiza con una instrucción explícita en
  // el system prompt; _parsearPropuestaExtraida ya lanza "internal" si la
  // respuesta no trae el bloque de la herramienta.
  const data = await _llamarAnthropic(apiKey, {
    model: MODELO,
    max_tokens: 2048,
    system: SYSTEM_EXTRAER,
    tools: [HERRAMIENTA_EXTRAER_AUDITORIA],
    tool_choice: { type: 'auto' },
    messages: [{ role: 'user', content: texto }],
  });

  return _parsearPropuestaExtraida(data.content);
});

// =============================================================================
// Fase 9: análisis inteligente y automático de repositorios GitHub.
//
// Lee el repositorio completo (solo lectura, vía el tarball público de
// GitHub -- un único fetch, sin token, sin recorrer archivo a archivo por
// la API de Contents y agotar el límite de 60 peticiones/hora sin
// autenticar) y pide a Anthropic que lo audite: arquitectura, tecnologías,
// documentación, funcionalidades detectadas (con evidencia y confianza),
// hallazgos, tareas e ideas. Como extraerAuditoria, SOLO propone --
// nada se guarda aquí; el cliente confirma y persiste con los servicios
// ya existentes.
// =============================================================================

const MAX_TARBALL_BYTES = 30 * 1024 * 1024; // 30 MB
const MAX_ARCHIVOS_CONTENIDO = 80;
const MAX_CHARS_POR_ARCHIVO = 20000;
const PRESUPUESTO_CHARS_TOTAL = 180000;
const MAX_RUTAS_ARBOL = 3000;

// Presupuestos del pipeline por etapas de generarExpediente (Fase 10) -- cada
// módulo tiene su propio presupuesto, mucho menor que el total de
// analizarRepositorio, porque cada uno es una llamada a Anthropic aparte.
const MAX_ARCHIVOS_POR_MODULO = 20;
const PRESUPUESTO_CHARS_POR_MODULO = 40000;
// Orden fijo: "tests" y "otros" nunca generan su propia llamada a Anthropic,
// solo cuentan como metadatos -- no aportan suficiente señal nueva para
// justificar una llamada más.
const MODULOS_CON_LLAMADA_PROPIA = ['pantallas', 'servicios', 'modelos', 'backend', 'configuracion', 'documentacion'];
const PESO_EXPEDIENTE = Number(process.env.APPSDOC_PESO_EXPEDIENTE) || 10;

// Directorios que nunca aportan señal real para auditar o documentar un
// proyecto (dependencias instaladas, builds, control de versiones...).
const DIRECTORIOS_IRRELEVANTES = [
  'node_modules/',
  '.git/',
  'build/',
  'dist/',
  '.dart_tool/',
  'pods/',
  '.gradle/',
  'coverage/',
  '.idea/',
  '.vscode/',
  'vendor/',
  '__pycache__/',
  '.venv/',
  'venv/',
  'deriveddata/',
  '.next/',
  'target/',
  'out/',
  '.pub-cache/',
];

const EXTENSIONES_IRRELEVANTES = [
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
  '.ico',
  '.svg',
  '.icns',
  '.ttf',
  '.otf',
  '.woff',
  '.woff2',
  '.eot',
  '.mp3',
  '.mp4',
  '.mov',
  '.avi',
  '.wav',
  '.ogg',
  '.zip',
  '.tar',
  '.gz',
  '.rar',
  '.7z',
  '.jar',
  '.aar',
  '.apk',
  '.ipa',
  '.aab',
  '.lock',
  '.pdf',
  '.exe',
  '.dll',
  '.so',
  '.dylib',
  '.class',
  '.o',
  '.a',
  '.keystore',
  '.jks',
  '.p12',
  '.pem',
  '.mobileprovision',
];

// Nunca se envían a la IA, aunque no estén en el denylist de extensiones --
// "No enviar secretos, archivos sensibles... al proveedor de IA", pedido
// explícito de esta fase.
const NOMBRES_IRRELEVANTES = ['package-lock.json', 'pubspec.lock', 'yarn.lock', 'composer.lock', 'gemfile.lock'];
const NOMBRES_SENSIBLES = [
  '.env',
  'google-services.json',
  'googleservice-info.plist',
  'firebase_options.dart',
  'id_rsa',
  'id_ed25519',
  '.pgpass',
  '.npmrc',
  'credentials.json',
];
const PATRON_NOMBRE_SENSIBLE = /secret|credential|password|service-account|\.key$/i;

function _esArchivoIrrelevante(ruta) {
  const rutaNormalizada = ruta.toLowerCase();
  if (DIRECTORIOS_IRRELEVANTES.some((d) => rutaNormalizada === d.slice(0, -1) || rutaNormalizada.startsWith(d) || rutaNormalizada.includes(`/${d}`))) {
    return true;
  }
  if (EXTENSIONES_IRRELEVANTES.some((ext) => rutaNormalizada.endsWith(ext))) return true;
  const nombreArchivo = rutaNormalizada.split('/').pop() || '';
  if (NOMBRES_IRRELEVANTES.includes(nombreArchivo)) return true;
  if (NOMBRES_SENSIBLES.some((n) => nombreArchivo === n || nombreArchivo.startsWith(`${n}.`))) return true;
  if (PATRON_NOMBRE_SENSIBLE.test(nombreArchivo)) return true;
  return false;
}

const ARCHIVOS_ANCLA = [
  'readme.md',
  'readme',
  'pubspec.yaml',
  'package.json',
  'analysis_options.yaml',
  'firebase.json',
  'claude.md',
  'app.json',
  'build.gradle',
  'podfile',
];

function _esArchivoAncla(ruta) {
  const nombre = ruta.toLowerCase().split('/').pop() || '';
  const profundidad = ruta.split('/').length - 1;
  // Solo cuentan como "ancla" a poca profundidad -- un README anidado en
  // una carpeta de ejemplos de tercer nivel no debería desplazar a los
  // archivos de configuración reales del proyecto.
  return profundidad <= 1 && ARCHIVOS_ANCLA.some((a) => nombre === a || nombre.startsWith(`${a}.`));
}

/// Pura: ordena (anclas primero) y recorta a maxArchivos. No decide
/// contenido ni tamaño, solo QUÉ rutas intentar leer y en qué orden.
function _priorizarArchivos(rutas, maxArchivos) {
  const anclas = rutas.filter(_esArchivoAncla);
  const resto = rutas.filter((r) => !_esArchivoAncla(r));
  return [...anclas, ...resto].slice(0, maxArchivos);
}

/// Nombres/rutas de configuración y dependencias -- no son código de la app
/// en sí, pero cuentan como su propio módulo para el expediente (Fase 10).
const ARCHIVOS_CONFIGURACION = [
  'pubspec.yaml',
  'pubspec.lock',
  'package.json',
  'package-lock.json',
  'analysis_options.yaml',
  'firebase.json',
  'firestore.rules',
  'firestore.indexes.json',
  'storage.rules',
  'build.gradle',
  'podfile',
  'podfile.lock',
  'app.json',
  '.firebaserc',
];

/// Nombres de carpeta reconocidos por módulo -- por SEGMENTO exacto de la
/// ruta, no por prefijo desde la raíz. Esto es deliberado: muchos
/// repositorios reales (sobre todo monorepos, p.ej. "packages/ui_core/
/// lib/screens/login.dart") no tienen "lib/screens" como prefijo del
/// repo, sino en cualquier profundidad. Un prefijo rígido (como asumía la
/// primera versión de esta función) clasifica TODO como "otros" en esos
/// casos y deja el expediente sin nada que analizar -- justo el fallo que
/// se detectó analizando un monorepo real.
const SEGMENTOS_PANTALLAS = ['screens', 'pantallas', 'pestañas', 'pestanas', 'pages', 'views'];
const SEGMENTOS_SERVICIOS = ['services', 'servicios'];
const SEGMENTOS_MODELOS = ['models', 'modelos', 'entities'];
const SEGMENTOS_BACKEND = ['functions', 'backend', 'server', 'api'];
const SEGMENTOS_TESTS = ['test', 'tests', 'spec', '__tests__'];
const SEGMENTOS_DOCUMENTACION = ['docs', 'doc'];

function _tieneSegmento(ruta, segmentos) {
  const partes = ruta.split('/');
  return segmentos.some((s) => partes.includes(s));
}

/// Pura: clasifica cada ruta (ya filtrada de irrelevantes, nunca vuelve a
/// mirar el denylist por su cuenta) en un módulo lógico para el pipeline por
/// etapas de `generarExpediente` (Fase 10). Toda ruta de entrada acaba en
/// exactamente un grupo -- "otros" es el cajón de sastre, nunca se descarta
/// nada aquí.
function _agruparPorModulo(rutas) {
  const grupos = {
    pantallas: [],
    servicios: [],
    modelos: [],
    backend: [],
    configuracion: [],
    documentacion: [],
    tests: [],
    otros: [],
  };
  for (const ruta of rutas) {
    const r = ruta.toLowerCase();
    const nombreBase = r.split('/').pop();
    // Orden deliberado: "tests"/"documentación"/"configuración" se
    // comprueban ANTES que pantallas/servicios/modelos/backend porque son
    // señales más específicas (nombre de archivo, carpeta dedicada) -- sin
    // este orden, "test/models/x_test.dart" caería en "modelos" solo
    // porque "models" aparece como segmento, perdiendo que en realidad es
    // un test.
    if (_tieneSegmento(r, SEGMENTOS_TESTS) || nombreBase.includes('_test.') || nombreBase.includes('.test.')) {
      grupos.tests.push(ruta);
    } else if (nombreBase.startsWith('readme') || _tieneSegmento(r, SEGMENTOS_DOCUMENTACION)) {
      grupos.documentacion.push(ruta);
    } else if (ARCHIVOS_CONFIGURACION.includes(nombreBase)) {
      grupos.configuracion.push(ruta);
    } else if (_tieneSegmento(r, SEGMENTOS_PANTALLAS)) {
      grupos.pantallas.push(ruta);
    } else if (_tieneSegmento(r, SEGMENTOS_SERVICIOS)) {
      grupos.servicios.push(ruta);
    } else if (_tieneSegmento(r, SEGMENTOS_MODELOS)) {
      grupos.modelos.push(ruta);
    } else if (_tieneSegmento(r, SEGMENTOS_BACKEND)) {
      grupos.backend.push(ruta);
    } else {
      grupos.otros.push(ruta);
    }
  }
  return grupos;
}

/// Pura: decide qué módulos consiguen su propia llamada a Anthropic. Por
/// defecto, los módulos "con nombre" de MODULOS_CON_LLAMADA_PROPIA que
/// tengan contenido -- "tests"/"otros" nunca aportan suficiente señal
/// propia. PERO si ninguno de los módulos con nombre tiene nada (la
/// heurística de carpetas no reconoció la estructura de este repo en
/// absoluto), cae a analizar "otros" como último recurso: un expediente
/// vacío por un fallo de categorización es peor que uno con una
/// clasificación menos fina.
function _elegirModulosAProcesar(grupos) {
  const conNombre = MODULOS_CON_LLAMADA_PROPIA.filter((m) => (grupos[m] || []).length > 0);
  if (conNombre.length > 0) return conNombre;
  return (grupos.otros || []).length > 0 ? ['otros'] : [];
}

/// Los tarballs de GitHub anteponen un prefijo "{owner}-{repo}-{sha}/" a
/// cada ruta -- esta es la ruta "lógica" relativa a la raíz del repo, la
/// que de verdad interesa mostrarle a la IA y comparar contra denylists.
function _rutaLogica(nombreEnTar) {
  const idx = nombreEnTar.indexOf('/');
  return idx === -1 ? '' : nombreEnTar.slice(idx + 1);
}

function _descomprimirTar(buffer) {
  return zlib.gunzipSync(buffer);
}

/// Primera pasada sobre el tarball (ya en memoria, sin red adicional):
/// solo cabeceras -- construye el árbol de rutas sin cargar contenido.
function _listarEntradasTar(buffer) {
  return new Promise((resolve, reject) => {
    const entradas = [];
    const extract = tar.extract();
    extract.on('entry', (header, stream, next) => {
      const ruta = _rutaLogica(header.name);
      if (header.type === 'file' && ruta && entradas.length < MAX_RUTAS_ARBOL) {
        entradas.push({ path: ruta, size: header.size });
      }
      stream.resume();
      stream.on('end', next);
    });
    extract.on('finish', () => resolve(entradas));
    extract.on('error', reject);
    try {
      extract.end(_descomprimirTar(buffer));
    } catch (e) {
      reject(e);
    }
  });
}

/// Segunda pasada sobre el MISMO buffer (no se vuelve a descargar nada):
/// esta vez sí carga contenido, pero solo de `rutasAIncluir`, y solo
/// hasta agotar `presupuestoChars` en total -- el resto se salta.
function _extraerContenidoTar(buffer, rutasAIncluir, presupuestoChars) {
  const conjunto = new Set(rutasAIncluir);
  return new Promise((resolve, reject) => {
    const contenidos = new Map();
    let acumulado = 0;
    const extract = tar.extract();
    extract.on('entry', (header, stream, next) => {
      const ruta = _rutaLogica(header.name);
      if (header.type === 'file' && ruta && conjunto.has(ruta) && acumulado < presupuestoChars) {
        const partes = [];
        stream.on('data', (chunk) => partes.push(chunk));
        stream.on('end', () => {
          let texto = Buffer.concat(partes).toString('utf8');
          if (texto.length > MAX_CHARS_POR_ARCHIVO) {
            texto = `${texto.slice(0, MAX_CHARS_POR_ARCHIVO)}\n… (truncado)`;
          }
          contenidos.set(ruta, texto);
          acumulado += texto.length;
          next();
        });
      } else {
        stream.resume();
        stream.on('end', next);
      }
    });
    extract.on('finish', () => resolve(contenidos));
    extract.on('error', reject);
    try {
      extract.end(_descomprimirTar(buffer));
    } catch (e) {
      reject(e);
    }
  });
}

async function _leerCuerpoConLimite(res, maxBytes) {
  const reader = res.body.getReader();
  const trozos = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.length;
    if (total > maxBytes) {
      await reader.cancel();
      throw new HttpsError('resource-exhausted', 'El repositorio es demasiado grande para analizarlo de una vez.');
    }
    trozos.push(Buffer.from(value));
  }
  return Buffer.concat(trozos);
}

async function _obtenerJsonGithub(ruta) {
  let res;
  try {
    res = await fetch(`https://api.github.com${ruta}`, { headers: { Accept: 'application/vnd.github+json' } });
  } catch (e) {
    throw new HttpsError('unavailable', 'No se pudo conectar con GitHub.');
  }
  if (res.status === 404) throw new HttpsError('not-found', 'No se pudo leer el repositorio: no existe o es privado.');
  if (res.status === 403) {
    if (res.headers.get('x-ratelimit-remaining') === '0') {
      throw new HttpsError('resource-exhausted', 'Límite de peticiones a GitHub alcanzado. Inténtalo más tarde.');
    }
    throw new HttpsError('internal', 'GitHub rechazó la petición (403).');
  }
  if (!res.ok) throw new HttpsError('internal', `GitHub devolvió un error inesperado (${res.status}).`);
  return res.json();
}

async function _obtenerRamaYCommit(propietario, nombre) {
  const repoJson = await _obtenerJsonGithub(`/repos/${propietario}/${nombre}`);
  const rama = repoJson.default_branch || 'main';
  let sha = null;
  try {
    const commitJson = await _obtenerJsonGithub(`/repos/${propietario}/${nombre}/commits/${rama}`);
    sha = commitJson.sha || null;
  } catch (e) {
    // El sha solo sirve para preparar comparaciones incrementales futuras
    // (ver arquitectura aprobada) -- si esta llamada concreta falla, el
    // análisis sigue adelante igual, simplemente sin esa referencia.
    sha = null;
  }
  return { rama, sha };
}

async function _descargarTarball(propietario, nombre, rama) {
  let res;
  try {
    res = await fetch(`https://api.github.com/repos/${propietario}/${nombre}/tarball/${encodeURIComponent(rama)}`, {
      headers: { Accept: 'application/vnd.github+json' },
    });
  } catch (e) {
    throw new HttpsError('unavailable', 'No se pudo descargar el repositorio desde GitHub.');
  }
  if (res.status === 404) throw new HttpsError('not-found', 'No se pudo leer el repositorio: no existe o es privado.');
  if (res.status === 403) {
    if (res.headers.get('x-ratelimit-remaining') === '0') {
      throw new HttpsError('resource-exhausted', 'Límite de peticiones a GitHub alcanzado. Inténtalo más tarde.');
    }
    throw new HttpsError('internal', 'GitHub rechazó la petición (403).');
  }
  if (!res.ok) throw new HttpsError('internal', `GitHub devolvió un error inesperado (${res.status}) al descargar el repositorio.`);
  return _leerCuerpoConLimite(res, MAX_TARBALL_BYTES);
}

/// Pura: arma el prompt a partir de datos ya reunidos (árbol, contenido,
/// lo ya registrado en AppsDoc, el análisis anterior si lo hay) -- sin
/// tocar Firestore ni GitHub.
function _construirPromptAnalisis({
  proyecto,
  rutasArbol,
  archivosConContenido,
  funcionalidadesExistentes,
  documentosExistentes,
  tareasExistentes,
  analisisAnterior,
}) {
  const lineas = [];
  lineas.push(`Repositorio del proyecto "${proyecto.nombre}".`);

  lineas.push('', '## Árbol de archivos (solo rutas, sin contenido)');
  lineas.push(rutasArbol.length ? rutasArbol.map((r) => `- ${r}`).join('\n') : '(vacío)');

  lineas.push('', '## Contenido de los archivos más relevantes');
  if (archivosConContenido.size) {
    for (const [ruta, contenido] of archivosConContenido) {
      lineas.push(`\n--- ${ruta} ---\n${contenido}`);
    }
  } else {
    lineas.push('(no se pudo leer el contenido de ningún archivo)');
  }

  lineas.push('', '## Funcionalidades ya registradas en AppsDoc -- no las repitas');
  lineas.push(funcionalidadesExistentes.length ? funcionalidadesExistentes.map((n) => `- ${n}`).join('\n') : '(ninguna)');

  lineas.push('', '## Documentos ya registrados en AppsDoc -- no los repitas');
  lineas.push(documentosExistentes.length ? documentosExistentes.map((n) => `- ${n}`).join('\n') : '(ninguno)');

  lineas.push('', '## Tareas ya registradas en AppsDoc -- no las repitas');
  lineas.push(tareasExistentes.length ? tareasExistentes.map((n) => `- ${n}`).join('\n') : '(ninguna)');

  if (analisisAnterior) {
    lineas.push('', '## Análisis automático anterior de este mismo repositorio (para comparar qué ha cambiado)');
    lineas.push(analisisAnterior);
  }

  return lineas.join('\n');
}

const ESTADOS_FUNCIONALIDAD_VALIDOS = ['planificada', 'enProgreso', 'completada', 'descartada'];
const CATEGORIAS_DOCUMENTO_VALIDAS = ['arquitectura', 'decision', 'nota'];
const CONFIANZAS_VALIDAS = ['alta', 'media', 'baja'];

// Fase 10 (expediente integral) -- deliberadamente distintos de
// EstadoFuncionalidad/CONFIANZAS_VALIDAS de arriba: el catálogo del
// expediente es documental (qué tan seguro está el análisis de que algo
// existe), nunca se mezcla con la Funcionalidad real que sí mueve el
// progreso.
const CONFIANZAS_EXPEDIENTE_VALIDAS = ['detectada', 'aparentementeImplementada', 'verificada', 'pendiente'];
const NIVELES_CONFIANZA_VALORACION_VALIDOS = ['baja', 'media', 'alta'];

function _normalizarTitulo(t) {
  return (t || '').trim().toLowerCase();
}

/// Pura: parsea la respuesta de Anthropic Y descarta cualquier
/// funcionalidad/documento/tarea propuesto que ya exista (comparación
/// case-insensitive por título/nombre) -- la instrucción al modelo para
/// que no los repita es la primera barrera, esta es la segunda,
/// determinista, que no depende de que el modelo la respete.
function _parsearAnalisisRepositorio(
  contentBlocks,
  { funcionalidadesExistentes = [], documentosExistentes = [], tareasExistentes = [] } = {},
) {
  const bloque = (contentBlocks || []).find((b) => b.type === 'tool_use' && b.name === 'registrar_analisis_repositorio');
  if (!bloque || typeof bloque.input !== 'object' || bloque.input === null) {
    throw new HttpsError('internal', 'La IA no devolvió un análisis válido.');
  }
  const input = bloque.input;
  const resumen = typeof input.resumen === 'string' ? input.resumen.trim() : '';
  if (!resumen) throw new HttpsError('internal', 'La IA no devolvió un resumen.');

  const existentesFunc = new Set(funcionalidadesExistentes.map(_normalizarTitulo));
  const existentesDoc = new Set(documentosExistentes.map(_normalizarTitulo));
  const existentesTarea = new Set(tareasExistentes.map(_normalizarTitulo));

  const arquitecturaDetectada = typeof input.arquitecturaDetectada === 'string' ? input.arquitecturaDetectada.trim() : '';
  const tecnologias = Array.isArray(input.tecnologias)
    ? input.tecnologias.filter((t) => typeof t === 'string' && t.trim() !== '').map((t) => t.trim())
    : [];

  const documentos = Array.isArray(input.documentos)
    ? input.documentos
        .filter((d) => d && typeof d.titulo === 'string' && d.titulo.trim() !== '' && !existentesDoc.has(_normalizarTitulo(d.titulo)))
        .map((d) => ({
          titulo: d.titulo.trim(),
          categoria: CATEGORIAS_DOCUMENTO_VALIDAS.includes(d.categoria) ? d.categoria : 'nota',
          contenido: typeof d.contenido === 'string' ? d.contenido.trim() : '',
        }))
    : [];

  const funcionalidades = Array.isArray(input.funcionalidades)
    ? input.funcionalidades
        .filter((f) => f && typeof f.nombre === 'string' && f.nombre.trim() !== '' && !existentesFunc.has(_normalizarTitulo(f.nombre)))
        .map((f) => ({
          nombre: f.nombre.trim(),
          descripcion: typeof f.descripcion === 'string' ? f.descripcion.trim() : '',
          estadoSugerido: ESTADOS_FUNCIONALIDAD_VALIDOS.includes(f.estadoSugerido) ? f.estadoSugerido : 'planificada',
          confianza: CONFIANZAS_VALIDAS.includes(f.confianza) ? f.confianza : 'baja',
          evidencia: typeof f.evidencia === 'string' ? f.evidencia.trim() : '',
        }))
    : [];

  const hallazgos = Array.isArray(input.hallazgos)
    ? input.hallazgos
        .filter((h) => h && typeof h.titulo === 'string' && h.titulo.trim() !== '')
        .map((h) => ({
          titulo: h.titulo.trim(),
          descripcion: typeof h.descripcion === 'string' ? h.descripcion.trim() : '',
          gravedad: GRAVEDADES_VALIDAS.includes(h.gravedad) ? h.gravedad : 'media',
        }))
    : [];

  const tareas = Array.isArray(input.tareas)
    ? input.tareas
        .filter((t) => t && typeof t.titulo === 'string' && t.titulo.trim() !== '' && !existentesTarea.has(_normalizarTitulo(t.titulo)))
        .map((t) => ({ titulo: t.titulo.trim(), descripcion: typeof t.descripcion === 'string' ? t.descripcion.trim() : '' }))
    : [];

  const ideas = Array.isArray(input.ideas)
    ? input.ideas
        .filter((i) => i && typeof i.titulo === 'string' && i.titulo.trim() !== '')
        .map((i) => ({ titulo: i.titulo.trim(), descripcion: typeof i.descripcion === 'string' ? i.descripcion.trim() : '' }))
    : [];

  return { resumen, arquitecturaDetectada, tecnologias, documentos, funcionalidades, hallazgos, tareas, ideas };
}

const HERRAMIENTA_ANALISIS_REPOSITORIO = {
  name: 'registrar_analisis_repositorio',
  description:
    'Registra el resultado de analizar el código fuente de un repositorio: arquitectura, tecnologías, documentación propuesta, funcionalidades detectadas (con evidencia y nivel de confianza), hallazgos de auditoría, tareas e ideas propuestas.',
  input_schema: {
    type: 'object',
    properties: {
      resumen: { type: 'string', description: 'Resumen general del análisis: qué es el proyecto y qué tan completo parece.' },
      arquitecturaDetectada: { type: 'string', description: 'Descripción breve de la arquitectura/estructura del proyecto.' },
      tecnologias: { type: 'array', items: { type: 'string' }, description: 'Lenguajes, frameworks y librerías principales.' },
      documentos: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            titulo: { type: 'string' },
            categoria: { type: 'string', enum: CATEGORIAS_DOCUMENTO_VALIDAS },
            contenido: { type: 'string', description: 'Contenido en markdown del documento propuesto.' },
          },
          required: ['titulo', 'categoria', 'contenido'],
        },
      },
      funcionalidades: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            nombre: { type: 'string' },
            descripcion: { type: 'string' },
            estadoSugerido: {
              type: 'string',
              enum: ESTADOS_FUNCIONALIDAD_VALIDOS,
              description:
                'Nunca "completada" salvo evidencia clara e inequívoca (implementación real y usada, no un esqueleto o TODO).',
            },
            confianza: { type: 'string', enum: CONFIANZAS_VALIDAS },
            evidencia: { type: 'string', description: 'Qué archivos o fragmentos de código sustentan esta detección.' },
          },
          required: ['nombre', 'estadoSugerido', 'confianza', 'evidencia'],
        },
      },
      hallazgos: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            titulo: { type: 'string' },
            descripcion: { type: 'string' },
            gravedad: { type: 'string', enum: GRAVEDADES_VALIDAS },
          },
          required: ['titulo', 'gravedad'],
        },
      },
      tareas: {
        type: 'array',
        items: {
          type: 'object',
          properties: { titulo: { type: 'string' }, descripcion: { type: 'string' } },
          required: ['titulo'],
        },
      },
      ideas: {
        type: 'array',
        items: {
          type: 'object',
          properties: { titulo: { type: 'string' }, descripcion: { type: 'string' } },
          required: ['titulo'],
        },
      },
    },
    required: ['resumen', 'arquitecturaDetectada', 'tecnologias', 'documentos', 'funcionalidades', 'hallazgos', 'tareas', 'ideas'],
  },
};

const SYSTEM_ANALISIS_REPOSITORIO = `Eres un auditor técnico senior analizando el código fuente real de un repositorio para preparar su documentación y auditoría dentro de AppsDoc, una herramienta personal de gestión de proyectos de software.

Recibes el árbol de archivos del repositorio y el contenido de los más relevantes -- puede que no sea el repositorio completo si es muy grande; analiza solo con lo que tienes, sin asumir que has visto más.

REGLAS ESTRICTAS:
- Debes responder SIEMPRE llamando a la herramienta "registrar_analisis_repositorio" -- nunca con texto libre, ni para explicar ni para pedir aclaraciones.
- NUNCA marques una funcionalidad como "completada" solo porque exista código relacionado o un esqueleto/placeholder. Solo márcala así cuando la evidencia sea clara e inequívoca (implementación real, sin TODOs ni stubs pendientes). Ante la duda, usa "enProgreso" o "planificada" y confianza "baja" o "media".
- No propongas ninguna funcionalidad, documento ni tarea que ya aparezca en las listas de "ya registrado" -- revísalas antes de proponer nada.
- Basa cada hallazgo y cada funcionalidad detectada en evidencia concreta del código que has visto; cita el archivo relevante en el campo de evidencia.
- Responde siempre en español, usando la herramienta "registrar_analisis_repositorio" -- nunca con texto libre.`;

exports.analizarRepositorio = onCall(
  { region: REGION, secrets: [_anthropicKey], timeoutSeconds: 180, memory: '512MiB' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
    const uid = request.auth.uid;
    const proyectoIdCrudo = request.data && request.data.proyectoId;
    if (typeof proyectoIdCrudo !== 'string' || proyectoIdCrudo.trim() === '') {
      throw new HttpsError('invalid-argument', 'Falta el identificador del proyecto.');
    }
    const proyectoId = proyectoIdCrudo.trim();

    const proyectoRef = db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId);
    const proyectoSnap = await proyectoRef.get();
    if (!proyectoSnap.exists) throw new HttpsError('not-found', 'El proyecto no existe.');
    const proyecto = proyectoSnap.data();
    const propietario = proyecto.repoPropietario;
    const nombreRepo = proyecto.repoNombre;
    if (!propietario || !nombreRepo) {
      throw new HttpsError('failed-precondition', 'Este proyecto no tiene un repositorio de GitHub vinculado.');
    }

    const hoyISO = new Date().toISOString().slice(0, 10);
    await _comprobarYRegistrarUso(uid, hoyISO);

    const [funcSnap, docSnap, tareaSnap, audSnap] = await Promise.all([
      proyectoRef.collection('funcionalidades').get(),
      proyectoRef.collection('documentos').get(),
      proyectoRef.collection('tareas').get(),
      proyectoRef.collection('auditorias').orderBy('fecha', 'desc').limit(3).get(),
    ]);
    const funcionalidadesExistentes = funcSnap.docs.map((d) => d.data().nombre).filter(Boolean);
    const documentosExistentes = docSnap.docs.map((d) => d.data().titulo).filter(Boolean);
    const tareasExistentes = tareaSnap.docs.map((d) => d.data().titulo).filter(Boolean);
    const anteriorDoc = audSnap.docs.map((d) => d.data()).find((a) => a.origen === 'analisisRepositorio');
    const analisisAnterior = anteriorDoc
      ? `${_fechaISO(anteriorDoc.fecha) ? `(${_fechaISO(anteriorDoc.fecha)}) ` : ''}${anteriorDoc.resumen || ''}`
      : null;

    const { rama, sha } = await _obtenerRamaYCommit(propietario, nombreRepo);
    const tarball = await _descargarTarball(propietario, nombreRepo, rama);

    const todasEntradas = await _listarEntradasTar(tarball);
    const todasLasRutas = todasEntradas.map((e) => e.path).filter(Boolean);
    const rutasTexto = todasLasRutas.filter((p) => !_esArchivoIrrelevante(p));
    const rutasAIncluir = _priorizarArchivos(rutasTexto, MAX_ARCHIVOS_CONTENIDO);
    const contenidos = await _extraerContenidoTar(tarball, rutasAIncluir, PRESUPUESTO_CHARS_TOTAL);

    const truncado = rutasTexto.length > contenidos.size || todasEntradas.length >= MAX_RUTAS_ARBOL;
    const archivosOmitidos = Math.max(0, rutasTexto.length - contenidos.size);

    const prompt = _construirPromptAnalisis({
      proyecto: { nombre: proyecto.nombre || '' },
      rutasArbol: todasLasRutas,
      archivosConContenido: contenidos,
      funcionalidadesExistentes,
      documentosExistentes,
      tareasExistentes,
      analisisAnterior,
    });

    const apiKey = _anthropicKey.value();
    if (!apiKey) throw new HttpsError('internal', 'API key no configurada en el servidor.');

    // tool_choice "auto", no forzado: ver el comentario equivalente en
    // extraerAuditoria -- los modelos actuales rechazan con 400 el
    // tool_choice forzado ("tool"/"any").
    const data = await _llamarAnthropic(apiKey, {
      model: MODELO,
      max_tokens: 4096,
      system: SYSTEM_ANALISIS_REPOSITORIO,
      tools: [HERRAMIENTA_ANALISIS_REPOSITORIO],
      tool_choice: { type: 'auto' },
      messages: [{ role: 'user', content: prompt }],
    });

    const resultado = _parsearAnalisisRepositorio(data.content, {
      funcionalidadesExistentes,
      documentosExistentes,
      tareasExistentes,
    });

    return {
      ...resultado,
      truncado,
      archivosAnalizados: contenidos.size,
      archivosOmitidos,
      commitAnalizado: sha,
      rama,
    };
  },
);

// ---------------------------------------------------------------------------
// Fase 10 -- Expediente integral (pipeline por etapas)
//
// generarExpediente es puramente documental: nunca escribe en
// funcionalidades/tareas/ideas/documentos/auditorias reales ni en
// Proyecto.progresoPorcentaje -- solo LEE el progreso ya calculado para
// mostrarlo junto a la valoración. El flujo de analizarRepositorio (arriba)
// no se toca. Reutiliza sin cambios _obtenerRamaYCommit, _descargarTarball,
// _listarEntradasTar, _esArchivoIrrelevante, _priorizarArchivos,
// _extraerContenidoTar y _llamarAnthropic.
// ---------------------------------------------------------------------------

const HERRAMIENTA_ANALISIS_MODULO = {
  name: 'registrar_analisis_modulo',
  description:
    'Registra el análisis condensado de un módulo concreto del repositorio (pantallas, servicios, modelos, backend, configuración o documentación).',
  input_schema: {
    type: 'object',
    properties: {
      resumenModulo: { type: 'string', description: 'Qué hace este módulo y cómo está organizado.' },
      elementosDetectados: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            nombre: { type: 'string' },
            descripcion: { type: 'string' },
            tipo: { type: 'string', description: 'p.ej. "pantalla", "servicio", "modelo", "endpoint", "dependencia".' },
            evidencia: { type: 'string', description: 'Archivo o fragmento concreto que sustenta esta detección.' },
          },
          required: ['nombre', 'tipo', 'evidencia'],
        },
      },
      tecnologiasDetectadas: { type: 'array', items: { type: 'string' } },
    },
    required: ['resumenModulo', 'elementosDetectados', 'tecnologiasDetectadas'],
  },
};

function _systemAnalisisModulo(nombreModulo) {
  return `Eres un auditor técnico senior. Analiza SOLO el módulo "${nombreModulo}" de una aplicación de software -- no tienes el resto del repositorio, no asumas nada sobre lo que no ves aquí. Responde llamando directamente a la herramienta "registrar_analisis_modulo", sin ningún texto libre antes ni después -- no expliques tu razonamiento fuera de la herramienta, eso agota el presupuesto de respuesta antes de completarla. Resume qué hace este módulo, enumera los elementos concretos detectados citando evidencia de archivo real, y lista las tecnologías que detectes en este módulo. Sé conciso: prioriza completar la llamada a la herramienta sobre la exhaustividad. No inventes nada que no esté respaldado por el código que ves.`;
}

/// Pura: prompt de una etapa de módulo -- solo el contenido de ESE módulo,
/// nunca el repositorio completo.
function _construirPromptModulo({ nombreModulo, archivosConContenido }) {
  const lineas = [];
  lineas.push(`Módulo "${nombreModulo}" de la aplicación -- contenido de sus archivos más relevantes.`);
  lineas.push('', '## Archivos');
  if (archivosConContenido.size) {
    for (const [ruta, contenido] of archivosConContenido) {
      lineas.push(`\n--- ${ruta} ---\n${contenido}`);
    }
  } else {
    lineas.push('(no se pudo leer contenido de ningún archivo de este módulo)');
  }
  return lineas.join('\n');
}

/// Pura: parsea la respuesta condensada de una llamada de módulo.
function _parsearAnalisisModulo(contentBlocks) {
  const bloque = (contentBlocks || []).find((b) => b.type === 'tool_use' && b.name === 'registrar_analisis_modulo');
  if (!bloque || typeof bloque.input !== 'object' || bloque.input === null) {
    throw new HttpsError('internal', 'La IA no devolvió un análisis de módulo válido.');
  }
  const input = bloque.input;
  const resumenModulo = typeof input.resumenModulo === 'string' ? input.resumenModulo.trim() : '';
  const elementosDetectados = Array.isArray(input.elementosDetectados)
    ? input.elementosDetectados
        .filter((e) => e && typeof e.nombre === 'string' && e.nombre.trim() !== '')
        .map((e) => ({
          nombre: e.nombre.trim(),
          descripcion: typeof e.descripcion === 'string' ? e.descripcion.trim() : '',
          tipo: typeof e.tipo === 'string' ? e.tipo.trim() : '',
          evidencia: typeof e.evidencia === 'string' ? e.evidencia.trim() : '',
        }))
    : [];
  const tecnologiasDetectadas = Array.isArray(input.tecnologiasDetectadas)
    ? input.tecnologiasDetectadas.filter((t) => typeof t === 'string' && t.trim() !== '').map((t) => t.trim())
    : [];
  return { resumenModulo, elementosDetectados, tecnologiasDetectadas };
}

const HALLAZGO_EXPEDIENTE_ITEM = {
  type: 'object',
  properties: {
    titulo: { type: 'string' },
    descripcion: { type: 'string' },
    gravedad: { type: 'string', enum: GRAVEDADES_VALIDAS },
    evidencia: { type: 'string' },
  },
  required: ['titulo', 'gravedad', 'evidencia'],
};

const ESCENARIO_ECONOMICO_ITEM = {
  type: 'object',
  properties: {
    costeDesarrolloEstimado: { type: 'number' },
    costeReconstruccionEstimado: { type: 'number' },
    valorProductoEstimado: { type: 'number' },
    moneda: { type: 'string', description: 'Código ISO de 3 letras, p.ej. "EUR".' },
    razonamiento: { type: 'string' },
  },
  required: ['costeDesarrolloEstimado', 'costeReconstruccionEstimado', 'valorProductoEstimado', 'moneda', 'razonamiento'],
};

const ESCENARIO_USUARIOS_ITEM = {
  type: 'object',
  properties: {
    usuariosEstimados: { type: 'number' },
    razonamiento: { type: 'string' },
  },
  required: ['usuariosEstimados', 'razonamiento'],
};

const HERRAMIENTA_SINTESIS_EXPEDIENTE = {
  name: 'registrar_expediente',
  description:
    'Registra el expediente integral de la aplicación: descripción general, pantallas, catálogo de funcionalidades, arquitectura, calidad, seguridad, valoración económica y potencial de usuarios.',
  input_schema: {
    type: 'object',
    properties: {
      descripcionGeneral: {
        type: 'object',
        properties: {
          resumen: {
            type: 'string',
            description: 'En lenguaje cotidiano, para alguien que nunca ha visto la app: qué es y para qué sirve, como se lo explicarías a un amigo.',
          },
          propuestaValor: { type: 'string' },
          publicoObjetivo: { type: 'string' },
          estadoMadurez: { type: 'string', description: 'p.ej. "prototipo", "en desarrollo activo", "listo para producción".' },
        },
        required: ['resumen', 'propuestaValor', 'publicoObjetivo', 'estadoMadurez'],
      },
      pantallas: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            nombre: { type: 'string' },
            descripcionFuncion: {
              type: 'string',
              description: 'Qué hace esta pantalla desde el punto de vista de quien la usa, en una frase sencilla -- no detalles de implementación.',
            },
            archivoPrincipal: { type: 'string' },
            navegacion: { type: 'string', description: 'Cómo se llega a esta pantalla y a dónde lleva.' },
            pantallasRelacionadas: { type: 'array', items: { type: 'string' } },
          },
          required: ['nombre', 'descripcionFuncion', 'archivoPrincipal'],
        },
      },
      catalogoFuncionalidades: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            nombre: {
              type: 'string',
              description:
                'Una acción concreta que la persona usuaria puede hacer, en lenguaje cotidiano -- p.ej. "Añadir una tarea", "Marcar un pago como pagado", "Invitar a un profesional". Nunca el nombre de una clase, pantalla técnica o módulo interno.',
            },
            descripcion: {
              type: 'string',
              description:
                'Explica esta función como si se la contaras a alguien sin conocimientos técnicos, en una o dos frases: qué consigue la persona usuaria al hacerlo, con un ejemplo concreto de cuándo la usaría. Nada de jerga de desarrollo (nombres de clases, "CRM", "endpoint", "Cloud Function", siglas internas...) salvo que forme parte del vocabulario normal de quien usa la app.',
            },
            confianza: {
              type: 'string',
              enum: CONFIANZAS_EXPEDIENTE_VALIDAS,
              description:
                '"detectada": solo código relacionado, sin más. "aparentementeImplementada": parece completa pero no verificada. "verificada": evidencia clara e inequívoca. "pendiente": no verificable con lo analizado. Nunca asumas que encontrar código significa que algo está terminado.',
            },
            evidencia: { type: 'string' },
            archivosRelacionados: { type: 'array', items: { type: 'string' } },
          },
          required: ['nombre', 'confianza', 'evidencia'],
        },
      },
      arquitectura: {
        type: 'object',
        properties: {
          resumen: { type: 'string' },
          patrones: { type: 'array', items: { type: 'string' } },
          tecnologias: { type: 'array', items: { type: 'string' } },
        },
        required: ['resumen', 'patrones', 'tecnologias'],
      },
      calidad: {
        type: 'object',
        properties: { resumen: { type: 'string' }, hallazgos: { type: 'array', items: HALLAZGO_EXPEDIENTE_ITEM } },
        required: ['resumen', 'hallazgos'],
      },
      seguridad: {
        type: 'object',
        properties: { resumen: { type: 'string' }, hallazgos: { type: 'array', items: HALLAZGO_EXPEDIENTE_ITEM } },
        required: ['resumen', 'hallazgos'],
        description:
          'Distingue problemas CONFIRMADOS de riesgos POTENCIALES en cada descripción. Nunca afirmes que la aplicación es segura solo porque no se detectaron problemas.',
      },
      valoracionEconomica: {
        type: 'object',
        properties: {
          conservador: ESCENARIO_ECONOMICO_ITEM,
          intermedio: ESCENARIO_ECONOMICO_ITEM,
          optimista: ESCENARIO_ECONOMICO_ITEM,
          supuestos: { type: 'array', items: { type: 'string' } },
          limitaciones: { type: 'string' },
          nivelConfianza: { type: 'string', enum: NIVELES_CONFIANZA_VALORACION_VALIDOS },
        },
        required: ['conservador', 'intermedio', 'optimista', 'supuestos', 'limitaciones', 'nivelConfianza'],
      },
      potencialUsuarios: {
        type: 'object',
        properties: {
          conservador: ESCENARIO_USUARIOS_ITEM,
          intermedio: ESCENARIO_USUARIOS_ITEM,
          optimista: ESCENARIO_USUARIOS_ITEM,
          segmentoObjetivo: { type: 'string' },
          supuestos: { type: 'array', items: { type: 'string' } },
          limitaciones: { type: 'string' },
          nivelConfianza: { type: 'string', enum: NIVELES_CONFIANZA_VALORACION_VALIDOS },
        },
        required: ['conservador', 'intermedio', 'optimista', 'segmentoObjetivo', 'supuestos', 'limitaciones', 'nivelConfianza'],
      },
      analisisProgresoValor: {
        type: 'string',
        description: 'Relación cualitativa entre el progreso de desarrollo y el valor/potencial -- nunca una fórmula mecánica.',
      },
    },
    required: [
      'descripcionGeneral',
      'pantallas',
      'catalogoFuncionalidades',
      'arquitectura',
      'calidad',
      'seguridad',
      'valoracionEconomica',
      'potencialUsuarios',
      'analisisProgresoValor',
    ],
  },
};

const SYSTEM_SINTESIS_EXPEDIENTE = `Eres un analista senior preparando el EXPEDIENTE INTEGRAL de una aplicación de software para AppsDoc: su objetivo es que cualquiera (el propio dueño o un tercero) entienda qué es la app, cómo está construida, qué calidad y seguridad tiene, y cuánto podría valer -- no proponer tareas ni mejoras (eso ya lo hace otra función de AppsDoc).

Recibes resúmenes YA CONDENSADOS de cada módulo del repositorio (pantallas, servicios, modelos, backend, configuración, documentación) -- no el código crudo. Básate solo en esos resúmenes y en el contexto que te demos (progreso ya calculado, expediente anterior si existe).

REGLAS ESTRICTAS:
- Responde llamando directamente a la herramienta "registrar_expediente", sin ningún texto libre antes ni después -- no expliques tu razonamiento fuera de la herramienta, eso agota el presupuesto de respuesta antes de completarla. Si el espacio aprieta, prioriza completar todas las secciones de forma breve sobre desarrollar unas pocas en detalle y dejar el resto vacío.
- Descripción general, pantallas y catálogo de funcionalidades: escribe como si le explicaras la aplicación, paso a paso, a una persona sin conocimientos técnicos. El nombre de cada funcionalidad es una ACCIÓN que alguien puede hacer ("Añadir una tarea", "Marcar un pago como pagado", "Invitar a un profesional"), nunca el nombre de una clase, pantalla o módulo interno. Cada descripción incluye un ejemplo concreto de cuándo se usaría. Nada de jerga de desarrollo (nombres de clases, "endpoint", "CRM", "Cloud Function", siglas internas) salvo que sea vocabulario normal para quien usa la app -- esa jerga sí es bienvenida, y necesaria, en la sección de Arquitectura.
- Catálogo de funcionalidades: usa "verificada" únicamente con evidencia clara e inequívoca; "aparentementeImplementada" si el código parece completo pero no está verificado; "detectada" si solo hay indicios; "pendiente" si no hay evidencia suficiente.
- Seguridad: distingue problemas confirmados de riesgos potenciales. Nunca afirmes que la aplicación es segura solo porque no detectaste problemas -- dilo explícitamente como limitación si es el caso.
- Valoración económica y potencial de usuarios son estimaciones razonadas a partir de lo que ves (complejidad, tecnologías, alcance) y tu conocimiento general de mercado -- NUNCA inventes clientes, usuarios, ventas o demanda reales. Cada escenario (conservador/intermedio/optimista) lleva su propio razonamiento. "supuestos" y "limitaciones" son obligatorios y deben ser honestos sobre qué información falta. Usa "nivelConfianza" baja si hay poca información -- no la infles.
- No multipliques mecánicamente el valor por el porcentaje de progreso -- "analisisProgresoValor" es una explicación cualitativa, no una fórmula.
- No propongas ninguna funcionalidad nueva, documento, tarea ni idea -- esto es un expediente documental, no una propuesta de trabajo.
- Responde siempre en español.`;

/// Pura: prompt de síntesis -- recibe los resúmenes condensados de cada
/// módulo (nunca código crudo de archivo otra vez) más contexto de AppsDoc.
function _construirPromptSintesis({
  proyecto,
  resumenesPorModulo,
  funcionalidadesExistentes,
  documentosExistentes,
  progresoPorcentaje,
  expedienteAnterior,
}) {
  const lineas = [];
  lineas.push(`Síntesis del proyecto "${proyecto.nombre}".`);

  lineas.push('', '## Resúmenes condensados por módulo');
  const entradasModulo = Object.entries(resumenesPorModulo).filter(([, r]) => r);
  if (entradasModulo.length) {
    for (const [nombreModulo, resumen] of entradasModulo) {
      lineas.push(`\n--- Módulo: ${nombreModulo} ---`);
      lineas.push(`Resumen: ${resumen.resumenModulo}`);
      if (resumen.elementosDetectados.length) {
        lineas.push('Elementos detectados:');
        for (const el of resumen.elementosDetectados) {
          lineas.push(`- [${el.tipo}] ${el.nombre}: ${el.descripcion} (evidencia: ${el.evidencia})`);
        }
      }
      if (resumen.tecnologiasDetectadas.length) {
        lineas.push(`Tecnologías: ${resumen.tecnologiasDetectadas.join(', ')}`);
      }
    }
  } else {
    lineas.push('(no se pudo analizar ningún módulo)');
  }

  lineas.push('', '## Funcionalidades ya registradas formalmente en AppsDoc (contexto -- el catálogo del expediente es un inventario completo, puede incluirlas también)');
  lineas.push(funcionalidadesExistentes.length ? funcionalidadesExistentes.map((n) => `- ${n}`).join('\n') : '(ninguna)');

  lineas.push('', '## Documentos ya registrados formalmente en AppsDoc');
  lineas.push(documentosExistentes.length ? documentosExistentes.map((n) => `- ${n}`).join('\n') : '(ninguno)');

  lineas.push('', `## Progreso de desarrollo ya calculado por AppsDoc: ${progresoPorcentaje}%`);
  lineas.push('(Úsalo solo como referencia para "analisisProgresoValor" -- nunca lo recalcules ni lo repitas como si fuera tuyo.)');

  if (expedienteAnterior) {
    lineas.push('', '## Resumen del expediente confirmado anterior de este mismo proyecto (para mantener continuidad, no para copiar literalmente)');
    lineas.push(expedienteAnterior);
  }

  return lineas.join('\n');
}

/// Pura: parsea la síntesis final. Clampa cada enum a su valor conservador
/// por defecto (confianza->"pendiente", gravedad->"media",
/// nivelConfianza->"baja") en vez de fallar, igual criterio que
/// _parsearAnalisisRepositorio.
function _parsearExpediente(contentBlocks, { progresoPorcentaje = 0 } = {}) {
  const bloque = (contentBlocks || []).find((b) => b.type === 'tool_use' && b.name === 'registrar_expediente');
  if (!bloque || typeof bloque.input !== 'object' || bloque.input === null) {
    throw new HttpsError('internal', 'La IA no devolvió un expediente válido.');
  }
  const input = bloque.input;

  const texto = (v) => (typeof v === 'string' ? v.trim() : '');
  const lista = (v) => (Array.isArray(v) ? v.filter((x) => typeof x === 'string' && x.trim() !== '').map((x) => x.trim()) : []);
  const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : 0);

  const d = input.descripcionGeneral || {};
  const descripcionGeneral = {
    resumen: texto(d.resumen),
    propuestaValor: texto(d.propuestaValor),
    publicoObjetivo: texto(d.publicoObjetivo),
    estadoMadurez: texto(d.estadoMadurez),
  };
  if (!descripcionGeneral.resumen) throw new HttpsError('internal', 'La IA no devolvió una descripción general.');

  const pantallas = Array.isArray(input.pantallas)
    ? input.pantallas
        .filter((p) => p && typeof p.nombre === 'string' && p.nombre.trim() !== '')
        .map((p) => ({
          nombre: p.nombre.trim(),
          descripcionFuncion: texto(p.descripcionFuncion),
          archivoPrincipal: texto(p.archivoPrincipal),
          navegacion: texto(p.navegacion),
          pantallasRelacionadas: lista(p.pantallasRelacionadas),
        }))
    : [];

  const catalogoFuncionalidades = Array.isArray(input.catalogoFuncionalidades)
    ? input.catalogoFuncionalidades
        .filter((f) => f && typeof f.nombre === 'string' && f.nombre.trim() !== '')
        .map((f) => ({
          nombre: f.nombre.trim(),
          descripcion: texto(f.descripcion),
          confianza: CONFIANZAS_EXPEDIENTE_VALIDAS.includes(f.confianza) ? f.confianza : 'pendiente',
          evidencia: texto(f.evidencia),
          archivosRelacionados: lista(f.archivosRelacionados),
        }))
    : [];

  const a = input.arquitectura || {};
  const arquitectura = { resumen: texto(a.resumen), patrones: lista(a.patrones), tecnologias: lista(a.tecnologias) };

  const mapearHallazgos = (hs) =>
    Array.isArray(hs)
      ? hs
          .filter((h) => h && typeof h.titulo === 'string' && h.titulo.trim() !== '')
          .map((h, i) => ({
            id: `${Date.now()}-${i}`,
            titulo: h.titulo.trim(),
            descripcion: texto(h.descripcion),
            gravedad: GRAVEDADES_VALIDAS.includes(h.gravedad) ? h.gravedad : 'media',
            evidencia: texto(h.evidencia),
          }))
      : [];

  const c = input.calidad || {};
  const calidad = { resumen: texto(c.resumen), hallazgos: mapearHallazgos(c.hallazgos) };
  const s = input.seguridad || {};
  const seguridad = { resumen: texto(s.resumen), hallazgos: mapearHallazgos(s.hallazgos) };

  const mapearEscenarioEconomico = (e) => {
    const eo = e || {};
    return {
      costeDesarrolloEstimado: num(eo.costeDesarrolloEstimado),
      costeReconstruccionEstimado: num(eo.costeReconstruccionEstimado),
      valorProductoEstimado: num(eo.valorProductoEstimado),
      moneda: texto(eo.moneda) || 'EUR',
      razonamiento: texto(eo.razonamiento),
    };
  };
  const ve = input.valoracionEconomica || {};
  const valoracionEconomica = {
    conservador: mapearEscenarioEconomico(ve.conservador),
    intermedio: mapearEscenarioEconomico(ve.intermedio),
    optimista: mapearEscenarioEconomico(ve.optimista),
    supuestos: lista(ve.supuestos),
    limitaciones: texto(ve.limitaciones),
    nivelConfianza: NIVELES_CONFIANZA_VALORACION_VALIDOS.includes(ve.nivelConfianza) ? ve.nivelConfianza : 'baja',
  };

  const mapearEscenarioUsuarios = (e) => {
    const eo = e || {};
    return { usuariosEstimados: num(eo.usuariosEstimados), razonamiento: texto(eo.razonamiento) };
  };
  const pu = input.potencialUsuarios || {};
  const potencialUsuarios = {
    conservador: mapearEscenarioUsuarios(pu.conservador),
    intermedio: mapearEscenarioUsuarios(pu.intermedio),
    optimista: mapearEscenarioUsuarios(pu.optimista),
    segmentoObjetivo: texto(pu.segmentoObjetivo),
    supuestos: lista(pu.supuestos),
    limitaciones: texto(pu.limitaciones),
    nivelConfianza: NIVELES_CONFIANZA_VALORACION_VALIDOS.includes(pu.nivelConfianza) ? pu.nivelConfianza : 'baja',
  };

  const progresoValor = { progresoPorcentajeLeido: progresoPorcentaje, analisisTexto: texto(input.analisisProgresoValor) };

  return {
    descripcionGeneral,
    pantallas,
    catalogoFuncionalidades,
    arquitectura,
    calidad,
    seguridad,
    valoracionEconomica,
    potencialUsuarios,
    progresoValor,
  };
}

exports.generarExpediente = onCall(
  { region: REGION, secrets: [_anthropicKey], timeoutSeconds: 540, memory: '1GiB' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Debes estar autenticado.');
    const uid = request.auth.uid;
    const proyectoIdCrudo = request.data && request.data.proyectoId;
    if (typeof proyectoIdCrudo !== 'string' || proyectoIdCrudo.trim() === '') {
      throw new HttpsError('invalid-argument', 'Falta el identificador del proyecto.');
    }
    const proyectoId = proyectoIdCrudo.trim();

    const proyectoRef = db.collection('usuarios').doc(uid).collection('proyectos').doc(proyectoId);
    const proyectoSnap = await proyectoRef.get();
    if (!proyectoSnap.exists) throw new HttpsError('not-found', 'El proyecto no existe.');
    const proyecto = proyectoSnap.data();
    const propietario = proyecto.repoPropietario;
    const nombreRepo = proyecto.repoNombre;
    if (!propietario || !nombreRepo) {
      throw new HttpsError('failed-precondition', 'Este proyecto no tiene un repositorio de GitHub vinculado.');
    }

    const hoyISO = new Date().toISOString().slice(0, 10);
    await _comprobarYRegistrarUso(uid, hoyISO, PESO_EXPEDIENTE);

    const [funcSnap, docSnap] = await Promise.all([
      proyectoRef.collection('funcionalidades').get(),
      proyectoRef.collection('documentos').get(),
    ]);
    const funcionalidadesExistentes = funcSnap.docs.map((d) => d.data().nombre).filter(Boolean);
    const documentosExistentes = docSnap.docs.map((d) => d.data().titulo).filter(Boolean);
    const progresoPorcentaje = typeof proyecto.progresoPorcentaje === 'number' ? proyecto.progresoPorcentaje : 0;

    const { rama, sha } = await _obtenerRamaYCommit(propietario, nombreRepo);
    const tarball = await _descargarTarball(propietario, nombreRepo, rama);

    const todasEntradas = await _listarEntradasTar(tarball);
    const todasLasRutas = todasEntradas.map((e) => e.path).filter(Boolean);
    // Único punto de filtrado de todo el pipeline -- _agruparPorModulo recibe
    // solo rutas ya limpias y nunca vuelve a mirar el denylist.
    const rutasTexto = todasLasRutas.filter((p) => !_esArchivoIrrelevante(p));
    const truncadoArbol = todasEntradas.length >= MAX_RUTAS_ARBOL;

    const grupos = _agruparPorModulo(rutasTexto);
    const modulosAProcesar = _elegirModulosAProcesar(grupos);
    console.log(
      `[generarExpediente][diag] proyecto=${proyectoId} rutasTotal=${todasLasRutas.length} rutasTexto=${rutasTexto.length} ` +
        `grupos=${JSON.stringify(Object.fromEntries(Object.entries(grupos).map(([k, v]) => [k, v.length])))} ` +
        `modulosAProcesar=${JSON.stringify(modulosAProcesar)}`,
    );

    const apiKey = _anthropicKey.value();
    if (!apiKey) throw new HttpsError('internal', 'API key no configurada en el servidor.');

    let archivosAnalizados = 0;
    let archivosOmitidosTotal = 0;
    const resumenesPorModulo = {};
    // Secuencial (no Promise.all): acota memoria y tasa de peticiones a
    // Anthropic en vez de disparar hasta 6 llamadas en paralelo.
    for (const nombreModulo of modulosAProcesar) {
      const rutasModulo = grupos[nombreModulo] || [];
      if (rutasModulo.length === 0) continue;
      const rutasAIncluir = _priorizarArchivos(rutasModulo, MAX_ARCHIVOS_POR_MODULO);
      const contenidos = await _extraerContenidoTar(tarball, rutasAIncluir, PRESUPUESTO_CHARS_POR_MODULO);
      archivosAnalizados += contenidos.size;
      archivosOmitidosTotal += Math.max(0, rutasModulo.length - contenidos.size);
      if (contenidos.size === 0) continue;

      const promptModulo = _construirPromptModulo({ nombreModulo, archivosConContenido: contenidos });
      const dataModulo = await _llamarAnthropic(apiKey, {
        model: MODELO,
        max_tokens: 4096,
        system: _systemAnalisisModulo(nombreModulo),
        tools: [HERRAMIENTA_ANALISIS_MODULO],
        tool_choice: { type: 'auto' },
        messages: [{ role: 'user', content: promptModulo }],
      });
      resumenesPorModulo[nombreModulo] = _parsearAnalisisModulo(dataModulo.content);
      console.log(
        `[generarExpediente][diag] modulo=${nombreModulo} rutasModulo=${rutasModulo.length} archivosIncluidos=${contenidos.size} ` +
          `stopReason=${dataModulo.stop_reason} elementosDetectados=${resumenesPorModulo[nombreModulo].elementosDetectados.length}`,
      );
    }

    const truncado = truncadoArbol || archivosOmitidosTotal > 0;

    // Expediente confirmado anterior, para continuidad -- igual criterio que
    // "análisis automático anterior" en analizarRepositorio.
    const anteriorSnap = await proyectoRef
      .collection('expedientes')
      .where('estado', '==', 'confirmado')
      .orderBy('numeroVersion', 'desc')
      .limit(1)
      .get();
    const expedienteAnteriorDoc = anteriorSnap.docs[0] ? anteriorSnap.docs[0].data() : null;
    const expedienteAnterior =
      expedienteAnteriorDoc && expedienteAnteriorDoc.descripcionGeneral ? expedienteAnteriorDoc.descripcionGeneral.resumen || null : null;

    const promptSintesis = _construirPromptSintesis({
      proyecto: { nombre: proyecto.nombre || '' },
      resumenesPorModulo,
      funcionalidadesExistentes,
      documentosExistentes,
      progresoPorcentaje,
      expedienteAnterior,
    });

    const dataSintesis = await _llamarAnthropic(apiKey, {
      model: MODELO,
      max_tokens: 16000,
      system: SYSTEM_SINTESIS_EXPEDIENTE,
      tools: [HERRAMIENTA_SINTESIS_EXPEDIENTE],
      tool_choice: { type: 'auto' },
      messages: [{ role: 'user', content: promptSintesis }],
    });

    console.log(
      `[generarExpediente][diag] sintesis stopReason=${dataSintesis.stop_reason} modulosConResumen=${Object.keys(resumenesPorModulo).length}`,
    );
    // La síntesis cubre 8 secciones grandes en una sola llamada -- si el
    // modelo se queda sin tokens a mitad de generación, el JSON del tool_use
    // puede acabar incompleto y las secciones finales (calidad/seguridad/
    // valoración) llegan vacías sin que _parsearExpediente lo note (solo
    // exige "descripcionGeneral.resumen"). Mejor fallar con un mensaje claro
    // que guardar un expediente a medias disfrazado de completo.
    if (dataSintesis.stop_reason === 'max_tokens') {
      throw new HttpsError(
        'internal',
        'La respuesta de la IA se cortó por longitud antes de completar el expediente. Inténtalo de nuevo.',
      );
    }
    const expediente = _parsearExpediente(dataSintesis.content, { progresoPorcentaje });
    console.log(
      `[generarExpediente][diag] parseado pantallas=${expediente.pantallas.length} catalogo=${expediente.catalogoFuncionalidades.length} ` +
        `arquitecturaResumen=${expediente.arquitectura.resumen ? 'si' : 'no'} calidadHallazgos=${expediente.calidad.hallazgos.length} ` +
        `seguridadHallazgos=${expediente.seguridad.hallazgos.length} nivelConfianzaValoracion=${expediente.valoracionEconomica.nivelConfianza}`,
    );

    return {
      ...expediente,
      metaGeneracion: {
        modeloUsado: MODELO,
        etapasEjecutadas: Object.keys(resumenesPorModulo).length + 1,
        archivosAnalizados,
        archivosOmitidos: archivosOmitidosTotal,
        truncado,
      },
      repoCommitAnalizado: sha,
      repoRama: rama,
    };
  },
);

module.exports._validarPreguntaInput = _validarPreguntaInput;
module.exports._validarExtraccionInput = _validarExtraccionInput;
module.exports._evaluarLimite = _evaluarLimite;
module.exports._construirContexto = _construirContexto;
module.exports._parsearRespuestaTexto = _parsearRespuestaTexto;
module.exports._parsearPropuestaExtraida = _parsearPropuestaExtraida;
module.exports._esArchivoIrrelevante = _esArchivoIrrelevante;
module.exports._priorizarArchivos = _priorizarArchivos;
module.exports._listarEntradasTar = _listarEntradasTar;
module.exports._extraerContenidoTar = _extraerContenidoTar;
module.exports._construirPromptAnalisis = _construirPromptAnalisis;
module.exports._parsearAnalisisRepositorio = _parsearAnalisisRepositorio;
module.exports._agruparPorModulo = _agruparPorModulo;
module.exports._elegirModulosAProcesar = _elegirModulosAProcesar;
module.exports._construirPromptModulo = _construirPromptModulo;
module.exports._parsearAnalisisModulo = _parsearAnalisisModulo;
module.exports._construirPromptSintesis = _construirPromptSintesis;
module.exports._parsearExpediente = _parsearExpediente;
