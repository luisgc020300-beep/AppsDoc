// functions-tests/helpers.js
//
// Helpers compartidos por seguridad.test.js, el único test de este
// directorio que corre contra el Emulator Suite real (Firestore + Auth +
// Functions) -- mismo criterio que functions-tests de REPARA: llamar a
// las Cloud Functions callable por HTTP directo (protocolo documentado
// por Firebase) en vez de con el SDK cliente.
'use strict';

const admin = require('firebase-admin');

const PROJECT_ID = 'appsdoc-app';
const REGION = 'europe-west1';
const FIRESTORE_HOST = process.env.APPSDOC_TEST_FIRESTORE_HOST || '127.0.0.1:8080';
const AUTH_HOST = process.env.APPSDOC_TEST_AUTH_HOST || '127.0.0.1:9099';
const FUNCTIONS_HOST = process.env.APPSDOC_TEST_FUNCTIONS_HOST || '127.0.0.1:5001';

process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.FIREBASE_AUTH_EMULATOR_HOST = AUTH_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

let contador = 0;

function idUnico(prefijo) {
  contador += 1;
  return `${prefijo}-${Date.now()}-${contador}`;
}

// Crea un usuario real en el emulador de Auth y devuelve su uid + idToken.
async function crearUsuario() {
  const email = `${idUnico('user')}@test.local`;
  const res = await fetch(`http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password: 'Test1234!', returnSecureToken: true }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`crearUsuario: ${JSON.stringify(data)}`);
  return { uid: data.localId, idToken: data.idToken };
}

// Llama a una Cloud Function callable por HTTP directo. Nunca lanza por un
// error de la función (unauthenticated, not-found...) -- el propio test
// decide qué hacer con cada código; sí lanza si la petición de red falla.
async function llamar(nombreFuncion, idToken, payload) {
  const res = await fetch(`http://${FUNCTIONS_HOST}/${PROJECT_ID}/${REGION}/${nombreFuncion}`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(idToken ? { authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data: payload }),
  });
  const texto = await res.text();
  let body;
  try {
    body = JSON.parse(texto);
  } catch (e) {
    throw new Error(`llamar(${nombreFuncion}): respuesta no JSON (status ${res.status}): ${texto.slice(0, 500)}`);
  }
  return { status: res.status, result: body.result, error: body.error };
}

// Siembra un proyecto directamente con el Admin SDK (salta las reglas de
// Firestore, igual que sembrar fixtures en REPARA) con el uid del dueño
// ya como parte de la ruta.
async function crearProyecto(uid, overrides = {}) {
  const proyectoId = idUnico('proyecto');
  const ahora = admin.firestore.Timestamp.now();
  await db
    .collection('usuarios')
    .doc(uid)
    .collection('proyectos')
    .doc(proyectoId)
    .set({
      nombre: 'Proyecto de prueba',
      descripcion: '',
      estado: 'idea',
      progresoPorcentaje: 45,
      repoUrl: '',
      repoPropietario: '',
      repoNombre: '',
      createdAt: ahora,
      updatedAt: ahora,
      ...overrides,
    });
  return proyectoId;
}

module.exports = { db, admin, PROJECT_ID, REGION, idUnico, crearUsuario, llamar, crearProyecto };
