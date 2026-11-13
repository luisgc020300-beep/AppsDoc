// lib/screens/proyectos/proyecto_detail_screen.dart
//
// Fase 8: siete secciones (Resumen, Funcionalidades, Documentación,
// Tareas, Ideas, Auditorías, Historial) ya no se amontonan en una sola
// lista vertical interminable -- cada una vive en su propia pestaña de un
// TabBar desplazable, bajo la misma AppBar. Resumen agrupa la ficha básica
// del proyecto, el repositorio de GitHub y el desglose de progreso.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/proyecto_detail_controller.dart';
import '../../models/auditoria.dart';
import '../../models/documento.dart';
import '../../models/estado_tarea.dart';
import '../../models/evento_historial.dart';
import '../../models/expediente.dart';
import '../../models/funcionalidad.dart';
import '../../models/github_repo_info.dart';
import '../../models/idea.dart';
import '../../models/proyecto.dart';
import '../../models/tarea.dart';
import '../../services/github_service.dart';
import '../../services/progreso_service.dart';
import '../../services/proyecto_service.dart';
import '../../services/tarea_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/estado_badge.dart';
import '../../widgets/expediente/expediente_detalle_widget.dart';
import '../../widgets/seccion_header.dart';
import '../../services/expediente_service.dart';
import '../analisis/analisis_repositorio_screen.dart';
import '../asistente/asistente_screen.dart';
import '../auditorias/auditoria_form_screen.dart';
import '../documentacion/documento_form_screen.dart';
import '../expediente/editar_descripcion_expediente_screen.dart';
import '../expediente/expediente_revision_screen.dart';
import '../expediente/expediente_versiones_screen.dart';
import '../expediente/galeria_capturas_screen.dart';
import '../funcionalidades/funcionalidad_form_screen.dart';
import '../ideas/idea_form_screen.dart';
import '../tareas/tarea_form_screen.dart';
import 'proyecto_form_screen.dart';

const _tabs = [
  Tab(text: 'Resumen'),
  Tab(text: 'Funcionalidades'),
  Tab(text: 'Documentación'),
  Tab(text: 'Tareas'),
  Tab(text: 'Ideas'),
  Tab(text: 'Auditorías'),
  Tab(text: 'Historial'),
  Tab(text: 'Expediente'),
];

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
        final proyecto = _controller.proyecto;
        return DefaultTabController(
          length: _tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(proyecto?.nombre ?? ''),
              actions: [
                if (proyecto != null) ...[
                  IconButton(
                    icon: const Icon(Icons.auto_awesome),
                    tooltip: 'Asistente',
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AsistenteScreen(proyecto: proyecto))),
                  ),
                  IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Editar', onPressed: _editarProyecto),
                ],
              ],
              bottom: proyecto == null ? null : const TabBar(isScrollable: true, tabs: _tabs),
            ),
            body: _buildBody(context, colors, proyecto),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AppsDocColorsExt colors, Proyecto? proyecto) {
    if (_controller.proyectoCargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (proyecto == null) {
      // Eliminarlo desde esta misma pantalla ya cierra el detalle (ver
      // _editarProyecto) -- esto solo cubre que haya dejado de existir por
      // otra vía mientras se veía.
      return Center(
        child: Text('Este proyecto ya no existe.', style: TextStyle(color: colors.textMuted)),
      );
    }
    return TabBarView(
      children: [
        _TabResumen(
          proyecto: proyecto,
          funcionalidades: _controller.funcionalidades,
          tareas: _controller.tareas,
          documentos: _controller.documentos,
          auditorias: _controller.auditorias,
        ),
        _contenedorTab(_SeccionFuncionalidades(proyectoId: widget.proyectoId, funcionalidades: _controller.funcionalidades)),
        _contenedorTab(_SeccionDocumentacion(proyectoId: widget.proyectoId, documentos: _controller.documentos)),
        _contenedorTab(_SeccionTareas(proyectoId: widget.proyectoId, tareas: _controller.tareas)),
        _contenedorTab(_SeccionIdeas(proyectoId: widget.proyectoId, ideas: _controller.ideas)),
        _contenedorTab(_SeccionAuditorias(proyectoId: widget.proyectoId, auditorias: _controller.auditorias)),
        _contenedorTab(_SeccionHistorial(historial: _controller.historial)),
        _contenedorTab(_SeccionExpediente(proyecto: proyecto)),
      ],
    );
  }

  Widget _contenedorTab(Widget seccion) => ListView(padding: const EdgeInsets.all(16), children: [seccion]);
}

