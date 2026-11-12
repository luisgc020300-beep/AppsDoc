// functions-tests/validacion.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { _validarPreguntaInput, _validarExtraccionInput } = require('../functions/index.js');

function codigoDe(fn) {
  try {
    fn();
    return null;
  } catch (e) {
    return e.code;
  }
}

test('_validarPreguntaInput: recorta espacios y acepta una entrada correcta', () => {
  const r = _validarPreguntaInput({ proyectoId: '  p1  ', pregunta: '  ¿Qué falta para publicar?  ' });
  assert.equal(r.proyectoId, 'p1');
  assert.equal(r.pregunta, '¿Qué falta para publicar?');
  assert.equal(r.githubResumen, null);
});

test('_validarPreguntaInput: conserva githubResumen cuando es un objeto', () => {
  const r = _validarPreguntaInput({ proyectoId: 'p1', pregunta: 'x', githubResumen: { ramaPrincipal: 'main' } });
  assert.deepEqual(r.githubResumen, { ramaPrincipal: 'main' });
});

test('_validarPreguntaInput: ignora githubResumen si no es un objeto plano', () => {
  const r = _validarPreguntaInput({ proyectoId: 'p1', pregunta: 'x', githubResumen: ['no', 'es', 'un', 'objeto'] });
  assert.equal(r.githubResumen, null);
});

test('_validarPreguntaInput: rechaza proyectoId vacío o ausente', () => {
  assert.equal(codigoDe(() => _validarPreguntaInput({ proyectoId: '', pregunta: 'x' })), 'invalid-argument');
  assert.equal(codigoDe(() => _validarPreguntaInput({ pregunta: 'x' })), 'invalid-argument');
});

test('_validarPreguntaInput: rechaza una pregunta vacía, ausente o solo espacios', () => {
  assert.equal(codigoDe(() => _validarPreguntaInput({ proyectoId: 'p1', pregunta: '' })), 'invalid-argument');
  assert.equal(codigoDe(() => _validarPreguntaInput({ proyectoId: 'p1', pregunta: '   ' })), 'invalid-argument');
  assert.equal(codigoDe(() => _validarPreguntaInput({ proyectoId: 'p1' })), 'invalid-argument');
});

test('_validarPreguntaInput: rechaza una pregunta de más de 4000 caracteres', () => {
  const larga = 'a'.repeat(4001);
  assert.equal(codigoDe(() => _validarPreguntaInput({ proyectoId: 'p1', pregunta: larga })), 'invalid-argument');
});

test('_validarPreguntaInput: acepta exactamente 4000 caracteres', () => {
  const limite = 'a'.repeat(4000);
  assert.doesNotThrow(() => _validarPreguntaInput({ proyectoId: 'p1', pregunta: limite }));
});

test('_validarExtraccionInput: recorta espacios y acepta una entrada correcta', () => {
  const r = _validarExtraccionInput({ proyectoId: '  p1  ', texto: '  Hallazgo: X  ' });
  assert.equal(r.proyectoId, 'p1');
  assert.equal(r.texto, 'Hallazgo: X');
});

test('_validarExtraccionInput: rechaza proyectoId o texto vacíos', () => {
  assert.equal(codigoDe(() => _validarExtraccionInput({ proyectoId: '', texto: 'x' })), 'invalid-argument');
  assert.equal(codigoDe(() => _validarExtraccionInput({ proyectoId: 'p1', texto: '   ' })), 'invalid-argument');
});

test('_validarExtraccionInput: rechaza un texto de más de 20000 caracteres', () => {
  const larga = 'a'.repeat(20001);
  assert.equal(codigoDe(() => _validarExtraccionInput({ proyectoId: 'p1', texto: larga })), 'invalid-argument');
});
