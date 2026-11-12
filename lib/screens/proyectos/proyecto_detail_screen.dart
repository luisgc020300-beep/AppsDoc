// lib/screens/proyectos/proyecto_detail_screen.dart
//
// Secciones, no tabs (ver arquitectura aprobada): Resumen arriba, luego
// Funcionalidades, Documentación, Tareas, Ideas, Auditorías e Historial
// como bloques en la misma pantalla. Progreso/GitHub/IA llegan en fases
// posteriores.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/proyecto_detail_controller.dart';
import '../../models/auditoria.dart';
import '../../models/documento.dart';
import '../../models/estado_tarea.dart';
import '../../models/evento_historial.dart';
import '../../models/funcionalidad.dart';
import '../../models/idea.dart';
import '../../models/tarea.dart';
import '../../services/progreso_service.dart';
import '../../services/tarea_service.dart';
import '../../theme/design_tokens.dart';
import '../auditorias/auditoria_form_screen.dart';
import '../documentacion/documento_form_screen.dart';
import '../funcionalidades/funcionalidad_form_screen.dart';
import '../ideas/idea_form_screen.dart';
import '../tareas/tarea_form_screen.dart';
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
        _SeccionProgreso(
          funcionalidades: _controller.funcionalidades,
          tareas: _controller.tareas,
          documentos: _controller.documentos,
          auditorias: _controller.auditorias,
        ),
        const SizedBox(height: 20),
        _SeccionFuncionalidades(proyectoId: widget.proyectoId, funcionalidades: _controller.funcionalidades),
        const SizedBox(height: 20),
        _SeccionDocumentacion(proyectoId: widget.proyectoId, documentos: _controller.documentos),
        const SizedBox(height: 20),
        _SeccionTareas(proyectoId: widget.proyectoId, tareas: _controller.tareas),
        const SizedBox(height: 20),
        _SeccionIdeas(proyectoId: widget.proyectoId, ideas: _controller.ideas),
        const SizedBox(height: 20),
        _SeccionAuditorias(proyectoId: widget.proyectoId, auditorias: _controller.auditorias),
        const SizedBox(height: 20),
        _SeccionHistorial(historial: _controller.historial),
      ],
    );
  }
}

/// El porcentaje y el desglose se calculan aquí mismo, en vivo, a partir
/// de las listas que ya tiene cargadas el controller -- ProgresoService
/// es puro, así que no hace falta volver a tocar Firestore para esto. El
/// Proyecto.progresoPorcentaje cacheado es solo para el listado (que no
/// carga estas cuatro subcolecciones); aquí, con los datos ya en mano,
/// calcular en vivo es más preciso que depender de la caché.
class _SeccionProgreso extends StatelessWidget {
  const _SeccionProgreso({
    required this.funcionalidades,
    required this.tareas,
    required this.documentos,
    required this.auditorias,
  });

  final List<Funcionalidad>? funcionalidades;
  final List<Tarea>? tareas;
  final List<Documento>? documentos;
  final List<Auditoria>? auditorias;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (funcionalidades == null || tareas == null || documentos == null || auditorias == null) {
      return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    }

