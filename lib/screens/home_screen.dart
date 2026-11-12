// lib/screens/home_screen.dart
import 'package:flutter/material.dart';

import '../models/app_project.dart';
import '../services/app_projects_store.dart';
import 'app_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = AppProjectsStore();
  List<AppProject>? _proyectos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final proyectos = await _store.cargar();
    if (!mounted) return;
    setState(() => _proyectos = proyectos);
  }

  Future<void> _guardar() async {
    await _store.guardar(_proyectos!);
  }

  Future<void> _abrirDetalle(AppProject proyecto) async {
    final actualizado = await Navigator.push<AppProject>(
      context,
      MaterialPageRoute(builder: (_) => AppDetailScreen(proyecto: proyecto)),
    );
    if (actualizado == null) return;
    setState(() {
      final i = _proyectos!.indexWhere((p) => p.id == actualizado.id);
      _proyectos![i] = actualizado;
    });
    await _guardar();
  }

  Future<void> _nuevaApp() async {
    final nombre = await _pedirTexto(context, titulo: 'Nueva app', hint: 'Nombre de la app');
    if (nombre == null || nombre.trim().isEmpty) return;
    final nuevo = AppProject(id: DateTime.now().microsecondsSinceEpoch.toString(), nombre: nombre.trim());
    setState(() => _proyectos = [..._proyectos!, nuevo]);
    await _guardar();
  }

  Future<void> _borrarApp(AppProject proyecto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar esta app?'),
        content: Text('Se borrará "${proyecto.nombre}" y todos sus pendientes de AppsDoc.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _proyectos!.removeWhere((p) => p.id == proyecto.id));
    await _guardar();
  }

  @override
  Widget build(BuildContext context) {
    final proyectos = _proyectos;
    return Scaffold(
      appBar: AppBar(title: const Text('AppsDoc')),
      body: proyectos == null
          ? const Center(child: CircularProgressIndicator())
          : proyectos.isEmpty
          ? const Center(child: Text('Todavía no hay ninguna app. Añade la primera con el botón +.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: proyectos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _AppCard(
                proyecto: proyectos[i],
                onTap: () => _abrirDetalle(proyectos[i]),
                onLongPress: () => _borrarApp(proyectos[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: proyectos == null ? null : _nuevaApp,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.proyecto, required this.onTap, required this.onLongPress});

  final AppProject proyecto;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final estado = proyecto.estado;
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
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
                        if (proyecto.pendientesSinHacer > 0) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.checklist, size: 14, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(width: 4),
                          Text(
                            '${proyecto.pendientesSinHacer} pendiente${proyecto.pendientesSinHacer == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _pedirTexto(BuildContext context, {required String titulo, required String hint}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Guardar')),
      ],
    ),
  );
}
