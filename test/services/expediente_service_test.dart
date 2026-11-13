// test/services/expediente_service_test.dart
import 'package:appsdoc/models/estado_expediente.dart';
import 'package:appsdoc/services/expediente_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _resultadoFuncion({List<Map<String, dynamic>>? pantallas, String resumen = 'Resumen generado.'}) => {
  'descripcionGeneral': {'resumen': resumen, 'propuestaValor': '', 'publicoObjetivo': '', 'estadoMadurez': ''},
  'pantallas': pantallas ?? [],
  'catalogoFuncionalidades': <Map<String, dynamic>>[],
  'arquitectura': {'resumen': '', 'patrones': [], 'tecnologias': []},
  'calidad': {'resumen': '', 'hallazgos': []},
  'seguridad': {'resumen': '', 'hallazgos': []},
  'valoracionEconomica': {
    'conservador': {},
    'intermedio': {},
    'optimista': {},
    'supuestos': [],
    'limitaciones': '',
    'nivelConfianza': 'baja',
  },
  'potencialUsuarios': {
    'conservador': {},
    'intermedio': {},
    'optimista': {},
    'segmentoObjetivo': '',
    'supuestos': [],
    'limitaciones': '',
    'nivelConfianza': 'baja',
  },
  'progresoValor': {'progresoPorcentajeLeido': 45, 'analisisTexto': ''},
  'metaGeneracion': {'modeloUsado': 'claude-sonnet-5-5', 'etapasEjecutadas': 3, 'archivosAnalizados': 10, 'archivosOmitidos': 0, 'truncado': false},
  'repoCommitAnalizado': 'abc1234',
  'repoRama': 'main',
};

