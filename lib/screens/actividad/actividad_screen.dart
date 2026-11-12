// lib/screens/actividad/actividad_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/actividad_controller.dart';
import '../../models/accion_historial.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';

class ActividadScreen extends StatefulWidget {
  const ActividadScreen({super.key});

  @override
  State<ActividadScreen> createState() => _ActividadScreenState();
}

class _ActividadScreenState extends State<ActividadScreen> {
  late final _controller = ActividadController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actividad')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.cargando) return const Center(child: CircularProgressIndicator());
          if (_controller.error != null) {
            return ErrorState(titulo: 'No se pudo cargar la actividad', error: _controller.error!);
          }
          final eventos = _controller.eventos!;
          if (eventos.isEmpty) {
            return const EmptyState(
              icono: Icons.timeline_outlined,
              titulo: 'Todavía no hay actividad',
              subtitulo: 'Aquí verás, en orden, lo último que ha pasado en todos tus proyectos.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: eventos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _TarjetaEvento(evento: eventos[i]),
          );
        },
      ),
    );
  }
}

class _TarjetaEvento extends StatelessWidget {
  const _TarjetaEvento({required this.evento});

  final EventoConProyecto evento;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final e = evento.evento;
    final colorAccion = e.accion == AccionHistorial.creado ? colors.success : colors.accent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: colorAccion.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(e.entidad.icono, size: 18, color: colorAccion),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.descripcion, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          evento.proyectoNombre,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('  ·  ', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(e.fecha),
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
