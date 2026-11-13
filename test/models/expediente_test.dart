// test/models/expediente_test.dart
import 'package:appsdoc/models/confianza_expediente.dart';
import 'package:appsdoc/models/estado_expediente.dart';
import 'package:appsdoc/models/expediente.dart';
import 'package:appsdoc/models/gravedad_hallazgo.dart';
import 'package:appsdoc/models/nivel_confianza_valoracion.dart';
import 'package:flutter_test/flutter_test.dart';

Expediente _expedienteCompleto() {
  final ahora = DateTime(2026, 11, 13, 10);
  return Expediente(
    id: 'e1',
    proyectoId: 'p1',
    numeroVersion: 2,
    estado: EstadoExpediente.confirmado,
    repoCommitAnalizado: 'abc1234',
    repoRama: 'main',
    descripcionGeneral: const SeccionDescripcionGeneral(
      resumen: 'App de gestión de proyectos.',
      propuestaValor: 'Centraliza la documentación técnica.',
      publicoObjetivo: 'Desarrolladores independientes.',
      estadoMadurez: 'en desarrollo activo',
    ),
    pantallas: [
      const PantallaExpediente(
        claveEstable: 'clave-1',
        nombre: 'Detalle de proyecto',
        descripcionFuncion: 'Muestra toda la info de un proyecto.',
        archivoPrincipal: 'lib/screens/proyectos/proyecto_detail_screen.dart',
        navegacion: 'Desde el listado.',
        pantallasRelacionadas: ['Listado de proyectos'],
      ),
    ],
    catalogoFuncionalidades: [
      const FuncionalidadExpediente(
        nombre: 'Login',
        descripcion: 'Email y contraseña',
        confianza: ConfianzaExpediente.verificada,
        evidencia: 'lib/screens/auth/login_screen.dart',
        archivosRelacionados: ['lib/services/auth_service.dart'],
      ),
    ],
    posibilidadesFuturas: const [
      PosibilidadFutura(nombre: 'Recordatorios automáticos por email', descripcion: 'Avisar antes de que venza una tarea.'),
    ],
    arquitectura: const SeccionArquitectura(
      resumen: 'Flutter + Firebase.',
      patrones: ['Servicios estáticos'],
      tecnologias: ['Flutter', 'Firebase'],
    ),
    calidad: const SeccionCalidad(
      resumen: 'Código razonable.',
      hallazgos: [
        HallazgoExpediente(id: 'h1', titulo: 'Duplicidad', descripcion: 'En X', gravedad: GravedadHallazgo.media, evidencia: 'lib/x.dart'),
      ],
    ),
    seguridad: const SeccionSeguridad(resumen: 'Sin problemas confirmados.'),
    valoracionEconomica: const SeccionValoracionEconomica(
      conservador: EscenarioEconomico(costeDesarrolloEstimado: 5000, costeReconstruccionEstimado: 4000, valorProductoEstimado: 3000, razonamiento: 'Alcance reducido.'),
      intermedio: EscenarioEconomico(costeDesarrolloEstimado: 10000, costeReconstruccionEstimado: 8000, valorProductoEstimado: 7000, razonamiento: 'Medio.'),
      optimista: EscenarioEconomico(costeDesarrolloEstimado: 20000, costeReconstruccionEstimado: 15000, valorProductoEstimado: 15000, razonamiento: 'Con tracción.'),
      supuestos: ['Tarifa media de mercado.'],
      limitaciones: 'Sin datos de mercado reales.',
      nivelConfianza: NivelConfianzaValoracion.media,
    ),
    potencialUsuarios: const SeccionPotencialUsuarios(
      conservador: EscenarioUsuarios(usuariosEstimados: 50, razonamiento: 'Solo el equipo.'),
      intermedio: EscenarioUsuarios(usuariosEstimados: 500, razonamiento: 'Adopción moderada.'),
      optimista: EscenarioUsuarios(usuariosEstimados: 5000, razonamiento: 'Con marketing.'),
      segmentoObjetivo: 'Desarrolladores independientes.',
      supuestos: ['Sin competencia directa.'],
      limitaciones: 'Estimación especulativa.',
      nivelConfianza: NivelConfianzaValoracion.baja,
    ),
    progresoValor: const SeccionProgresoValor(progresoPorcentajeLeido: 45, analisisTexto: 'El progreso es moderado.'),
    metaGeneracion: const MetaGeneracionExpediente(
      modeloUsado: 'claude-sonnet-5-5',
      etapasEjecutadas: 5,
      archivosAnalizados: 30,
      archivosOmitidos: 2,
      truncado: false,
    ),
    createdAt: ahora,
    updatedAt: ahora,
    confirmadoEn: ahora,
  );
}

