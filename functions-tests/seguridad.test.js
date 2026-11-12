// functions-tests/seguridad.test.js
//
// Único test de este directorio que corre contra el Emulator Suite real
// (Firestore + Auth + Functions) -- `npm run test:emulator`. Comprueba
// exactamente los caminos que NUNCA deben llegar a llamar a Anthropic:
// sin autenticación, proyectoId de otro usuario, argumentos inválidos y
// límite diario ya agotado. El camino feliz (llamar realmente a Anthropic)
// no se prueba aquí -- eso exigiría una clave real o un servidor de
// prueba; el parseo de su respuesta ya está cubierto en anthropic.test.js
// con bloques de contenido fabricados a mano.
const test = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, crearProyecto, llamar } = require('./helpers');

test('preguntarAsistente sin autenticación es rechazada', async () => {
  const { error } = await llamar('preguntarAsistente', null, { proyectoId: 'x', pregunta: '¿Qué falta?' });
  assert.equal(error.status, 'UNAUTHENTICATED');
});

test('extraerAuditoria sin autenticación es rechazada', async () => {
  const { error } = await llamar('extraerAuditoria', null, { proyectoId: 'x', texto: 'auditoría pegada' });
  assert.equal(error.status, 'UNAUTHENTICATED');
});

test('preguntarAsistente con un proyecto que no es del que llama devuelve not-found, no los datos de otro', async () => {
  const propietario = await crearUsuario();
  const intruso = await crearUsuario();
  const proyectoId = await crearProyecto(propietario.uid, { nombre: 'Proyecto privado del propietario' });

  const { error } = await llamar('preguntarAsistente', intruso.idToken, { proyectoId, pregunta: '¿Qué falta?' });
  assert.equal(error.status, 'NOT_FOUND');
});

test('extraerAuditoria con un proyecto que no es del que llama devuelve not-found', async () => {
  const propietario = await crearUsuario();
  const intruso = await crearUsuario();
  const proyectoId = await crearProyecto(propietario.uid);

  const { error } = await llamar('extraerAuditoria', intruso.idToken, { proyectoId, texto: 'auditoría pegada' });
  assert.equal(error.status, 'NOT_FOUND');
});

test('preguntarAsistente con proyectoId vacío devuelve invalid-argument', async () => {
  const user = await crearUsuario();
  const { error } = await llamar('preguntarAsistente', user.idToken, { proyectoId: '', pregunta: 'x' });
  assert.equal(error.status, 'INVALID_ARGUMENT');
});

test('extraerAuditoria con texto vacío devuelve invalid-argument', async () => {
  const user = await crearUsuario();
  const proyectoId = await crearProyecto(user.uid);
  const { error } = await llamar('extraerAuditoria', user.idToken, { proyectoId, texto: '   ' });
  assert.equal(error.status, 'INVALID_ARGUMENT');
});

test('preguntarAsistente respeta el límite diario ya agotado, sin llegar a llamar a la IA', async () => {
  const user = await crearUsuario();
  const proyectoId = await crearProyecto(user.uid);
  const hoyISO = new Date().toISOString().slice(0, 10);
  // Sembrado directo con el Admin SDK -- el mismo límite (40) que usa la
  // función en producción, para no depender de ninguna variable de
  // entorno especial de test.
  await db.collection('usuarios').doc(user.uid).collection('usoIA').doc(hoyISO).set({ peticiones: 40 });

  const { error } = await llamar('preguntarAsistente', user.idToken, { proyectoId, pregunta: '¿Qué falta?' });
  assert.equal(error.status, 'RESOURCE_EXHAUSTED');
});

test('extraerAuditoria respeta el límite diario ya agotado', async () => {
  const user = await crearUsuario();
  const proyectoId = await crearProyecto(user.uid);
  const hoyISO = new Date().toISOString().slice(0, 10);
  await db.collection('usuarios').doc(user.uid).collection('usoIA').doc(hoyISO).set({ peticiones: 40 });

  const { error } = await llamar('extraerAuditoria', user.idToken, { proyectoId, texto: 'auditoría pegada de sobra' });
  assert.equal(error.status, 'RESOURCE_EXHAUSTED');
});

// ---------------------------------------------------------------------------
// analizarRepositorio (Fase 9) -- los mismos caminos de seguridad, más el
// de "proyecto sin repositorio vinculado" (nunca debería llegar siquiera a
// intentar descargar nada de GitHub).
// ---------------------------------------------------------------------------

test('analizarRepositorio sin autenticación es rechazada', async () => {
  const { error } = await llamar('analizarRepositorio', null, { proyectoId: 'x' });
  assert.equal(error.status, 'UNAUTHENTICATED');
});

test('analizarRepositorio con proyectoId vacío devuelve invalid-argument', async () => {
  const user = await crearUsuario();
  const { error } = await llamar('analizarRepositorio', user.idToken, { proyectoId: '' });
  assert.equal(error.status, 'INVALID_ARGUMENT');
});

test('analizarRepositorio con un proyecto que no es del que llama devuelve not-found', async () => {
  const propietario = await crearUsuario();
  const intruso = await crearUsuario();
  const proyectoId = await crearProyecto(propietario.uid, {
    repoUrl: 'https://github.com/owner/repo',
    repoPropietario: 'owner',
    repoNombre: 'repo',
  });

  const { error } = await llamar('analizarRepositorio', intruso.idToken, { proyectoId });
  assert.equal(error.status, 'NOT_FOUND');
});

test('analizarRepositorio sin repositorio vinculado devuelve failed-precondition, sin tocar GitHub', async () => {
  const user = await crearUsuario();
  const proyectoId = await crearProyecto(user.uid); // repoPropietario/repoNombre vacíos por defecto

  const { error } = await llamar('analizarRepositorio', user.idToken, { proyectoId });
  assert.equal(error.status, 'FAILED_PRECONDITION');
});

test('analizarRepositorio respeta el límite diario ya agotado, sin llegar a llamar a GitHub ni a la IA', async () => {
  const user = await crearUsuario();
  const proyectoId = await crearProyecto(user.uid, {
    repoUrl: 'https://github.com/owner/repo',
    repoPropietario: 'owner',
    repoNombre: 'repo',
  });
  const hoyISO = new Date().toISOString().slice(0, 10);
  await db.collection('usuarios').doc(user.uid).collection('usoIA').doc(hoyISO).set({ peticiones: 40 });

  const { error } = await llamar('analizarRepositorio', user.idToken, { proyectoId });
  assert.equal(error.status, 'RESOURCE_EXHAUSTED');
});
