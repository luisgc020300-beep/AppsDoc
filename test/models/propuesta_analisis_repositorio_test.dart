// test/models/propuesta_analisis_repositorio_test.dart
import 'package:appsdoc/models/categoria_documento.dart';
import 'package:appsdoc/models/estado_funcionalidad.dart';
import 'package:appsdoc/models/gravedad_hallazgo.dart';
import 'package:appsdoc/models/propuesta_analisis_repositorio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PropuestaAnalisisRepositorio.fromJson() parsea todas las secciones', () {
    final propuesta = PropuestaAnalisisRepositorio.fromJson({
      'resumen': 'App Flutter de gestión de proyectos.',
      'arquitecturaDetectada': 'Flutter + Firebase, patrón de servicios estáticos.',
      'tecnologias': ['Flutter', 'Dart', 'Firebase'],
      'documentos': [
        {'titulo': 'Arquitectura general', 'categoria': 'arquitectura', 'contenido': '# Arquitectura'},
      ],
      'funcionalidades': [
        {
          'nombre': 'Login',
          'descripcion': 'Email y contraseña',
          'estadoSugerido': 'completada',
          'confianza': 'alta',
          'evidencia': 'lib/screens/auth/login_screen.dart',
        },
      ],
      'hallazgos': [
        {'titulo': 'Falta rate limit', 'descripcion': 'En el endpoint X', 'gravedad': 'alta'},
      ],
      'tareas': [
        {'titulo': 'Añadir tests', 'descripcion': ''},
      ],
      'ideas': [
        {'titulo': 'Modo offline', 'descripcion': ''},
      ],
      'truncado': true,
      'archivosAnalizados': 40,
      'archivosOmitidos': 12,
      'commitAnalizado': 'abc1234',
      'rama': 'main',
    });

    expect(propuesta.resumen, 'App Flutter de gestión de proyectos.');
    expect(propuesta.arquitecturaDetectada, 'Flutter + Firebase, patrón de servicios estáticos.');
    expect(propuesta.tecnologias, ['Flutter', 'Dart', 'Firebase']);
    expect(propuesta.documentos, hasLength(1));
    expect(propuesta.documentos.single.categoria, CategoriaDocumento.arquitectura);
    expect(propuesta.funcionalidades, hasLength(1));
    expect(propuesta.funcionalidades.single.estadoSugerido, EstadoFuncionalidad.completada);
    expect(propuesta.funcionalidades.single.confianza, ConfianzaDeteccion.alta);
    expect(propuesta.hallazgos, hasLength(1));
    expect(propuesta.hallazgos.single.gravedad, GravedadHallazgo.alta);
    expect(propuesta.tareas, hasLength(1));
    expect(propuesta.ideas, hasLength(1));
    expect(propuesta.truncado, true);
    expect(propuesta.archivosAnalizados, 40);
    expect(propuesta.archivosOmitidos, 12);
    expect(propuesta.commitAnalizado, 'abc1234');
    expect(propuesta.rama, 'main');
  });

  test('PropuestaAnalisisRepositorio.fromJson() con listas ausentes cae a vacías y truncado a false', () {
    final propuesta = PropuestaAnalisisRepositorio.fromJson({'resumen': 'X'});

    expect(propuesta.tecnologias, isEmpty);
    expect(propuesta.documentos, isEmpty);
    expect(propuesta.funcionalidades, isEmpty);
    expect(propuesta.hallazgos, isEmpty);
    expect(propuesta.tareas, isEmpty);
    expect(propuesta.ideas, isEmpty);
    expect(propuesta.truncado, false);
    expect(propuesta.archivosAnalizados, 0);
    expect(propuesta.commitAnalizado, isNull);
  });

  test('FuncionalidadDetectada.fromJson() con estadoSugerido/confianza desconocidos cae a los valores más conservadores', () {
    final f = FuncionalidadDetectada.fromJson({'nombre': 'X', 'estadoSugerido': 'rarisimo', 'confianza': 'extrema'});

    expect(f.estadoSugerido, EstadoFuncionalidad.planificada);
    expect(f.confianza, ConfianzaDeteccion.baja);
  });

  test('DocumentoPropuesto.fromJson() con categoria desconocida cae a nota', () {
    final d = DocumentoPropuesto.fromJson({'titulo': 'X', 'categoria': 'no-existe'});

    expect(d.categoria, CategoriaDocumento.nota);
  });
}
