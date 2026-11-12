// functions-tests/anthropic.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { _parsearRespuestaTexto, _parsearPropuestaExtraida } = require('../functions/index.js');

function codigoDe(fn) {
  try {
    fn();
    return null;
  } catch (e) {
    return e.code;
  }
}

test('_parsearRespuestaTexto: extrae el bloque de texto e ignora el de thinking', () => {
  const texto = _parsearRespuestaTexto([
    { type: 'thinking', thinking: 'razonamiento interno, nunca debe llegar al usuario' },
    { type: 'text', text: 'Te falta documentación de arquitectura.' },
  ]);
  assert.equal(texto, 'Te falta documentación de arquitectura.');
});

test('_parsearRespuestaTexto: sin bloque de texto, lanza internal', () => {
  assert.equal(codigoDe(() => _parsearRespuestaTexto([{ type: 'thinking', thinking: 'x' }])), 'internal');
  assert.equal(codigoDe(() => _parsearRespuestaTexto([])), 'internal');
  assert.equal(codigoDe(() => _parsearRespuestaTexto(undefined)), 'internal');
});

test('_parsearRespuestaTexto: un bloque de texto vacío también se rechaza', () => {
  assert.equal(codigoDe(() => _parsearRespuestaTexto([{ type: 'text', text: '   ' }])), 'internal');
});

function bloqueHerramienta(input) {
  return [{ type: 'tool_use', name: 'extraer_auditoria', input }];
}

test('_parsearPropuestaExtraida: extrae resumen, hallazgos y tareas de la herramienta', () => {
  const r = _parsearPropuestaExtraida(
    bloqueHerramienta({
      resumen: 'Auditoría de seguridad pre-lanzamiento.',
      hallazgos: [{ titulo: 'Falta rate limit', descripcion: 'En el endpoint X', gravedad: 'alta' }],
      tareas: [{ titulo: 'Añadir rate limit', descripcion: '' }],
    }),
  );

  assert.equal(r.resumen, 'Auditoría de seguridad pre-lanzamiento.');
  assert.deepEqual(r.hallazgos, [{ titulo: 'Falta rate limit', descripcion: 'En el endpoint X', gravedad: 'alta' }]);
  assert.deepEqual(r.tareas, [{ titulo: 'Añadir rate limit', descripcion: '' }]);
});

test('_parsearPropuestaExtraida: una gravedad inválida o ausente cae a "media"', () => {
  const r = _parsearPropuestaExtraida(
    bloqueHerramienta({
      resumen: 'X',
      hallazgos: [
        { titulo: 'A', gravedad: 'catastrofica' },
        { titulo: 'B' },
      ],
      tareas: [],
    }),
  );
  assert.equal(r.hallazgos[0].gravedad, 'media');
  assert.equal(r.hallazgos[1].gravedad, 'media');
});

test('_parsearPropuestaExtraida: descarta hallazgos y tareas sin título', () => {
  const r = _parsearPropuestaExtraida(
    bloqueHerramienta({
      resumen: 'X',
      hallazgos: [{ titulo: '', gravedad: 'alta' }, { gravedad: 'baja' }, { titulo: 'Válido', gravedad: 'baja' }],
      tareas: [{ titulo: '' }, { titulo: 'Válida' }],
    }),
  );
  assert.equal(r.hallazgos.length, 1);
  assert.equal(r.hallazgos[0].titulo, 'Válido');
  assert.equal(r.tareas.length, 1);
  assert.equal(r.tareas[0].titulo, 'Válida');
});

test('_parsearPropuestaExtraida: sin resumen, lanza internal', () => {
  assert.equal(codigoDe(() => _parsearPropuestaExtraida(bloqueHerramienta({ hallazgos: [], tareas: [] }))), 'internal');
  assert.equal(codigoDe(() => _parsearPropuestaExtraida(bloqueHerramienta({ resumen: '  ', hallazgos: [], tareas: [] }))), 'internal');
});

test('_parsearPropuestaExtraida: sin el bloque de la herramienta, lanza internal', () => {
  assert.equal(codigoDe(() => _parsearPropuestaExtraida([{ type: 'text', text: 'respuesta libre, no debería pasar' }])), 'internal');
  assert.equal(codigoDe(() => _parsearPropuestaExtraida([])), 'internal');
});

test('_parsearPropuestaExtraida: hallazgos/tareas ausentes del todo se tratan como listas vacías', () => {
  const r = _parsearPropuestaExtraida(bloqueHerramienta({ resumen: 'X' }));
  assert.deepEqual(r.hallazgos, []);
  assert.deepEqual(r.tareas, []);
});