    final resultado = ProgresoService.calcular(
      funcionalidades: funcionalidades!,
      tareas: tareas!,
      documentos: documentos!,
      auditorias: auditorias!,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          value: resultado.porcentaje / 100,
                          strokeWidth: 5,
                          backgroundColor: colors.surfaceMuted,
                          valueColor: AlwaysStoppedAnimation(colors.accent),
                        ),
                      ),
                      Text('${resultado.porcentaje}%', style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Preparación para publicar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...resultado.criterios.map(
              (c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      c.cumplido ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 18,
                      color: c.cumplido ? colors.success : colors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.nombre)),
                    Text('${c.puntosObtenidos}/${c.puntosMaximos}', style: TextStyle(color: colors.textMuted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

class _SeccionTareas extends StatelessWidget {
  const _SeccionTareas({required this.proyectoId, required this.tareas});

  final String proyectoId;
  final List<Tarea>? tareas;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Tareas', style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Añadir tarea',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TareaFormScreen(proyectoId: proyectoId))),
            ),
          ],
        ),
        if (tareas == null)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else if (tareas!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin tareas todavía.', style: TextStyle(color: colors.textMuted)),
          )
        else
          ...tareas!.map(
            (t) => Card(
              child: ListTile(
                leading: Icon(t.prioridad.icono, color: t.prioridad.color),
                title: Text(t.titulo),
                subtitle: Row(
                  children: [
                    Icon(t.estado.icono, size: 14, color: t.estado.color),
                    const SizedBox(width: 4),
                    Text(t.estado.etiqueta, style: TextStyle(color: t.estado.color)),
                    if (t.fechaLimite != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.calendar_today_outlined, size: 13, color: t.vencida ? colors.danger : colors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('dd/MM/yyyy').format(t.fechaLimite!),
                        style: TextStyle(color: t.vencida ? colors.danger : colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                // Cambiar el estado directamente desde la lista, sin abrir
                // la ficha completa -- pedido explícito de esta fase.
                trailing: PopupMenuButton<EstadoTarea>(
                  tooltip: 'Cambiar estado',
                  initialValue: t.estado,
                  onSelected: (nuevoEstado) => TareaService.actualizar(proyectoId, t.id, estado: nuevoEstado),
                  itemBuilder: (context) => EstadoTarea.values
                      .map((e) => PopupMenuItem(value: e, child: Text(e.etiqueta)))
                      .toList(),
                  child: Icon(Icons.more_vert, color: colors.textMuted),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TareaFormScreen(proyectoId: proyectoId, tareaExistente: t)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SeccionIdeas extends StatelessWidget {
  const _SeccionIdeas({required this.proyectoId, required this.ideas});

  final String proyectoId;
  final List<Idea>? ideas;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Ideas', style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Añadir idea',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IdeaFormScreen(proyectoId: proyectoId))),
            ),
          ],
        ),
        if (ideas == null)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else if (ideas!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin ideas todavía.', style: TextStyle(color: colors.textMuted)),
          )
        else
          ...ideas!.map(
            (i) => Card(
              child: ListTile(
                leading: Icon(i.estado.icono, color: i.estado.color),
                title: Text(i.titulo),
                subtitle: Text(i.estado.etiqueta, style: TextStyle(color: i.estado.color)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => IdeaFormScreen(proyectoId: proyectoId, ideaExistente: i)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SeccionAuditorias extends StatelessWidget {
  const _SeccionAuditorias({required this.proyectoId, required this.auditorias});

  final String proyectoId;
  final List<Auditoria>? auditorias;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Auditorías', style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Añadir auditoría',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuditoriaFormScreen(proyectoId: proyectoId))),
            ),
          ],
        ),
        if (auditorias == null)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else if (auditorias!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin auditorías todavía.', style: TextStyle(color: colors.textMuted)),
          )
        else
          ...auditorias!.map(
            (a) => Card(
              child: ListTile(
                leading: Icon(a.resultado.icono, color: a.resultado.color),
                title: Text(DateFormat('dd/MM/yyyy').format(a.fecha)),
                subtitle: Row(
                  children: [
                    Icon(a.origen.icono, size: 14, color: a.origen.color),
                    const SizedBox(width: 4),
                    Text(a.origen.etiqueta, style: TextStyle(color: a.origen.color)),
                    if (a.hallazgosAbiertos > 0) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.flag_outlined, size: 14, color: colors.danger),
                      const SizedBox(width: 4),
                      Text('${a.hallazgosAbiertos} abiertos', style: TextStyle(color: colors.danger, fontSize: 12)),
                    ],
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AuditoriaFormScreen(proyectoId: proyectoId, auditoriaExistente: a)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SeccionHistorial extends StatelessWidget {
  const _SeccionHistorial({required this.historial});

  final List<EventoHistorial>? historial;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        // Solo lectura -- lo generan el resto de servicios automáticamente,
        // nunca se añade ni se edita a mano.
        if (historial == null)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else if (historial!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin actividad todavía.', style: TextStyle(color: colors.textMuted)),
          )
        else
          ...historial!.map(
            (e) => ListTile(
              dense: true,
              leading: Icon(e.entidad.icono, color: colors.textMuted, size: 20),
              title: Text(e.descripcion),
              subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(e.fecha)),
            ),
          ),
      ],
    );
  }
}