/// Identidad del proyecto, repositorio de GitHub y desglose de progreso --
/// las tres cosas que antes encabezaban la lista interminable, ahora
/// agrupadas en la primera pestaña.
class _TabResumen extends StatelessWidget {
  const _TabResumen({
    required this.proyecto,
    required this.funcionalidades,
    required this.tareas,
    required this.documentos,
    required this.auditorias,
  });

  final Proyecto proyecto;
  final List<Funcionalidad>? funcionalidades;
  final List<Tarea>? tareas;
  final List<Documento>? documentos;
  final List<Auditoria>? auditorias;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                  const SizedBox(height: 12),
                ],
                EstadoBadge(icono: proyecto.estado.icono, etiqueta: proyecto.estado.etiqueta, color: proyecto.estado.color),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _InfoGeneral(
                        etiqueta: 'Creado',
                        valor: DateFormat('dd/MM/yyyy').format(proyecto.createdAt),
                        colors: colors,
                      ),
                    ),
                    Expanded(
                      child: _InfoGeneral(
                        etiqueta: 'Actualizado',
                        valor: DateFormat('dd/MM/yyyy').format(proyecto.updatedAt),
                        colors: colors,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SeccionGithub(proyecto: proyecto),
        const SizedBox(height: 16),
        _SeccionProgreso(funcionalidades: funcionalidades, tareas: tareas, documentos: documentos, auditorias: auditorias),
      ],
    );
  }
}

class _InfoGeneral extends StatelessWidget {
  const _InfoGeneral({required this.etiqueta, required this.valor, required this.colors});

