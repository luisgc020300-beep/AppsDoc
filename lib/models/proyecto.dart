// lib/models/proyecto.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'estado_proyecto.dart';

/// Ficha básica de un proyecto. GitHub e IA son de fases posteriores -- el
/// modelo se amplía cuando esa fase lo necesite, no antes.
class Proyecto {
  Proyecto({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.estado = EstadoProyecto.idea,
    this.progresoPorcentaje = 0,
    this.repoUrl = '',
    this.repoPropietario = '',
    this.repoNombre = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final EstadoProyecto estado;

  /// URL tal como la introdujo el usuario; propietario/nombre ya
  /// validados y separados por GithubService.parseRepoUrl() en el
  /// momento de vincular, para no tener que volver a parsear la URL en
  /// cada consulta. Los tres quedan vacíos mientras no haya repositorio
  /// vinculado -- ProyectoService.vincularRepo()/desvincularRepo() son la
  /// única vía para cambiarlos.
  final String repoUrl;
  final String repoPropietario;
  final String repoNombre;

  /// Indicador independiente (nunca suma al progreso, ver ProgresoService
  /// y la arquitectura aprobada de la Fase 5): simplemente si hay un
  /// repositorio vinculado o no.
  bool get repoConectado => repoUrl.isNotEmpty;

  /// Caché de ProgresoService.calcular() -- nunca se escribe a mano desde
  /// la UI (no está en copyWith ni en ProyectoService.actualizar() a
  /// propósito). Solo ProyectoService.recalcularProgreso() lo recalcula y
  /// lo guarda, disparado automáticamente tras cualquier cambio en
  /// funcionalidades/tareas/documentos/auditorías del proyecto.
  final int progresoPorcentaje;
  final DateTime createdAt;
  final DateTime updatedAt;

  Proyecto copyWith({
    String? nombre,
    String? descripcion,
    EstadoProyecto? estado,
    String? repoUrl,
    String? repoPropietario,
    String? repoNombre,
    DateTime? updatedAt,
  }) {
    return Proyecto(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      progresoPorcentaje: progresoPorcentaje,
      repoUrl: repoUrl ?? this.repoUrl,
      repoPropietario: repoPropietario ?? this.repoPropietario,
      repoNombre: repoNombre ?? this.repoNombre,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'descripcion': descripcion,
    'estado': estado.name,
    'progresoPorcentaje': progresoPorcentaje,
    'repoUrl': repoUrl,
    'repoPropietario': repoPropietario,
    'repoNombre': repoNombre,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Proyecto.fromJson(String id, Map<String, dynamic> json) => Proyecto(
    id: id,
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String? ?? '',
    estado: EstadoProyecto.values.firstWhere(
      (e) => e.name == json['estado'],
      orElse: () => EstadoProyecto.idea,
    ),
    progresoPorcentaje: (json['progresoPorcentaje'] as num?)?.toInt() ?? 0,
    repoUrl: json['repoUrl'] as String? ?? '',
    repoPropietario: json['repoPropietario'] as String? ?? '',
    repoNombre: json['repoNombre'] as String? ?? '',
    createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
