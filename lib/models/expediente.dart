// lib/models/expediente.dart
//
// Fase 10: expediente integral de un proyecto -- descripción, pantallas,
// catálogo de funcionalidades, arquitectura, calidad, seguridad, valoración
// económica y potencial de usuarios. Cada documento es una versión completa
// e inmutable salvo ExpedienteService.editarCampo (correcciones manuales del
// usuario sobre una versión ya confirmada, ver ese servicio). Puramente
// documental: nunca escribe en funcionalidades/tareas/ideas/documentos/
// auditorias reales ni en Proyecto.progresoPorcentaje -- progresoValor solo
// LEE ese número ya calculado.
import 'package:cloud_firestore/cloud_firestore.dart';

import 'confianza_expediente.dart';
import 'estado_expediente.dart';
import 'gravedad_hallazgo.dart';
import 'nivel_confianza_valoracion.dart';

DateTime _fechaDesde(dynamic v, {DateTime? fallback}) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return fallback ?? DateTime.now();
}

DateTime? _fechaOpcionalDesde(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String _texto(dynamic v) => v as String? ?? '';

List<String> _listaTexto(dynamic v) =>
    (v as List<dynamic>? ?? []).map((e) => e as String? ?? '').where((e) => e.isNotEmpty).toList();

num _numero(dynamic v) => v is num ? v : 0;

/// Igual que `v as Map<String, dynamic>?`, pero tolera los mapas sueltamente
/// tipados que llegan del puente de Cloud Functions o de literales `{}` en
/// Dart (`Map<dynamic, dynamic>`) -- un cast directo lanza en ese caso.
Map<String, dynamic>? _mapa(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;

class SeccionDescripcionGeneral {
  const SeccionDescripcionGeneral({
    this.resumen = '',
    this.propuestaValor = '',
    this.publicoObjetivo = '',
    this.estadoMadurez = '',
  });

  final String resumen;
  final String propuestaValor;
  final String publicoObjetivo;
  final String estadoMadurez;

  SeccionDescripcionGeneral copyWith({
    String? resumen,
    String? propuestaValor,
    String? publicoObjetivo,
    String? estadoMadurez,
  }) => SeccionDescripcionGeneral(
    resumen: resumen ?? this.resumen,
    propuestaValor: propuestaValor ?? this.propuestaValor,
    publicoObjetivo: publicoObjetivo ?? this.publicoObjetivo,
    estadoMadurez: estadoMadurez ?? this.estadoMadurez,
  );

  Map<String, dynamic> toJson() => {
    'resumen': resumen,
    'propuestaValor': propuestaValor,
    'publicoObjetivo': publicoObjetivo,
    'estadoMadurez': estadoMadurez,
  };

  factory SeccionDescripcionGeneral.fromJson(Map<String, dynamic>? json) => SeccionDescripcionGeneral(
    resumen: _texto(json?['resumen']),
    propuestaValor: _texto(json?['propuestaValor']),
    publicoObjetivo: _texto(json?['publicoObjetivo']),
    estadoMadurez: _texto(json?['estadoMadurez']),
  );
}

/// `claveEstable` enlaza con `usuarios/{uid}/proyectos/{id}/pantallasCatalogo`
/// (ver ExpedienteService._emparejarPantallas) para que las capturas
/// sobrevivan a un reanálisis aunque la pantalla cambie de nombre/orden.
/// Vacío hasta que ExpedienteService hace el emparejamiento tras generar.
class PantallaExpediente {
  const PantallaExpediente({
    this.claveEstable = '',
    required this.nombre,
    this.descripcionFuncion = '',
    this.archivoPrincipal = '',
    this.navegacion = '',
    List<String>? pantallasRelacionadas,
  }) : pantallasRelacionadas = pantallasRelacionadas ?? const [];

  final String claveEstable;
  final String nombre;
  final String descripcionFuncion;
  final String archivoPrincipal;
  final String navegacion;
  final List<String> pantallasRelacionadas;

  PantallaExpediente copyWith({String? claveEstable}) => PantallaExpediente(
    claveEstable: claveEstable ?? this.claveEstable,
    nombre: nombre,
    descripcionFuncion: descripcionFuncion,
    archivoPrincipal: archivoPrincipal,
    navegacion: navegacion,
    pantallasRelacionadas: pantallasRelacionadas,
  );

  Map<String, dynamic> toJson() => {
    'claveEstable': claveEstable,
    'nombre': nombre,
    'descripcionFuncion': descripcionFuncion,
    'archivoPrincipal': archivoPrincipal,
    'navegacion': navegacion,
    'pantallasRelacionadas': pantallasRelacionadas,
  };

  factory PantallaExpediente.fromJson(Map<String, dynamic> json) => PantallaExpediente(
    claveEstable: _texto(json['claveEstable']),
    nombre: _texto(json['nombre']),
    descripcionFuncion: _texto(json['descripcionFuncion']),
    archivoPrincipal: _texto(json['archivoPrincipal']),
    navegacion: _texto(json['navegacion']),
    pantallasRelacionadas: _listaTexto(json['pantallasRelacionadas']),
  );
}

/// Catálogo documental del expediente -- deliberadamente distinto de
/// Funcionalidad/EstadoFuncionalidad (esa es la que mueve ProgresoService).
class FuncionalidadExpediente {
  const FuncionalidadExpediente({
    required this.nombre,
    this.descripcion = '',
    this.confianza = ConfianzaExpediente.pendiente,
    this.evidencia = '',
    List<String>? archivosRelacionados,
  }) : archivosRelacionados = archivosRelacionados ?? const [];

  final String nombre;
  final String descripcion;
  final ConfianzaExpediente confianza;
  final String evidencia;
  final List<String> archivosRelacionados;

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'descripcion': descripcion,
    'confianza': confianza.name,
    'evidencia': evidencia,
    'archivosRelacionados': archivosRelacionados,
  };

  factory FuncionalidadExpediente.fromJson(Map<String, dynamic> json) => FuncionalidadExpediente(
    nombre: _texto(json['nombre']),
    descripcion: _texto(json['descripcion']),
    confianza: ConfianzaExpediente.values.firstWhere(
      (c) => c.name == json['confianza'],
      orElse: () => ConfianzaExpediente.pendiente,
    ),
    evidencia: _texto(json['evidencia']),
    archivosRelacionados: _listaTexto(json['archivosRelacionados']),
  );
}

/// Embebido dentro de SeccionCalidad/SeccionSeguridad -- nunca se escribe en
/// la colección `auditorias` real. Reutiliza GravedadHallazgo tal cual.
class HallazgoExpediente {
  const HallazgoExpediente({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    this.gravedad = GravedadHallazgo.media,
    this.evidencia = '',
  });

  final String id;
  final String titulo;
  final String descripcion;
  final GravedadHallazgo gravedad;
  final String evidencia;

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'descripcion': descripcion,
    'gravedad': gravedad.name,
    'evidencia': evidencia,
  };

  factory HallazgoExpediente.fromJson(Map<String, dynamic> json) => HallazgoExpediente(
    id: _texto(json['id']),
    titulo: _texto(json['titulo']),
    descripcion: _texto(json['descripcion']),
    gravedad: GravedadHallazgo.values.firstWhere((g) => g.name == json['gravedad'], orElse: () => GravedadHallazgo.media),
    evidencia: _texto(json['evidencia']),
  );
}

