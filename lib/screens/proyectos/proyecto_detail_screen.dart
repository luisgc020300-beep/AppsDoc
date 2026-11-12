// lib/screens/proyectos/proyecto_detail_screen.dart
//
// Secciones, no tabs (ver arquitectura aprobada): Resumen arriba, luego
// Funcionalidades y Documentación como bloques en la misma pantalla.
// Auditorías/Tareas/Ideas/Historial llegan en fases posteriores.
import 'package:flutter/material.dart';

import '../../controllers/proyecto_detail_controller.dart';
import '../../models/documento.dart';
import '../../models/funcionalidad.dart';
import '../../theme/design_tokens.dart';
import '../documentacion/documento_form_screen.dart';
import '../funcionalidades/funcionalidad_form_screen.dart';
import 'proyecto_form_screen.dart';

class ProyectoDetailScreen extends StatefulWidget {
  const ProyectoDetailScreen({required this.proyectoId, super.key});

  final String proyectoId;

  @override
  State<ProyectoDetailScreen> createState() => _ProyectoDetailScreenState();
}

class _ProyectoDetailScreenState extends State<ProyectoDetailScreen> {
  late final _controller = ProyectoDetailController(proyectoId: widget.proyectoId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _editarProyecto() async {
    final eliminado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProyectoFormScreen(proyectoExistente: _controller.proyecto!)),
    );
    if (eliminado == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_controller.proyecto?.nombre ?? ''),
            actions: [
              if (_controller.proyecto != null)
                IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Editar', onPressed: _editarProyecto),
            ],
          ),
          body: _buildBody(context, colors),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AppsDocColorsExt colors) {
    if (_controller.proyectoCargando) {
      return const Center(child: CircularProgressIndicator());
    }
    final proyecto = _controller.proyecto;
    if (proyecto == null) {
      // Eliminarlo desde esta misma pantalla ya cierra el detalle (ver
      // _editarProyecto) -- esto solo cubre que haya dejado de existir por
      // otra vía mientras se veía.
      return Center(
        child: Text('Este proyecto ya no existe.', style: TextStyle(color: colors.textMuted)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (proyecto.descripcion.isNotEmpty) ...[
                  Text(proyecto.descripcion, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Icon(proyecto.estado.icono, size: 16, color: proyecto.estado.color),
                    const SizedBox(width: 6),
                    Text(proyecto.estado.etiqueta, style: TextStyle(color: proyecto.estado.color)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _SeccionFuncionalidades(proyectoId: widget.proyectoId, funcionalidades: _controller.funcionalidades),
        const SizedBox(height: 20),
        _SeccionDocumentacion(proyectoId: widget.proyectoId, documentos: _controller.documentos),
      ],
    );
  }
}

class _SeccionFuncionalidades extends StatelessWidget {
  const _SeccionFuncionalidades({required this.proyectoId, required this.funcionalidades});

  final String proyectoId;
  final List<Funcionalidad>? funcionalidades;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Funcionalidades', style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Añadir funcionalidad',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FuncionalidadFormScreen(proyectoId: proyectoId)),
              ),
            ),
          ],
        ),
        if (funcionalidades == null)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else if (funcionalidades!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin funcionalidades todavía.', style: TextStyle(color: colors.textMuted)),
          )
        else
          ...funcionalidades!.map(
            (f) => Card(
              child: ListTile(
                leading: Icon(f.estado.icono, color: f.estado.color),
                title: Text(f.nombre),
                subtitle: Text(f.estado.etiqueta, style: TextStyle(color: f.estado.color)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FuncionalidadFormScreen(proyectoId: proyectoId, funcionalidadExistente: f)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SeccionDocumentacion extends StatelessWidget {
  const _SeccionDocumentacion({required this.proyectoId, required this.documentos});

  final String proyectoId;
  final List<Documento>? documentos;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Documentación', style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Añadir documento',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DocumentoFormScreen(proyectoId: proyectoId)),
              ),
            ),
          ],
        ),
        if (documentos == null)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else if (documentos!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin documentos todavía.', style: TextStyle(color: colors.textMuted)),
          )
        else
          ...documentos!.map(
            (d) => Card(
              child: ListTile(
                leading: Icon(d.categoria.icono, color: d.categoria.color),
                title: Text(d.titulo),
                subtitle: Text(d.categoria.etiqueta, style: TextStyle(color: d.categoria.color)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DocumentoFormScreen(proyectoId: proyectoId, documentoExistente: d)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
