// lib/models/hallazgo.dart
//
// Vive embebido dentro de Auditoria (no es colección propia de Firestore)
// -- por eso su id lo genera el cliente, no Firestore.
import 'estado_hallazgo.dart';
import 'gravedad_hallazgo.dart';

class Hallazgo {
  Hallazgo({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    this.gravedad = GravedadHallazgo.media,
    this.estado = EstadoHallazgo.abierto,
  });

  final String id;
  final String titulo;
  final String descripcion;
  final GravedadHallazgo gravedad;
  final EstadoHallazgo estado;

  Hallazgo copyWith({String? titulo, String? descripcion, GravedadHallazgo? gravedad, EstadoHallazgo? estado}) {
    return Hallazgo(
      id: id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      gravedad: gravedad ?? this.gravedad,
      estado: estado ?? this.estado,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'descripcion': descripcion,
    'gravedad': gravedad.name,
    'estado': estado.name,
  };

  factory Hallazgo.fromJson(Map<String, dynamic> json) => Hallazgo(
    id: json['id'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    descripcion: json['descripcion'] as String? ?? '',
    gravedad: GravedadHallazgo.values.firstWhere((g) => g.name == json['gravedad'], orElse: () => GravedadHallazgo.media),
    estado: EstadoHallazgo.values.firstWhere((e) => e.name == json['estado'], orElse: () => EstadoHallazgo.abierto),
  );
}