void main() {
  test('toJson()/fromJson() hacen un viaje de ida y vuelta sin perder ninguna sección', () {
    final original = _expedienteCompleto();

    final reconstruido = Expediente.fromJson('e1', 'p1', original.toJson());

    expect(reconstruido.numeroVersion, 2);
    expect(reconstruido.estado, EstadoExpediente.confirmado);
    expect(reconstruido.repoCommitAnalizado, 'abc1234');
    expect(reconstruido.descripcionGeneral.resumen, 'App de gestión de proyectos.');
    expect(reconstruido.pantallas, hasLength(1));
    expect(reconstruido.pantallas.single.claveEstable, 'clave-1');
    expect(reconstruido.pantallas.single.pantallasRelacionadas, ['Listado de proyectos']);
    expect(reconstruido.catalogoFuncionalidades.single.confianza, ConfianzaExpediente.verificada);
    expect(reconstruido.posibilidadesFuturas.single.nombre, 'Recordatorios automáticos por email');
    expect(reconstruido.posibilidadesFuturas.single.descripcion, 'Avisar antes de que venza una tarea.');
    expect(reconstruido.arquitectura.tecnologias, ['Flutter', 'Firebase']);
    expect(reconstruido.calidad.hallazgos.single.gravedad, GravedadHallazgo.media);
    expect(reconstruido.seguridad.hallazgos, isEmpty);
    expect(reconstruido.valoracionEconomica.conservador.costeDesarrolloEstimado, 5000);
    expect(reconstruido.valoracionEconomica.nivelConfianza, NivelConfianzaValoracion.media);
    expect(reconstruido.potencialUsuarios.optimista.usuariosEstimados, 5000);
    expect(reconstruido.potencialUsuarios.nivelConfianza, NivelConfianzaValoracion.baja);
    expect(reconstruido.progresoValor.progresoPorcentajeLeido, 45);
    expect(reconstruido.metaGeneracion.etapasEjecutadas, 5);
    expect(reconstruido.confirmadoEn, isNotNull);
  });

  test('fromJson() con enums desconocidos cae a sus valores conservadores por defecto', () {
    final e = Expediente.fromJson('e1', 'p1', {
      'estado': 'ya_no_existe',
      'descripcionGeneral': {'resumen': 'X'},
      'catalogoFuncionalidades': [
        {'nombre': 'Y', 'confianza': 'inventada'},
      ],
      'calidad': {
        'hallazgos': [
          {'id': 'h1', 'titulo': 'Z', 'gravedad': 'catastrofica'},
        ],
      },
      'valoracionEconomica': {'nivelConfianza': 'altisima'},
      'potencialUsuarios': {'nivelConfianza': 'desconocida'},
    });

    expect(e.estado, EstadoExpediente.borrador);
    expect(e.catalogoFuncionalidades.single.confianza, ConfianzaExpediente.pendiente);
    expect(e.calidad.hallazgos.single.gravedad, GravedadHallazgo.media);
    expect(e.valoracionEconomica.nivelConfianza, NivelConfianzaValoracion.baja);
    expect(e.potencialUsuarios.nivelConfianza, NivelConfianzaValoracion.baja);
  });

  test('fromJson() construye un borrador válido a partir de la forma cruda que devuelve la Cloud Function (sin numeroVersion/estado/fechas propias)', () {
    // Esto es justo lo que ExpedienteService.generar() recibe de vuelta del
    // callable -- sin numeroVersion/estado/createdAt/updatedAt/confirmadoEn,
    // porque generarExpediente nunca escribe en Firestore (ver index.js).
    final resultadoFuncion = {
      'descripcionGeneral': {'resumen': 'Resumen generado.', 'propuestaValor': '', 'publicoObjetivo': '', 'estadoMadurez': ''},
      'pantallas': <Map<String, dynamic>>[],
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

    final borrador = Expediente.fromJson('', 'p1', {...resultadoFuncion, 'numeroVersion': 3});

    expect(borrador.id, '');
    expect(borrador.numeroVersion, 3);
    expect(borrador.estado, EstadoExpediente.borrador);
    expect(borrador.confirmadoEn, isNull);
    expect(borrador.descripcionGeneral.resumen, 'Resumen generado.');
    expect(borrador.posibilidadesFuturas, isEmpty);
    expect(borrador.createdAt, isNotNull);
    expect(borrador.updatedAt, isNotNull);
  });

  test('copyWith() permite confirmar un expediente cambiando solo id/estado/confirmadoEn', () {
    final borrador = _expedienteCompleto().copyWith(estado: EstadoExpediente.borrador, confirmadoEn: null, id: '');
    final confirmado = borrador.copyWith(id: 'e2', estado: EstadoExpediente.confirmado, confirmadoEn: DateTime(2026, 11, 13));

    expect(confirmado.id, 'e2');
    expect(confirmado.estado, EstadoExpediente.confirmado);
    expect(confirmado.confirmadoEn, isNotNull);
    expect(confirmado.descripcionGeneral.resumen, borrador.descripcionGeneral.resumen);
  });
}