class SeccionArquitectura {
  const SeccionArquitectura({this.resumen = '', List<String>? patrones, List<String>? tecnologias})
    : patrones = patrones ?? const [],
      tecnologias = tecnologias ?? const [];

  final String resumen;
  final List<String> patrones;
  final List<String> tecnologias;

  Map<String, dynamic> toJson() => {'resumen': resumen, 'patrones': patrones, 'tecnologias': tecnologias};

  factory SeccionArquitectura.fromJson(Map<String, dynamic>? json) => SeccionArquitectura(
    resumen: _texto(json?['resumen']),
    patrones: _listaTexto(json?['patrones']),
    tecnologias: _listaTexto(json?['tecnologias']),
  );
}

class SeccionCalidad {
  const SeccionCalidad({this.resumen = '', List<HallazgoExpediente>? hallazgos}) : hallazgos = hallazgos ?? const [];

  final String resumen;
  final List<HallazgoExpediente> hallazgos;

  Map<String, dynamic> toJson() => {'resumen': resumen, 'hallazgos': hallazgos.map((h) => h.toJson()).toList()};

  factory SeccionCalidad.fromJson(Map<String, dynamic>? json) => SeccionCalidad(
    resumen: _texto(json?['resumen']),
    hallazgos: (json?['hallazgos'] as List<dynamic>? ?? [])
        .map((h) => HallazgoExpediente.fromJson(Map<String, dynamic>.from(h as Map)))
        .toList(),
  );
}

