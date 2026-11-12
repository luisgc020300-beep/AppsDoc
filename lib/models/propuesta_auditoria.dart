// lib/models/propuesta_auditoria.dart
//
// Lo que devuelve AiAssistantService.extraerAuditoria(): una PROPUESTA,
// nunca datos ya guardados. El usuario la revisa y decide qué confirmar;
// solo entonces se usan AuditoriaService/TareaService (los mismos de
// siempre) para persistir, que ya dejan su propio rastro en el historial.
import 'gravedad_hallazgo.dart';

class HallazgoPropuesto {
  const HallazgoPropuesto({required this.titulo, this.descripcion = '', this.gravedad = GravedadHallazgo.media});

  final String titulo;
  final String descripcion;
  final GravedadHallazgo gravedad;

  factory HallazgoPropuesto.fromJson(Map<String, dynamic> json) => HallazgoPropuesto(
    titulo: json['titulo'] as String? ?? '',
    descripcion: json['descripcion'] as String? ?? '',
    gravedad: GravedadHallazgo.values.firstWhere(
      (g) => g.name == json['gravedad'],
      orElse: () => GravedadHallazgo.media,
    ),
  );
}

class TareaPropuesta {
  const TareaPropuesta({required this.titulo, this.descripcion = ''});

  final String titulo;
  final String descripcion;

  factory TareaPropuesta.fromJson(Map<String, dynamic> json) =>
      TareaPropuesta(titulo: json['titulo'] as String? ?? '', descripcion: json['descripcion'] as String? ?? '');
}

class PropuestaAuditoria {
  const PropuestaAuditoria({required this.resumen, required this.hallazgos, required this.tareas});

  final String resumen;
  final List<HallazgoPropuesto> hallazgos;
  final List<TareaPropuesta> tareas;

  factory PropuestaAuditoria.fromJson(Map<String, dynamic> json) => PropuestaAuditoria(
    resumen: json['resumen'] as String? ?? '',
    hallazgos: ((json['hallazgos'] as List?) ?? const [])
        .map((h) => HallazgoPropuesto.fromJson(h as Map<String, dynamic>))
        .toList(),
    tareas: ((json['tareas'] as List?) ?? const [])
        .map((t) => TareaPropuesta.fromJson(t as Map<String, dynamic>))
        .toList(),
  );
}
