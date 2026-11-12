// lib/models/pendiente.dart
class Pendiente {
  Pendiente({required this.id, required this.texto, this.hecho = false});

  final String id;
  final String texto;
  final bool hecho;

  Pendiente copyWith({String? texto, bool? hecho}) {
    return Pendiente(id: id, texto: texto ?? this.texto, hecho: hecho ?? this.hecho);
  }

  Map<String, dynamic> toJson() => {'id': id, 'texto': texto, 'hecho': hecho};

  factory Pendiente.fromJson(Map<String, dynamic> json) => Pendiente(
    id: json['id'] as String,
    texto: json['texto'] as String,
    hecho: json['hecho'] as bool? ?? false,
  );
}
