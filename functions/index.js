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

function _evaluarLimite(peticionesHoy, limiteDiario) {
  const actual = typeof peticionesHoy === 'number' ? peticionesHoy : 0;
  if (actual >= limiteDiario) {
    return { permitido: false, nuevoContador: actual };
  }
  return { permitido: true, nuevoContador: actual + 1 };
}

async function _comprobarYRegistrarUso(uid, hoyISO) {
  const ref = db.collection('usuarios').doc(uid).collection('usoIA').doc(hoyISO);
  const permitido = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const decision = _evaluarLimite(snap.exists ? snap.data().peticiones : 0, LIMITE_DIARIO);
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
  'Vas a recibir el texto de una auditoría o revisión de un proyecto de software, normalmente pegada tal cual desde otra conversación con Claude. Analízalo y usa la herramienta "extraer_auditoria" para devolver: un resumen breve, la lista de hallazgos (con título, descripción y gravedad baja/media/alta/critica) y una lista de tareas accionables derivadas de esos hallazgos. No inventes hallazgos que no estén respaldados por el texto. Responde siempre en español, usando la herramienta -- nunca con texto libre.';

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

  // Sin "thinking": la API de Anthropic no admite tool_choice forzado
  // junto con thinking activado, y aquí interesa forzar la herramienta
  // para garantizar una extracción estructurada, no texto libre.
  const data = await _llamarAnthropic(apiKey, {
    model: MODELO,
    max_tokens: 2048,
    system: SYSTEM_EXTRAER,
    tools: [HERRAMIENTA_EXTRAER_AUDITORIA],
    tool_choice: { type: 'tool', name: 'extraer_auditoria' },
    messages: [{ role: 'user', content: texto }],
  });

  return _parsearPropuestaExtraida(data.content);
});

module.exports._validarPreguntaInput = _validarPreguntaInput;
module.exports._validarExtraccionInput = _validarExtraccionInput;
module.exports._evaluarLimite = _evaluarLimite;
module.exports._construirContexto = _construirContexto;
module.exports._parsearRespuestaTexto = _parsearRespuestaTexto;
module.exports._parsearPropuestaExtraida = _parsearPropuestaExtraida;
