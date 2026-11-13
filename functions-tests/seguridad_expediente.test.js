// functions-tests/seguridad_expediente.test.js
//
// Fase 10 (expediente integral) -- mismo criterio que seguridad.test.js:
// corre contra el Emulator Suite real (`npm run test:emulator`) y comprueba
// exactamente los caminos que NUNCA deben llegar a descargar nada de GitHub
// ni a llamar a Anthropic: sin autenticación, proyecto de otro usuario,
// argumentos inválidos, sin repositorio vinculado, y límite diario agotado
// -- este último verificando explícitamente el peso ponderado
// (PESO_EXPEDIENTE=10), no solo el límite a secas que ya cubre
// analizarRepositorio.
const test = require('node:test');
const assert = require('node:assert/strict');
const { db, crearUsuario, crearProyecto, llamar } = require('./helpers');

test('generarExpediente sin autenticación es rechazada', async () => {
  const { error } = await llamar('generarExpediente', null, { proyectoId: 'x' });
  assert.equal(error.status, 'UNAUTHENTICATED');
});

test('generarExpediente con proyectoId vacío devuelve invalid-argument', async () => {
  const user = await crearUsuario();
  const { error } = await llamar('generarExpediente', user.idToken, { proyectoId: '' });
  assert.equal(error.status, 'INVALID_ARGUMENT');
});

test('generarExpediente con un proyecto que no es del que llama devuelve not-found', async () => {
  const propietario = await crearUsuario();
  const intruso = await crearUsuario();
  const proyectoId = await crearProyecto(propietario.uid, {
    repoUrl: 'https://github.com/owner/repo',
    repoPropietario: 'owner',
    repoNombre: 'repo',
  });

  const { error } = await llamar('generarExpediente', intruso.idToken, { proyectoId });
  assert.equal(error.status, 'NOT_FOUND');
});

test('generarExpediente sin repositorio vinculado devuelve failed-precondition, sin tocar GitHub', async () => {
  const user = await crearUsuario();
  const proyectoId = await crearProyecto(user.uid); // repoPropietario/repoNombre vacíos por defecto

  const { error } = await llamar('generarExpediente', user.idToken, { proyectoId });
  assert.equal(error.status, 'FAILED_PRECONDITION');
});

test('generarExpediente respeta el límite diario ponderado (PESO_EXPEDIENTE=10): 35 peticiones ya hechas bloquea aunque esté por debajo del límite a secas', async () => {
  const user = await crearUsuario();
  const proyectoId = await crearProyecto(user.uid, {
    repoUrl: 'https://github.com/owner/repo',
    repoPropietario: 'owner',
    repoNombre: 'repo',
  });
  const hoyISO = new Date().toISOString().slice(0, 10);
  // 35 < 40 (el límite diario): una llamada normal de peso 1 pasaría. Con
  // generarExpediente pesando 10, 35+10=45>40 -- debe bloquear igual, sin
  // llegar a descargar nada de GitHub ni a llamar a la IA.
  await db.collection('usuarios').doc(user.uid).collection('usoIA').doc(hoyISO).set({ peticiones: 35 });

  const { error } = await llamar('generarExpediente', user.idToken, { proyectoId });
  assert.equal(error.status, 'RESOURCE_EXHAUSTED');
});

test('generarExpediente con el límite ya agotado del todo (40 peticiones) también bloquea', async () => {
  const user = await crearUsuario();
  const proyectoId = await crearProyecto(user.uid, {
    repoUrl: 'https://github.com/owner/repo',
    repoPropietario: 'owner',
    repoNombre: 'repo',
  });
  const hoyISO = new Date().toISOString().slice(0, 10);
  await db.collection('usuarios').doc(user.uid).collection('usoIA').doc(hoyISO).set({ peticiones: 40 });

  const { error } = await llamar('generarExpediente', user.idToken, { proyectoId });
  assert.equal(error.status, 'RESOURCE_EXHAUSTED');
});
