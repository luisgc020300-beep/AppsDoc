// lib/screens/proyectos/proyectos_list_screen.dart
import 'package:flutter/material.dart';

import '../../controllers/proyectos_list_controller.dart';
import '../../models/estado_proyecto.dart';
import '../../models/proyecto.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/progreso_ring.dart';
import 'proyecto_detail_screen.dart';
import 'proyecto_form_screen.dart';

class ProyectosListScreen extends StatefulWidget {
  const ProyectosListScreen({super.key});

  @override
  State<ProyectosListScreen> createState() => _ProyectosListScreenState();
}

class _ProyectosListScreenState extends State<ProyectosListScreen> {
  late final _controller = ProyectosListController();
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';
  EstadoProyecto? _filtroEstado;

  @override
  void dispose() {
    _controller.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  List<Proyecto> _filtrar(List<Proyecto> proyectos) {
    var resultado = proyectos;
    if (_filtroEstado != null) {
      resultado = resultado.where((p) => p.estado == _filtroEstado).toList();
    }
    if (_busqueda.trim().isNotEmpty) {
      final q = _busqueda.trim().toLowerCase();
      resultado = resultado
          .where((p) => p.nombre.toLowerCase().contains(q) || p.descripcion.toLowerCase().contains(q))
          .toList();
    }
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis proyectos')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.cargando) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.error != null) {
            return ErrorState(titulo: 'No se pudieron cargar tus proyectos', error: _controller.error!);
          }
          final todos = _controller.proyectos!;
          if (todos.isEmpty) {
            return const EmptyState(
              icono: Icons.dashboard_customize_outlined,
              titulo: 'Todavía no tienes ningún proyecto',
              subtitulo: 'Añade el primero con el botón +.',
            );
          }
          final visibles = _filtrar(todos);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _busquedaCtrl,
                  onChanged: (v) => setState(() => _busqueda = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar proyecto…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busqueda.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _busquedaCtrl.clear();
                              _busqueda = '';
                            }),
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Todos'),
                        selected: _filtroEstado == null,
                        onSelected: (_) => setState(() => _filtroEstado = null),
                      ),
                    ),
                    for (final estado in EstadoProyecto.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(estado.etiqueta),
                          avatar: Icon(estado.icono, size: 16),
                          selected: _filtroEstado == estado,
                          onSelected: (_) => setState(() => _filtroEstado = _filtroEstado == estado ? null : estado),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: visibles.isEmpty
                    ? const EmptyState(icono: Icons.search_off, titulo: 'Ningún proyecto coincide')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: visibles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _ProyectoCard(
                          proyecto: visibles[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ProyectoDetailScreen(proyectoId: visibles[i].id)),
                          ),
                        ),
                      ),
              ),
            ],
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

class _ProyectoCard extends StatelessWidget {
  const _ProyectoCard({required this.proyecto, required this.onTap});

  final Proyecto proyecto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final estado = proyecto.estado;
    final colors = context.colors;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                        if (proyecto.repoConectado) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Repositorio conectado',
                            child: Icon(Icons.hub_outlined, size: 14, color: colors.success),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              ProgresoRing(porcentaje: proyecto.progresoPorcentaje, tamano: 44),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
