// functions-tests/contexto.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { _construirContexto } = require('../functions/index.js');

function datosVacios(overrides = {}) {
  return {
    proyecto: { nombre: 'REPARA', descripcion: '', estado: 'enDesarrollo', progresoPorcentaje: 45 },
    funcionalidades: [],
    documentos: [],
    tareas: [],
    ideas: [],
    auditorias: [],
    historial: [],
    githubResumen: null,
    ...overrides,
  };
}

test('incluye nombre, estado y porcentaje de progreso del proyecto', () => {
  const texto = _construirContexto(datosVacios());
  assert.match(texto, /Proyecto: REPARA/);
  assert.match(texto, /Estado: enDesarrollo/);
  assert.match(texto, /Progreso hacia publicar: 45%/);
});

test('omite la línea de descripción cuando está vacía, pero la incluye cuando no', () => {
  const sinDescripcion = _construirContexto(datosVacios());
  assert.doesNotMatch(sinDescripcion, /Descripción:/);

  const conDescripcion = _construirContexto(
    datosVacios({ proyecto: { nombre: 'REPARA', descripcion: 'Mantenimiento del hogar', estado: 'idea', progresoPorcentaje: 0 } }),
  );
  assert.match(conDescripcion, /Descripción: Mantenimiento del hogar/);
});

test('todas las listas vacías muestran "(ninguna todavía)" en cada sección', () => {
  const texto = _construirContexto(datosVacios());
  assert.equal((texto.match(/\(ninguna todavía\)/g) || []).length, 5);
  assert.match(texto, /\(sin actividad todavía\)/);
  assert.match(texto, /\(sin repositorio conectado, o sin datos disponibles en este momento\)/);
});

test('lista funcionalidades, documentos (truncando contenido largo), tareas e ideas', () => {
  const texto = _construirContexto(
    datosVacios({
      funcionalidades: [{ nombre: 'Login', descripcion: 'Con email', estado: 'completada' }],
      documentos: [{ titulo: 'Arquitectura', categoria: 'arquitectura', contenido: 'x'.repeat(600) }],
      tareas: [{ titulo: 'Escribir tests', estado: 'pendiente', prioridad: 'alta', fechaLimite: '2026-12-01T00:00:00.000Z' }],
      ideas: [{ titulo: 'Soporte offline', descripcion: '', estado: 'nueva' }],
    }),
  );

  assert.match(texto, /- \[completada\] Login: Con email/);
  assert.match(texto, /- \[arquitectura\] Arquitectura: x{500}…/);
  assert.match(texto, /- \[pendiente\]\[prioridad alta\] Escribir tests \(vence: 2026-12-01T00:00:00\.000Z\)/);
  assert.match(texto, /- \[nueva\] Soporte offline/);
});

test('lista auditorías con sus hallazgos anidados', () => {
  const texto = _construirContexto(
    datosVacios({
      auditorias: [
        {
          fecha: '2026-11-01T00:00:00.000Z',
          origen: 'claude',
          resultado: 'conObservaciones',
          resumen: 'Primera revisión',
          hallazgos: [{ titulo: 'Falta validación', descripcion: 'En el formulario', gravedad: 'alta', estado: 'abierto' }],
        },
      ],
    }),
  );

  assert.match(texto, /- 2026-11-01T00:00:00\.000Z \[claude\] resultado: conObservaciones -- Primera revisión/);
  assert.match(texto, /    · \[alta\]\[abierto\] Falta validación: En el formulario/);
});

test('incluye el resumen de GitHub cuando se proporciona', () => {
  const texto = _construirContexto(
    datosVacios({
      githubResumen: {
        ramaPrincipal: 'main',
        ultimoCommitMensaje: 'fix: progreso real',
        ultimoCommitFecha: '2026-11-10T08:30:00.000Z',
        actualizadoEn: '2026-11-01T10:00:00.000Z',
      },
    }),
  );

  assert.match(texto, /Rama principal: main\. Último commit: "fix: progreso real"/);
});

test('el historial se lista en el orden recibido, más reciente primero', () => {
  const texto = _construirContexto(
    datosVacios({
      historial: [
        { fecha: '2026-11-10T00:00:00.000Z', entidad: 'tarea', descripcion: 'Tarea creada: "X"' },
        { fecha: '2026-11-01T00:00:00.000Z', entidad: 'proyecto', descripcion: 'Proyecto creado: "REPARA"' },
      ],
    }),
  );

  const idxTarea = texto.indexOf('Tarea creada');
  const idxProyecto = texto.indexOf('Proyecto creado');
  assert.ok(idxTarea > -1 && idxProyecto > -1 && idxTarea < idxProyecto);
});