class SeccionSeguridad {
  const SeccionSeguridad({this.resumen = '', List<HallazgoExpediente>? hallazgos}) : hallazgos = hallazgos ?? const [];

  final String resumen;
  final List<HallazgoExpediente> hallazgos;

  Map<String, dynamic> toJson() => {'resumen': resumen, 'hallazgos': hallazgos.map((h) => h.toJson()).toList()};

  factory SeccionSeguridad.fromJson(Map<String, dynamic>? json) => SeccionSeguridad(
    resumen: _texto(json?['resumen']),
    hallazgos: (json?['hallazgos'] as List<dynamic>? ?? [])
        .map((h) => HallazgoExpediente.fromJson(Map<String, dynamic>.from(h as Map)))
        .toList(),
  );
}

/// Estimación razonada por la IA -- nunca datos de mercado reales. `moneda`
/// es un código ISO de 3 letras (p.ej. "EUR").
class EscenarioEconomico {
  const EscenarioEconomico({
    this.costeDesarrolloEstimado = 0,
    this.costeReconstruccionEstimado = 0,
    this.valorProductoEstimado = 0,
    this.moneda = 'EUR',
    this.razonamiento = '',
  });

  final num costeDesarrolloEstimado;
  final num costeReconstruccionEstimado;
  final num valorProductoEstimado;
  final String moneda;
  final String razonamiento;

  Map<String, dynamic> toJson() => {
    'costeDesarrolloEstimado': costeDesarrolloEstimado,
    'costeReconstruccionEstimado': costeReconstruccionEstimado,
    'valorProductoEstimado': valorProductoEstimado,
    'moneda': moneda,
    'razonamiento': razonamiento,
  };

  factory EscenarioEconomico.fromJson(Map<String, dynamic>? json) => EscenarioEconomico(
    costeDesarrolloEstimado: _numero(json?['costeDesarrolloEstimado']),
    costeReconstruccionEstimado: _numero(json?['costeReconstruccionEstimado']),
    valorProductoEstimado: _numero(json?['valorProductoEstimado']),
    moneda: json?['moneda'] as String? ?? 'EUR',
    razonamiento: _texto(json?['razonamiento']),
  );
}

class SeccionValoracionEconomica {
  const SeccionValoracionEconomica({
    this.conservador = const EscenarioEconomico(),
    this.intermedio = const EscenarioEconomico(),
    this.optimista = const EscenarioEconomico(),
    List<String>? supuestos,
    this.limitaciones = '',
    this.nivelConfianza = NivelConfianzaValoracion.baja,
  }) : supuestos = supuestos ?? const [];

  final EscenarioEconomico conservador;
  final EscenarioEconomico intermedio;
  final EscenarioEconomico optimista;
  final List<String> supuestos;
  final String limitaciones;
  final NivelConfianzaValoracion nivelConfianza;

