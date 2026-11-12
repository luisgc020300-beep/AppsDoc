// lib/models/accion_historial.dart
//
// Solo creación y modificación -- la eliminación no se registra en el
// historial (pedido explícito de esta fase, para no enturbiar el
// historial con el rastro de algo que ya no existe).
enum AccionHistorial { creado, actualizado }
