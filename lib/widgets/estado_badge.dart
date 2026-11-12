// lib/widgets/estado_badge.dart
//
// Insignia de estado reutilizable: icono + etiqueta sobre un fondo tenue
// del mismo color semántico. Sustituye el patrón repetido Row(Icon+Text)
// que existía suelto en cada pantalla (estado de proyecto/funcionalidad/
// tarea/idea/hallazgo, prioridad, categoría, origen, resultado...) por un
// único componente visual, consistente en todas las pantallas.
import 'package:flutter/material.dart';

class EstadoBadge extends StatelessWidget {
  const EstadoBadge({required this.icono, required this.etiqueta, required this.color, this.compacto = false, super.key});

  final IconData icono;
  final String etiqueta;
  final Color color;

  /// Versión compacta (subtítulos de listas, filas densas) sin fondo ni
  /// borde propios -- solo icono + texto coloreados.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    if (compacto) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Text(etiqueta, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 6),
          Text(etiqueta, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
