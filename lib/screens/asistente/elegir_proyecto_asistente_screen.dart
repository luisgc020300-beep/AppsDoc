// lib/screens/asistente/elegir_proyecto_asistente_screen.dart
//
// El asistente de IA es contextual a un proyecto (necesita su documentación,
// funcionalidades, tareas... para responder) -- esta pantalla es solo el
// selector que antecede a AsistenteScreen cuando se entra desde la pestaña
// "Asistente" de la navegación inferior, en vez de desde la ficha de un
// proyecto concreto. Reutiliza el mismo stream de proyectos que el listado
// general, sin ningún dato ni lógica nuevos.
import 'package:flutter/material.dart';

import '../../controllers/proyectos_list_controller.dart';
import '../../models/proyecto.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/progreso_ring.dart';
import 'asistente_screen.dart';

class ElegirProyectoAsistenteScreen extends StatefulWidget {
  const ElegirProyectoAsistenteScreen({super.key});

  @override
  State<ElegirProyectoAsistenteScreen> createState() => _ElegirProyectoAsistenteScreenState();
}

class _ElegirProyectoAsistenteScreenState extends State<ElegirProyectoAsistenteScreen> {
  late final _controller = ProyectosListController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.cargando) return const Center(child: CircularProgressIndicator());
          if (_controller.error != null) {
            return ErrorState(titulo: 'No se pudieron cargar tus proyectos', error: _controller.error!);
          }
          final proyectos = _controller.proyectos!;
          if (proyectos.isEmpty) {
            return const EmptyState(
              icono: Icons.auto_awesome,
              titulo: 'Crea un proyecto primero',
              subtitulo: 'El asistente necesita un proyecto sobre el que responder.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: proyectos.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Elige un proyecto para hablar con su asistente:', style: TextStyle(color: colors.textMuted)),
                );
              }
              final proyecto = proyectos[i - 1];
              return _TarjetaProyectoAsistente(proyecto: proyecto);
            },
          );
        },
      ),
    );
  }
}

class _TarjetaProyectoAsistente extends StatelessWidget {
  const _TarjetaProyectoAsistente({required this.proyecto});

  final Proyecto proyecto;

  @override
  Widget build(BuildContext context) {
    final estado = proyecto.estado;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AsistenteScreen(proyecto: proyecto))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: estado.color.withValues(alpha: 0.15),
                child: Icon(estado.icono, color: estado.color),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(proyecto.nombre, style: Theme.of(context).textTheme.titleMedium)),
              ProgresoRing(porcentaje: proyecto.progresoPorcentaje, tamano: 36, grosor: 3),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
