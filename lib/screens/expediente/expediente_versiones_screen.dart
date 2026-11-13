// lib/screens/expediente/expediente_versiones_screen.dart
//
// Lista todas las versiones de un expediente (más reciente primero), cada
// una abre el mismo widget de detalle en modo lectura -- ver qué cambió
// entre análisis sin perder el histórico.
import 'package:flutter/material.dart';

import '../../models/expediente.dart';
import '../../services/expediente_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/estado_badge.dart';
import '../../widgets/expediente/expediente_detalle_widget.dart';

class ExpedienteVersionesScreen extends StatelessWidget {
  const ExpedienteVersionesScreen({required this.proyectoId, super.key});

  final String proyectoId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Versiones del expediente')),
      body: SafeArea(
        child: StreamBuilder<List<Expediente>>(
          stream: ExpedienteService.streamVersiones(proyectoId),
          builder: (context, snapshot) {
            final versiones = snapshot.data;
            if (versiones == null) return const Center(child: CircularProgressIndicator());
            if (versiones.isEmpty) {
              return Center(child: Text('Todavía no hay ningún expediente generado.', style: TextStyle(color: colors.textMuted)));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: versiones.length,
              itemBuilder: (context, i) {
                final v = versiones[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text('Versión ${v.numeroVersion}'),
                    subtitle: Text(
                      v.descripcionGeneral.resumen.isEmpty ? '(sin resumen)' : v.descripcionGeneral.resumen,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: EstadoBadge(icono: v.estado.icono, etiqueta: v.estado.etiqueta, color: v.estado.color, compacto: true),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _VersionDetalleScreen(expediente: v)),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _VersionDetalleScreen extends StatelessWidget {
  const _VersionDetalleScreen({required this.expediente});
  final Expediente expediente;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Expediente -- versión ${expediente.numeroVersion}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ExpedienteDetalleWidget(expediente: expediente),
        ),
      ),
    );
  }
}
