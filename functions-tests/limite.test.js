// functions-tests/limite.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { _evaluarLimite } = require('../functions/index.js');

test('por debajo del límite, permite e incrementa el contador', () => {
  const r = _evaluarLimite(5, 40);
  assert.equal(r.permitido, true);
  assert.equal(r.nuevoContador, 6);
});

test('justo en el límite, bloquea sin incrementar', () => {
  const r = _evaluarLimite(40, 40);
  assert.equal(r.permitido, false);
  assert.equal(r.nuevoContador, 40);
});

test('por encima del límite (no debería pasar, pero por si acaso), bloquea', () => {
  const r = _evaluarLimite(41, 40);
  assert.equal(r.permitido, false);
});

test('sin ninguna petición todavía (undefined), permite la primera', () => {
  const r = _evaluarLimite(undefined, 40);
  assert.equal(r.permitido, true);
  assert.equal(r.nuevoContador, 1);
});

test('un límite de 1 permite exactamente una petición y bloquea la segunda', () => {
  const primera = _evaluarLimite(0, 1);
  assert.equal(primera.permitido, true);
  const segunda = _evaluarLimite(primera.nuevoContador, 1);
  assert.equal(segunda.permitido, false);
});

test('peso>1: por debajo del límite, permite e incrementa el contador en "peso" unidades', () => {
  const r = _evaluarLimite(5, 40, 10);
  assert.equal(r.permitido, true);
  assert.equal(r.nuevoContador, 15);
});

test('peso>1: si "actual + peso" supera el límite, bloquea sin incrementar', () => {
  const r = _evaluarLimite(35, 40, 10);
  assert.equal(r.permitido, false);
  assert.equal(r.nuevoContador, 35);
});

test('peso>1: justo en el límite exacto, permite', () => {
  const r = _evaluarLimite(30, 40, 10);
  assert.equal(r.permitido, true);
  assert.equal(r.nuevoContador, 40);
});

test('sin peso explícito (llamadas existentes de 2 argumentos) se comporta igual que antes', () => {
  const conDosArgumentos = _evaluarLimite(5, 40);
  const conPesoUnoExplicito = _evaluarLimite(5, 40, 1);
  assert.deepEqual(conDosArgumentos, conPesoUnoExplicito);
});