  Map<String, dynamic> toJson() => {
    'conservador': conservador.toJson(),
    'intermedio': intermedio.toJson(),
    'optimista': optimista.toJson(),
    'supuestos': supuestos,
    'limitaciones': limitaciones,
    'nivelConfianza': nivelConfianza.name,
  };

  factory SeccionValoracionEconomica.fromJson(Map<String, dynamic>? json) => SeccionValoracionEconomica(
    conservador: EscenarioEconomico.fromJson(_mapa(json?['conservador'])),
    intermedio: EscenarioEconomico.fromJson(_mapa(json?['intermedio'])),
    optimista: EscenarioEconomico.fromJson(_mapa(json?['optimista'])),
    supuestos: _listaTexto(json?['supuestos']),
    limitaciones: _texto(json?['limitaciones']),
    nivelConfianza: NivelConfianzaValoracion.values.firstWhere(
      (n) => n.name == json?['nivelConfianza'],
      orElse: () => NivelConfianzaValoracion.baja,
    ),
  );
}

class EscenarioUsuarios {
  const EscenarioUsuarios({this.usuariosEstimados = 0, this.razonamiento = ''});

  final num usuariosEstimados;
  final String razonamiento;

  Map<String, dynamic> toJson() => {'usuariosEstimados': usuariosEstimados, 'razonamiento': razonamiento};

  factory EscenarioUsuarios.fromJson(Map<String, dynamic>? json) =>
      EscenarioUsuarios(usuariosEstimados: _numero(json?['usuariosEstimados']), razonamiento: _texto(json?['razonamiento']));
}

/// "Especulativo, no una predicción" -- así debe presentarse siempre en UI
/// cuando falte información suficiente (nivelConfianza baja).
class SeccionPotencialUsuarios {
  const SeccionPotencialUsuarios({
    this.conservador = const EscenarioUsuarios(),
    this.intermedio = const EscenarioUsuarios(),
    this.optimista = const EscenarioUsuarios(),
    this.segmentoObjetivo = '',
    List<String>? supuestos,
    this.limitaciones = '',
    this.nivelConfianza = NivelConfianzaValoracion.baja,
  }) : supuestos = supuestos ?? const [];

  final EscenarioUsuarios conservador;
  final EscenarioUsuarios intermedio;
  final EscenarioUsuarios optimista;
  final String segmentoObjetivo;
  final List<String> supuestos;
  final String limitaciones;
  final NivelConfianzaValoracion nivelConfianza;

  Map<String, dynamic> toJson() => {
    'conservador': conservador.toJson(),
    'intermedio': intermedio.toJson(),
    'optimista': optimista.toJson(),
    'segmentoObjetivo': segmentoObjetivo,
    'supuestos': supuestos,
    'limitaciones': limitaciones,
    'nivelConfianza': nivelConfianza.name,
  };

  factory SeccionPotencialUsuarios.fromJson(Map<String, dynamic>? json) => SeccionPotencialUsuarios(
    conservador: EscenarioUsuarios.fromJson(_mapa(json?['conservador'])),
    intermedio: EscenarioUsuarios.fromJson(_mapa(json?['intermedio'])),
    optimista: EscenarioUsuarios.fromJson(_mapa(json?['optimista'])),
    segmentoObjetivo: _texto(json?['segmentoObjetivo']),
    supuestos: _listaTexto(json?['supuestos']),
    limitaciones: _texto(json?['limitaciones']),
    nivelConfianza: NivelConfianzaValoracion.values.firstWhere(
      (n) => n.name == json?['nivelConfianza'],
      orElse: () => NivelConfianzaValoracion.baja,
    ),
  );
}

/// `progresoPorcentajeLeido` es una COPIA de Proyecto.progresoPorcentaje en
/// el momento de generar -- nunca se escribe de vuelta ni se recalcula aquí.
class SeccionProgresoValor {
  const SeccionProgresoValor({this.progresoPorcentajeLeido = 0, this.analisisTexto = ''});

  final int progresoPorcentajeLeido;
  final String analisisTexto;

