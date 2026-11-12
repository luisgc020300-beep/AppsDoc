// lib/screens/proyectos/proyectos_list_screen.dart
import 'package:flutter/material.dart';

import '../../controllers/proyectos_list_controller.dart';
import '../../models/proyecto.dart';
import '../../theme/design_tokens.dart';
import '../ajustes/ajustes_screen.dart';
import 'proyecto_detail_screen.dart';
import 'proyecto_form_screen.dart';

class ProyectosListScreen extends StatefulWidget {
  const ProyectosListScreen({super.key});

  @override
  State<ProyectosListScreen> createState() => _ProyectosListScreenState();
}

class _ProyectosListScreenState extends State<ProyectosListScreen> {
  late final _controller = ProyectosListController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AppsDoc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AjustesScreen())),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.error != null) {
            return _ErrorState(error: _controller.error!);
          }
          final proyectos = _controller.proyectos!;
          if (proyectos.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: proyectos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ProyectoCard(
              proyecto: proyectos[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProyectoDetailScreen(proyectoId: proyectos[i].id)),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProyectoFormScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_customize_outlined, size: 48, color: colors.textMuted),
            const SizedBox(height: 16),
            Text('Todavía no tienes ningún proyecto', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Añade el primero con el botón +.', textAlign: TextAlign.center, style: TextStyle(color: colors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.danger),
            const SizedBox(height: 16),
            Text('No se pudieron cargar tus proyectos', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center, style: TextStyle(color: colors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _ProyectoCard extends StatelessWidget {
  const _ProyectoCard({required this.proyecto, required this.onTap});

  final Proyecto proyecto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final estado = proyecto.estado;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: estado.color.withValues(alpha: 0.15),
                child: Icon(estado.icono, color: estado.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(proyecto.nombre, style: Theme.of(context).textTheme.titleMedium),
                    if (proyecto.descripcion.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          proyecto.descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(estado.icono, size: 14, color: estado.color),
                        const SizedBox(width: 4),
                        Text(estado.etiqueta, style: TextStyle(color: estado.color, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              _AnilloProgreso(porcentaje: proyecto.progresoPorcentaje),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mismo número que en la ficha del proyecto (ProgresoService.calcular(),
/// cacheado en Proyecto.progresoPorcentaje) -- aquí solo se pinta, nunca
/// se recalcula ni se deja tocar.
class _AnilloProgreso extends StatelessWidget {
  const _AnilloProgreso({required this.porcentaje});

  final int porcentaje;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: porcentaje / 100,
              strokeWidth: 3,
              backgroundColor: colors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(colors.accent),
            ),
          ),
          Text('$porcentaje%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors.textMuted)),
        ],
      ),
    );
  }
}
