// lib/models/propuesta_analisis_repositorio.dart
//
// Lo que devuelve AiAssistantService.analizarRepositorio(): igual que
// PropuestaAuditoria, es una PROPUESTA -- nada se guarda hasta que el
// usuario revisa y confirma. Reutiliza HallazgoPropuesto/TareaPropuesta de
// la Fase 7 (mismo origen de hallazgos/tareas, aquí detectados leyendo el
// código en vez de un texto pegado).
import 'categoria_documento.dart';
import 'estado_funcionalidad.dart';
import 'propuesta_auditoria.dart';

class DocumentoPropuesto {
  const DocumentoPropuesto({
    required this.titulo,
    this.categoria = CategoriaDocumento.nota,
    this.contenido = '',
  });

  final String titulo;
  final CategoriaDocumento categoria;
  final String contenido;

  factory DocumentoPropuesto.fromJson(Map<String, dynamic> json) => DocumentoPropuesto(
    titulo: json['titulo'] as String? ?? '',
    categoria: CategoriaDocumento.values.firstWhere(
      (c) => c.name == json['categoria'],
      orElse: () => CategoriaDocumento.nota,
    ),
    contenido: json['contenido'] as String? ?? '',
  );
}

/// Nivel de certeza con el que la IA detectó una funcionalidad -- nunca se
/// traduce automáticamente en progreso: el usuario sigue siendo quien
/// confirma (y puede cambiar) el estado final antes de guardar nada, así
/// que ProgresoService nunca concede puntos sin que una persona lo
/// verifique.
enum ConfianzaDeteccion {
  alta('Alta'),
  media('Media'),
  baja('Baja');

  const ConfianzaDeteccion(this.etiqueta);
  final String etiqueta;

  static ConfianzaDeteccion desde(String? valor) =>
      ConfianzaDeteccion.values.firstWhere((c) => c.name == valor, orElse: () => ConfianzaDeteccion.baja);
}

class FuncionalidadDetectada {
  const FuncionalidadDetectada({
    required this.nombre,
    this.descripcion = '',
    this.estadoSugerido = EstadoFuncionalidad.planificada,
    this.confianza = ConfianzaDeteccion.baja,
    this.evidencia = '',
  });

  final String nombre;
  final String descripcion;
  final EstadoFuncionalidad estadoSugerido;
  final ConfianzaDeteccion confianza;
  final String evidencia;

  factory FuncionalidadDetectada.fromJson(Map<String, dynamic> json) => FuncionalidadDetectada(
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String? ?? '',
    estadoSugerido: EstadoFuncionalidad.values.firstWhere(
      (e) => e.name == json['estadoSugerido'],
      orElse: () => EstadoFuncionalidad.planificada,
    ),
    confianza: ConfianzaDeteccion.desde(json['confianza'] as String?),
    evidencia: json['evidencia'] as String? ?? '',
  );
}

class IdeaPropuesta {
  const IdeaPropuesta({required this.titulo, this.descripcion = ''});

  final String titulo;
  final String descripcion;

  factory IdeaPropuesta.fromJson(Map<String, dynamic> json) =>
      IdeaPropuesta(titulo: json['titulo'] as String? ?? '', descripcion: json['descripcion'] as String? ?? '');
}

class PropuestaAnalisisRepositorio {
  const PropuestaAnalisisRepositorio({
    required this.resumen,
    required this.arquitecturaDetectada,
    required this.tecnologias,
    required this.documentos,
    required this.funcionalidades,
    required this.hallazgos,
    required this.tareas,
    required this.ideas,
    required this.truncado,
    required this.archivosAnalizados,
    required this.archivosOmitidos,
    this.commitAnalizado,
    this.rama,
  });

  final String resumen;
  final String arquitecturaDetectada;
  final List<String> tecnologias;
  final List<DocumentoPropuesto> documentos;
  final List<FuncionalidadDetectada> funcionalidades;
  final List<HallazgoPropuesto> hallazgos;
  final List<TareaPropuesta> tareas;
  final List<IdeaPropuesta> ideas;

  /// true si el repositorio era demasiado grande para leerlo entero --
  /// el análisis se hizo con un subconjunto priorizado de archivos.
  final bool truncado;
  final int archivosAnalizados;
  final int archivosOmitidos;

  /// Commit analizado -- preparación para la Fase futura de detección de
  /// commits nuevos (análisis incremental), todavía no implementada.
  final String? commitAnalizado;
  final String? rama;

  factory PropuestaAnalisisRepositorio.fromJson(Map<String, dynamic> json) => PropuestaAnalisisRepositorio(
    resumen: json['resumen'] as String? ?? '',
    arquitecturaDetectada: json['arquitecturaDetectada'] as String? ?? '',
    tecnologias: ((json['tecnologias'] as List?) ?? const []).map((t) => t.toString()).toList(),
    documentos: ((json['documentos'] as List?) ?? const [])
        .map((d) => DocumentoPropuesto.fromJson(d as Map<String, dynamic>))
        .toList(),
    funcionalidades: ((json['funcionalidades'] as List?) ?? const [])
        .map((f) => FuncionalidadDetectada.fromJson(f as Map<String, dynamic>))
        .toList(),
    hallazgos: ((json['hallazgos'] as List?) ?? const [])
        .map((h) => HallazgoPropuesto.fromJson(h as Map<String, dynamic>))
        .toList(),
    tareas: ((json['tareas'] as List?) ?? const [])
        .map((t) => TareaPropuesta.fromJson(t as Map<String, dynamic>))
        .toList(),
    ideas: ((json['ideas'] as List?) ?? const [])
        .map((i) => IdeaPropuesta.fromJson(i as Map<String, dynamic>))
        .toList(),
    truncado: json['truncado'] as bool? ?? false,
    archivosAnalizados: (json['archivosAnalizados'] as num?)?.toInt() ?? 0,
    archivosOmitidos: (json['archivosOmitidos'] as num?)?.toInt() ?? 0,
    commitAnalizado: json['commitAnalizado'] as String?,
    rama: json['rama'] as String?,
  );
}