  Map<String, dynamic> toJson() => {'progresoPorcentajeLeido': progresoPorcentajeLeido, 'analisisTexto': analisisTexto};

  factory SeccionProgresoValor.fromJson(Map<String, dynamic>? json) => SeccionProgresoValor(
    progresoPorcentajeLeido: (json?['progresoPorcentajeLeido'] as num?)?.toInt() ?? 0,
    analisisTexto: _texto(json?['analisisTexto']),
  );
}

class MetaGeneracionExpediente {
  const MetaGeneracionExpediente({
    this.modeloUsado = '',
    this.etapasEjecutadas = 0,
    this.archivosAnalizados = 0,
    this.archivosOmitidos = 0,
    this.truncado = false,
  });

  final String modeloUsado;
  final int etapasEjecutadas;
  final int archivosAnalizados;
  final int archivosOmitidos;
  final bool truncado;

  Map<String, dynamic> toJson() => {
    'modeloUsado': modeloUsado,
    'etapasEjecutadas': etapasEjecutadas,
    'archivosAnalizados': archivosAnalizados,
    'archivosOmitidos': archivosOmitidos,
    'truncado': truncado,
  };

  factory MetaGeneracionExpediente.fromJson(Map<String, dynamic>? json) => MetaGeneracionExpediente(
    modeloUsado: _texto(json?['modeloUsado']),
    etapasEjecutadas: (json?['etapasEjecutadas'] as num?)?.toInt() ?? 0,
    archivosAnalizados: (json?['archivosAnalizados'] as num?)?.toInt() ?? 0,
    archivosOmitidos: (json?['archivosOmitidos'] as num?)?.toInt() ?? 0,
    truncado: json?['truncado'] as bool? ?? false,
  );
}

class Expediente {
  Expediente({
    required this.id,
    required this.proyectoId,
    this.numeroVersion = 1,
    this.estado = EstadoExpediente.borrador,
    this.repoCommitAnalizado,
    this.repoRama,
    this.descripcionGeneral = const SeccionDescripcionGeneral(),
    List<PantallaExpediente>? pantallas,
    List<FuncionalidadExpediente>? catalogoFuncionalidades,
    this.arquitectura = const SeccionArquitectura(),
    this.calidad = const SeccionCalidad(),
    this.seguridad = const SeccionSeguridad(),
    this.valoracionEconomica = const SeccionValoracionEconomica(),
    this.potencialUsuarios = const SeccionPotencialUsuarios(),
    this.progresoValor = const SeccionProgresoValor(),
    this.metaGeneracion = const MetaGeneracionExpediente(),
    required this.createdAt,
    required this.updatedAt,
    this.confirmadoEn,
  }) : pantallas = pantallas ?? [],
       catalogoFuncionalidades = catalogoFuncionalidades ?? [];

  final String id;
  final String proyectoId;
  final int numeroVersion;
  final EstadoExpediente estado;
  final String? repoCommitAnalizado;
  final String? repoRama;
  final SeccionDescripcionGeneral descripcionGeneral;
  final List<PantallaExpediente> pantallas;
  final List<FuncionalidadExpediente> catalogoFuncionalidades;
  final SeccionArquitectura arquitectura;
  final SeccionCalidad calidad;
  final SeccionSeguridad seguridad;
  final SeccionValoracionEconomica valoracionEconomica;
  final SeccionPotencialUsuarios potencialUsuarios;
  final SeccionProgresoValor progresoValor;
  final MetaGeneracionExpediente metaGeneracion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? confirmadoEn;

