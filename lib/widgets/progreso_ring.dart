// lib/widgets/progreso_ring.dart
//
// Anillo de progreso -- antes duplicado entre _AnilloProgreso (listado) y
// _SeccionProgreso (ficha de detalle) con tamaños distintos. Un solo
// widget parametrizado por tamaño, usado en ambos sitios.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class ProgresoRing extends StatelessWidget {
  const ProgresoRing({required this.porcentaje, this.tamano = 44, this.grosor = 4, super.key});

  final int porcentaje;
  final double tamano;
  final double grosor;

  Color _colorPorPorcentaje(AppsDocColorsExt colors) {
    if (porcentaje >= 80) return colors.success;
    if (porcentaje >= 40) return colors.accent;
    return colors.warning;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _colorPorPorcentaje(colors);
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: tamano - 4,
            height: tamano - 4,
            child: CircularProgressIndicator(
              value: porcentaje / 100,
              strokeWidth: grosor,
              strokeCap: StrokeCap.round,
              backgroundColor: colors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$porcentaje%',
            style: TextStyle(fontSize: tamano * 0.24, fontWeight: FontWeight.w700, color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