  final String etiqueta;
  final String valor;
  final AppsDocColorsExt colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: TextStyle(color: colors.textMuted, fontSize: 12)),
        const SizedBox(height: 2),
        Text(valor, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

/// Repositorio vinculado -- indicador independiente (repoConectado) y
/// resumen en vivo vía GithubService (solo lectura, sin token). Nunca
/// suma puntos a ProgresoService, ver arquitectura aprobada de la Fase 5.
class _SeccionGithub extends StatefulWidget {
  const _SeccionGithub({required this.proyecto});

  final Proyecto proyecto;

  @override
  State<_SeccionGithub> createState() => _SeccionGithubState();
}

class _SeccionGithubState extends State<_SeccionGithub> {
  GithubRepoInfo? _info;
  Object? _error;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  @override
  void didUpdateWidget(_SeccionGithub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proyecto.repoUrl != widget.proyecto.repoUrl) {
      _info = null;
      _error = null;
      _cargarResumen();
    }
  }

  Future<void> _cargarResumen() async {
    if (!widget.proyecto.repoConectado) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final info = await GithubService.obtenerResumenRepo(
        propietario: widget.proyecto.repoPropietario,
        nombre: widget.proyecto.repoNombre,
      );
      if (!mounted) return;
      setState(() {
        _info = info;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
  }

  Future<void> _vincular() async {
    final urlCtrl = TextEditingController();
    String? errorDialogo;
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: const Text('Vincular repositorio'),
            content: TextField(
              controller: urlCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'URL de GitHub',
                hintText: 'https://github.com/usuario/repositorio',
                errorText: errorDialogo,
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  try {
                    GithubService.parseRepoUrl(urlCtrl.text);
                    Navigator.pop(ctx, urlCtrl.text.trim());
                  } on UrlRepositorioInvalidaException {
                    setStateDialog(() => errorDialogo = 'Esa URL no parece la de un repositorio de GitHub');
                  }
                },
                child: const Text('Vincular'),
              ),
            ],
          );
        },
      ),
    );
    if (url == null || !mounted) return;
    try {
      await ProyectoService.vincularRepo(widget.proyecto.id, url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo vincular: $e')));
      }
    }
  }

  Future<void> _desvincular() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Desvincular repositorio?'),
        content: Text(
          'Se quitará el enlace a "${widget.proyecto.repoPropietario}/${widget.proyecto.repoNombre}". '
          'Esto no afecta al repositorio en GitHub.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desvincular')),
        ],
      ),
    );
    if (confirmar == true) await ProyectoService.desvincularRepo(widget.proyecto.id);
  }

  String _mensajeError(Object error) {
    if (error is RepositorioNoEncontradoOPrivadoException) return error.toString();
    if (error is LimiteDePeticionesGithubException) return error.toString();
    return 'No se pudo conectar con GitHub.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final proyecto = widget.proyecto;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SeccionHeader(
              titulo: 'Repositorio',
              icono: Icons.hub_outlined,
              accion: Text(
                proyecto.repoConectado ? 'Conectado' : 'Sin conectar',
                style: TextStyle(color: proyecto.repoConectado ? colors.success : colors.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            if (!proyecto.repoConectado) ...[
              Text('Sin repositorio vinculado.', style: TextStyle(color: colors.textMuted)),
              const SizedBox(height: 10),
              FilledButton.tonal(onPressed: _vincular, child: const Text('Vincular repositorio')),
            ] else ...[
              Text('${proyecto.repoPropietario}/${proyecto.repoNombre}', style: AppsDocText.mono(color: colors.textPrimary)),
              const SizedBox(height: 10),
              if (_cargando)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: colors.danger),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_mensajeError(_error!), style: TextStyle(color: colors.danger))),
                    IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reintentar', onPressed: _cargarResumen),
                  ],
                )
              else if (_info != null) ...[
                _FilaInfoRepo(icono: Icons.account_tree_outlined, etiqueta: 'Rama principal', valor: _info!.ramaPrincipal),
                _FilaInfoRepo(icono: Icons.commit_outlined, etiqueta: 'Último commit', valor: _info!.ultimoCommitMensaje),
                _FilaInfoRepo(
                  icono: Icons.schedule_outlined,
                  etiqueta: 'Actualizado',
                  valor: DateFormat('dd/MM/yyyy HH:mm').format(_info!.actualizadoEn),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AnalisisRepositorioScreen(proyecto: proyecto)),
                ),
                icon: const Icon(Icons.travel_explore),
                label: const Text('Analizar con IA'),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _desvincular,
                  child: Text('Desvincular repositorio', style: TextStyle(color: colors.danger)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaInfoRepo extends StatelessWidget {
  const _FilaInfoRepo({required this.icono, required this.etiqueta, required this.valor});

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icono, size: 15, color: colors.textMuted),
          const SizedBox(width: 6),
          Text('$etiqueta: ', style: TextStyle(color: colors.textMuted)),
          Expanded(child: Text(valor, overflow: TextOverflow.ellipsis)),
        ],
      ),
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
                          strokeCap: StrokeCap.round,
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
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Añadir funcionalidad',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FuncionalidadFormScreen(proyectoId: proyectoId)),
            ),
          ),
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
              margin: const EdgeInsets.only(top: 10),
              child: ListTile(
                leading: Icon(f.estado.icono, color: f.estado.color),
                title: Text(f.nombre),
                subtitle: EstadoBadge(icono: f.estado.icono, etiqueta: f.estado.etiqueta, color: f.estado.color, compacto: true),
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
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Añadir documento',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DocumentoFormScreen(proyectoId: proyectoId)),
            ),
          ),
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
              margin: const EdgeInsets.only(top: 10),
              child: ListTile(
                leading: Icon(d.categoria.icono, color: d.categoria.color),
                title: Text(d.titulo),
                subtitle: EstadoBadge(icono: d.categoria.icono, etiqueta: d.categoria.etiqueta, color: d.categoria.color, compacto: true),
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
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Añadir tarea',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TareaFormScreen(proyectoId: proyectoId))),
          ),
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
              margin: const EdgeInsets.only(top: 10),
              child: ListTile(
                leading: Icon(t.prioridad.icono, color: t.prioridad.color),
                title: Text(t.titulo),
                subtitle: Row(
                  children: [
                    EstadoBadge(icono: t.estado.icono, etiqueta: t.estado.etiqueta, color: t.estado.color, compacto: true),
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
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Añadir idea',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IdeaFormScreen(proyectoId: proyectoId))),
          ),
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
              margin: const EdgeInsets.only(top: 10),
              child: ListTile(
                leading: Icon(i.estado.icono, color: i.estado.color),
                title: Text(i.titulo),
                subtitle: EstadoBadge(icono: i.estado.icono, etiqueta: i.estado.etiqueta, color: i.estado.color, compacto: true),
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
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Añadir auditoría',
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => AuditoriaFormScreen(proyectoId: proyectoId))),
          ),
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
              margin: const EdgeInsets.only(top: 10),
              child: ListTile(
                leading: Icon(a.resultado.icono, color: a.resultado.color),
                title: Text(DateFormat('dd/MM/yyyy').format(a.fecha)),
                subtitle: Row(
                  children: [
                    EstadoBadge(icono: a.origen.icono, etiqueta: a.origen.etiqueta, color: a.origen.color, compacto: true),
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
            (e) => Card(
              margin: const EdgeInsets.only(top: 10),
              child: ListTile(
                dense: true,
                leading: Icon(e.entidad.icono, color: colors.textMuted, size: 20),
                title: Text(e.descripcion),
                subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(e.fecha)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Fase 10: el expediente es un pipeline y una pantalla aparte de
/// "Analizar con IA" (que sigue viviendo en _SeccionGithub, sin cambios) --
/// puramente documental, nunca escribe en funcionalidades/tareas/ideas/
/// documentos/auditorias reales ni en Proyecto.progresoPorcentaje.
class _SeccionExpediente extends StatelessWidget {
  const _SeccionExpediente({required this.proyecto});

  final Proyecto proyecto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<Expediente?>(
      stream: ExpedienteService.streamActualConfirmado(proyecto.id),
      builder: (context, snapshot) {
        final actual = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SeccionHeader(
              titulo: 'Expediente',
              icono: Icons.folder_special_outlined,
              accion: TextButton.icon(
                icon: const Icon(Icons.history, size: 16),
                label: const Text('Versiones'),
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ExpedienteVersionesScreen(proyectoId: proyecto.id))),
              ),
            ),
            const SizedBox(height: 10),
            if (!proyecto.repoConectado)
              Text(
                'Vincula un repositorio de GitHub en la sección Resumen para poder generar un expediente.',
                style: TextStyle(color: colors.textMuted),
              )
            else if (actual == null) ...[
              Text(
                'Todavía no hay un expediente confirmado para este proyecto. Genera uno para obtener su descripción, '
                'catálogo de pantallas y funcionalidades, arquitectura, calidad, seguridad y valoración económica.',
                style: TextStyle(color: colors.textMuted),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ExpedienteRevisionScreen(proyecto: proyecto))),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generar expediente'),
              ),
            ] else ...[
              ExpedienteDetalleWidget(expediente: actual),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ExpedienteRevisionScreen(proyecto: proyecto))),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Generar de nuevo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EditarDescripcionExpedienteScreen(proyectoId: proyecto.id, expediente: actual)),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Corregir descripción'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GaleriaCapturasScreen(proyectoId: proyecto.id, pantallas: actual.pantallas),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galería de capturas'),
                  ),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Exportar a PDF (próximamente)'),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