  Expediente copyWith({
    String? id,
    int? numeroVersion,
    EstadoExpediente? estado,
    List<PantallaExpediente>? pantallas,
    DateTime? confirmadoEn,
  }) => Expediente(
    id: id ?? this.id,
    proyectoId: proyectoId,
    numeroVersion: numeroVersion ?? this.numeroVersion,
    estado: estado ?? this.estado,
    repoCommitAnalizado: repoCommitAnalizado,
    repoRama: repoRama,
    descripcionGeneral: descripcionGeneral,
    pantallas: pantallas ?? this.pantallas,
    catalogoFuncionalidades: catalogoFuncionalidades,
    arquitectura: arquitectura,
    calidad: calidad,
    seguridad: seguridad,
    valoracionEconomica: valoracionEconomica,
    potencialUsuarios: potencialUsuarios,
    progresoValor: progresoValor,
    metaGeneracion: metaGeneracion,
    createdAt: createdAt,
    updatedAt: updatedAt,
    confirmadoEn: confirmadoEn ?? this.confirmadoEn,
  );

  Map<String, dynamic> toJson() => {
    'numeroVersion': numeroVersion,
    'estado': estado.name,
    'repoCommitAnalizado': repoCommitAnalizado,
    'repoRama': repoRama,
    'descripcionGeneral': descripcionGeneral.toJson(),
    'pantallas': pantallas.map((p) => p.toJson()).toList(),
    'catalogoFuncionalidades': catalogoFuncionalidades.map((f) => f.toJson()).toList(),
    'arquitectura': arquitectura.toJson(),
    'calidad': calidad.toJson(),
    'seguridad': seguridad.toJson(),
    'valoracionEconomica': valoracionEconomica.toJson(),
    'potencialUsuarios': potencialUsuarios.toJson(),
    'progresoValor': progresoValor.toJson(),
    'metaGeneracion': metaGeneracion.toJson(),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'confirmadoEn': confirmadoEn == null ? null : Timestamp.fromDate(confirmadoEn!),
  };

  /// Sirve tanto para leer un documento ya persistido en Firestore (fechas
  /// como Timestamp) como para construir el borrador recién devuelto por la
  /// Cloud Function `generarExpediente` (sin numeroVersion/estado/fechas
  /// propias todavía -- aquí caen a sus valores por defecto, que son
  /// exactamente los correctos para un borrador nuevo: versión indicada por
  /// el llamador, estado "borrador", fechas "ahora").
  factory Expediente.fromJson(String id, String proyectoId, Map<String, dynamic> json) => Expediente(
    id: id,
    proyectoId: proyectoId,
    numeroVersion: (json['numeroVersion'] as num?)?.toInt() ?? 1,
    estado: EstadoExpediente.values.firstWhere((e) => e.name == json['estado'], orElse: () => EstadoExpediente.borrador),
    repoCommitAnalizado: json['repoCommitAnalizado'] as String?,
    repoRama: json['repoRama'] as String?,
    descripcionGeneral: SeccionDescripcionGeneral.fromJson(_mapa(json['descripcionGeneral'])),
    pantallas: (json['pantallas'] as List<dynamic>? ?? [])
        .map((p) => PantallaExpediente.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(),
    catalogoFuncionalidades: (json['catalogoFuncionalidades'] as List<dynamic>? ?? [])
        .map((f) => FuncionalidadExpediente.fromJson(Map<String, dynamic>.from(f as Map)))
        .toList(),
    arquitectura: SeccionArquitectura.fromJson(_mapa(json['arquitectura'])),
    calidad: SeccionCalidad.fromJson(_mapa(json['calidad'])),
    seguridad: SeccionSeguridad.fromJson(_mapa(json['seguridad'])),
    valoracionEconomica: SeccionValoracionEconomica.fromJson(_mapa(json['valoracionEconomica'])),
    potencialUsuarios: SeccionPotencialUsuarios.fromJson(_mapa(json['potencialUsuarios'])),
    progresoValor: SeccionProgresoValor.fromJson(_mapa(json['progresoValor'])),
    metaGeneracion: MetaGeneracionExpediente.fromJson(_mapa(json['metaGeneracion'])),
    createdAt: _fechaDesde(json['createdAt']),
    updatedAt: _fechaDesde(json['updatedAt']),
    confirmadoEn: _fechaOpcionalDesde(json['confirmadoEn']),
  );
}