void main() {
  late FakeFirebaseFirestore db;
  const proyectoId = 'p1';

  setUp(() {
    db = FakeFirebaseFirestore();
    ExpedienteService.debugFirestoreOverride = db;
    ExpedienteService.debugUidOverride = 'uid-1';
  });

  tearDown(() {
    ExpedienteService.debugFirestoreOverride = null;
    ExpedienteService.debugUidOverride = null;
    ExpedienteService.debugCallableOverride = null;
  });

  test('generar() guarda un borrador con numeroVersion 1 y lo devuelve streamVersiones()', () async {
    ExpedienteService.debugCallableOverride = (datos) async {
      expect(datos['proyectoId'], proyectoId);
      return _resultadoFuncion();
    };

    final expediente = await ExpedienteService.generar(proyectoId: proyectoId);

    expect(expediente.numeroVersion, 1);
    expect(expediente.estado, EstadoExpediente.borrador);
    expect(expediente.descripcionGeneral.resumen, 'Resumen generado.');

    final versiones = await ExpedienteService.streamVersiones(proyectoId).first;
    expect(versiones, hasLength(1));
    expect(versiones.single.id, expediente.id);
  });

  test('generar() dos veces numera las versiones correlativamente, más reciente primero en streamVersiones()', () async {
    ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion();

    await ExpedienteService.generar(proyectoId: proyectoId);
    final segundo = await ExpedienteService.generar(proyectoId: proyectoId);

    expect(segundo.numeroVersion, 2);
    final versiones = await ExpedienteService.streamVersiones(proyectoId).first;
    expect(versiones.map((e) => e.numeroVersion), [2, 1]);
  });

  group('emparejamiento de pantallas (pantallasCatalogo)', () {
    test('la primera generación crea una entrada nueva en pantallasCatalogo por cada pantalla detectada', () async {
      ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion(
        pantallas: [
          {'nombre': 'Login', 'archivoPrincipal': 'lib/screens/auth/login_screen.dart', 'descripcionFuncion': '', 'navegacion': '', 'pantallasRelacionadas': []},
        ],
      );

      final expediente = await ExpedienteService.generar(proyectoId: proyectoId);

      expect(expediente.pantallas, hasLength(1));
      expect(expediente.pantallas.single.claveEstable, isNotEmpty);
    });

    test('una pantalla con el mismo archivoPrincipal en una generación posterior reutiliza la misma claveEstable aunque cambie de nombre', () async {
      ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion(
        pantallas: [
          {'nombre': 'Login', 'archivoPrincipal': 'lib/screens/auth/login_screen.dart', 'descripcionFuncion': '', 'navegacion': '', 'pantallasRelacionadas': []},
        ],
      );
      final primero = await ExpedienteService.generar(proyectoId: proyectoId);
      final claveOriginal = primero.pantallas.single.claveEstable;

      ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion(
        pantallas: [
          {'nombre': 'Inicio de sesión', 'archivoPrincipal': 'lib/screens/auth/login_screen.dart', 'descripcionFuncion': '', 'navegacion': '', 'pantallasRelacionadas': []},
        ],
      );
      final segundo = await ExpedienteService.generar(proyectoId: proyectoId);

      expect(segundo.pantallas.single.claveEstable, claveOriginal);
      expect(segundo.pantallas.single.nombre, 'Inicio de sesión');
    });

    test('sin archivoPrincipal, una pantalla con el mismo nombre normalizado reutiliza la misma claveEstable', () async {
      ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion(
        pantallas: [
          {'nombre': '  Login  ', 'archivoPrincipal': '', 'descripcionFuncion': '', 'navegacion': '', 'pantallasRelacionadas': []},
        ],
      );
      final primero = await ExpedienteService.generar(proyectoId: proyectoId);
      final claveOriginal = primero.pantallas.single.claveEstable;

      ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion(
        pantallas: [
          {'nombre': 'LOGIN', 'archivoPrincipal': '', 'descripcionFuncion': '', 'navegacion': '', 'pantallasRelacionadas': []},
        ],
      );
      final segundo = await ExpedienteService.generar(proyectoId: proyectoId);

      expect(segundo.pantallas.single.claveEstable, claveOriginal);
    });
  });

  group('confirmar() / descartarBorrador() / editarCampo()', () {
    test('confirmar() marca la versión como confirmada y la hace visible en streamActualConfirmado()', () async {
      ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion();
      final borrador = await ExpedienteService.generar(proyectoId: proyectoId);

      expect(await ExpedienteService.streamActualConfirmado(proyectoId).first, isNull);

      await ExpedienteService.confirmar(proyectoId, borrador.id);

      final actual = await ExpedienteService.streamActualConfirmado(proyectoId).first;
      expect(actual, isNotNull);
      expect(actual!.id, borrador.id);
      expect(actual.estado, EstadoExpediente.confirmado);
      expect(actual.confirmadoEn, isNotNull);
    });

    test('descartarBorrador() elimina un borrador', () async {
      ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion();
      final borrador = await ExpedienteService.generar(proyectoId: proyectoId);

      await ExpedienteService.descartarBorrador(proyectoId, borrador.id);

      expect(await ExpedienteService.streamVersiones(proyectoId).first, isEmpty);
    });

    test('descartarBorrador() sobre una versión ya confirmada lanza y no la borra', () async {
      ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion();
      final borrador = await ExpedienteService.generar(proyectoId: proyectoId);
      await ExpedienteService.confirmar(proyectoId, borrador.id);

      await expectLater(ExpedienteService.descartarBorrador(proyectoId, borrador.id), throwsStateError);

      expect(await ExpedienteService.streamVersiones(proyectoId).first, hasLength(1));
    });

    test('editarCampo() sobre una versión confirmada actualiza el campo indicado', () async {
      ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion();
      final borrador = await ExpedienteService.generar(proyectoId: proyectoId);
      await ExpedienteService.confirmar(proyectoId, borrador.id);

      await ExpedienteService.editarCampo(proyectoId, borrador.id, {
        'descripcionGeneral': {'resumen': 'Corregido a mano', 'propuestaValor': '', 'publicoObjetivo': '', 'estadoMadurez': ''},
      });

      final actual = await ExpedienteService.streamActualConfirmado(proyectoId).first;
      expect(actual!.descripcionGeneral.resumen, 'Corregido a mano');
    });

    test('editarCampo() también funciona sobre un borrador (antes de confirmar) -- así la pantalla de revisión puede corregir texto', () async {
      ExpedienteService.debugCallableOverride = (datos) async => _resultadoFuncion();
      final borrador = await ExpedienteService.generar(proyectoId: proyectoId);

      await ExpedienteService.editarCampo(proyectoId, borrador.id, {
        'descripcionGeneral': {'resumen': 'Corregido antes de confirmar', 'propuestaValor': '', 'publicoObjetivo': '', 'estadoMadurez': ''},
      });

      final versiones = await ExpedienteService.streamVersiones(proyectoId).first;
      expect(versiones.single.descripcionGeneral.resumen, 'Corregido antes de confirmar');
      expect(versiones.single.estado, EstadoExpediente.borrador, reason: 'editarCampo nunca cambia el estado');
    });

    test('editarCampo() sobre un expediente inexistente lanza', () async {
      await expectLater(
        ExpedienteService.editarCampo(proyectoId, 'no-existe', {'descripcionGeneral': {}}),
        throwsStateError,
      );
    });
  });

  test('sin sesión (uid null), streamVersiones() devuelve vacío y generar() lanza', () async {
    ExpedienteService.debugUidOverride = null;

    expect(await ExpedienteService.streamVersiones(proyectoId).first, isEmpty);
    await expectLater(ExpedienteService.generar(proyectoId: proyectoId), throwsStateError);
  });
}
