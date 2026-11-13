// lib/screens/proyectos/proyecto_detail_screen.dart
//
// Reorganización post-Fase-10: 5 pestañas (Funcionalidades, Ideas,
// Documentos, Pantallas, Potencial) en vez de las 8 de la Fase 8, y una
// única operación de IA ("Analizar con IA", que ahora abre
// ExpedienteRevisionScreen) en vez de dos flujos distintos y confusos
// entre sí (el AnalisisRepositorioScreen de la Fase 9 dejó de enlazarse
// desde aquí, aunque sigue existiendo en el repo). La ficha básica del
// proyecto, el repositorio de GitHub y el desglose de progreso ya no son
// una pestaña propia ("Resumen") -- viven en una cabecera fija, visible
// en las 5 pestañas, justo debajo del TabBar.
//
// Tareas/Ideas (manuales)/Historial pierden su pestaña: sus
// modelos/servicios siguen intactos (ProgresoService sigue usando
// Tarea), solo dejan de tener una pantalla de gestión propia. Las
// auditorías manuales/pegadas desde el chat SÍ se conservan -- se
// muestran dentro de "Documentos", junto a la auditoría generada por IA.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/proyecto_detail_controller.dart';
import '../../models/auditoria.dart';
import '../../models/documento.dart';
import '../../models/expediente.dart';
import '../../models/funcionalidad.dart';
import '../../models/github_repo_info.dart';
import '../../models/proyecto.dart';
import '../../models/tarea.dart';
import '../../services/expediente_service.dart';
import '../../services/github_service.dart';
import '../../services/progreso_service.dart';
import '../../services/proyecto_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/estado_badge.dart';
import '../../widgets/expediente/expediente_detalle_widget.dart';
import '../../widgets/seccion_header.dart';
import '../asistente/asistente_screen.dart';
import '../auditorias/auditoria_form_screen.dart';
import '../expediente/editar_descripcion_expediente_screen.dart';
import '../expediente/expediente_revision_screen.dart';
import '../expediente/expediente_versiones_screen.dart';
import '../expediente/galeria_capturas_screen.dart';
import 'proyecto_form_screen.dart';

const _tabs = [
  Tab(text: 'Funcionalidades'),
  Tab(text: 'Ideas'),
  Tab(text: 'Documentos'),
  Tab(text: 'Pantallas'),
  Tab(text: 'Potencial'),
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
    // CustomScrollView en vez de un Column con Expanded: así, si la
    // cabecera (ficha + GitHub + progreso) no cupiera entera en pantallas
    // muy pequeñas, la página entera se desplaza en vez de desbordar -- un
    // Column fijo no tiene ese margen de seguridad.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _CabeceraProyecto(
              proyecto: proyecto,
              funcionalidades: _controller.funcionalidades,
              tareas: _controller.tareas,
              documentos: _controller.documentos,
              auditorias: _controller.auditorias,
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: true,
          child: TabBarView(
            children: [
              StreamBuilder<Expediente?>(
                stream: ExpedienteService.streamActualConfirmado(widget.proyectoId),
                builder: (context, snapshot) =>
                    _contenedorTab(_TabFuncionalidades(proyecto: proyecto, expediente: snapshot.data)),
              ),
              StreamBuilder<Expediente?>(
                stream: ExpedienteService.streamActualConfirmado(widget.proyectoId),
                builder: (context, snapshot) => _contenedorTab(_TabIdeas(proyecto: proyecto, expediente: snapshot.data)),
              ),
              StreamBuilder<Expediente?>(
                stream: ExpedienteService.streamActualConfirmado(widget.proyectoId),
                builder: (context, snapshot) => _contenedorTab(
                  _TabDocumentos(proyecto: proyecto, expediente: snapshot.data, auditorias: _controller.auditorias),
                ),
              ),
              StreamBuilder<Expediente?>(
                stream: ExpedienteService.streamActualConfirmado(widget.proyectoId),
                builder: (context, snapshot) => _contenedorTab(_TabPantallas(proyecto: proyecto, expediente: snapshot.data)),
              ),
              StreamBuilder<Expediente?>(
                stream: ExpedienteService.streamActualConfirmado(widget.proyectoId),
                builder: (context, snapshot) => _contenedorTab(_TabPotencial(proyecto: proyecto, expediente: snapshot.data)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contenedorTab(Widget seccion) => ListView(padding: const EdgeInsets.all(16), children: [seccion]);
}

/// Ficha básica + repositorio de GitHub + desglose de progreso -- antes era
/// la pestaña "Resumen" (Fase 8), ahora una cabecera fija visible en las 5
/// pestañas nuevas. Ni el contenido ni la lógica cambian, solo su lugar en
/// la pantalla.
class _CabeceraProyecto extends StatelessWidget {
  const _CabeceraProyecto({
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
    return Column(
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
        const SizedBox(height: 16),
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
/// "Analizar con IA" abre ExpedienteRevisionScreen (Fase 10) -- es la
/// única operación de análisis desde la reorganización de pestañas, en vez
/// de convivir con el AnalisisRepositorioScreen de la Fase 9.
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
                  MaterialPageRoute(builder: (_) => ExpedienteRevisionScreen(proyecto: proyecto)),
                ),
                icon: const Icon(Icons.auto_awesome),
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

/// Mensaje + CTA comunes a las 5 pestañas cuando todavía no hay un
/// expediente confirmado que mostrar (sin repo vinculado, o repo vinculado
/// pero sin analizar todavía).
class _EstadoVacioExpediente extends StatelessWidget {
  const _EstadoVacioExpediente({required this.proyecto});

  final Proyecto proyecto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (!proyecto.repoConectado) {
      return Text(
        'Vincula un repositorio de GitHub arriba para poder analizar esta aplicación.',
        style: TextStyle(color: colors.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Todavía no se ha analizado esta aplicación con IA. Analízala para ver su descripción, funcionalidades, '
          'ideas, documentación, pantallas y potencial.',
          style: TextStyle(color: colors.textMuted),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpedienteRevisionScreen(proyecto: proyecto))),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Analizar con IA'),
        ),
      ],
    );
  }
}

/// A. FUNCIONALIDADES -- introducción de la app + cómo funciona (en
/// lenguaje cotidiano, dirigido a un futuro usuario, no una ficha técnica).
class _TabFuncionalidades extends StatelessWidget {
  const _TabFuncionalidades({required this.proyecto, required this.expediente});

  final Proyecto proyecto;
  final Expediente? expediente;

  @override
  Widget build(BuildContext context) {
    final e = expediente;
    if (e == null) return _EstadoVacioExpediente(proyecto: proyecto);
    return ExpedienteSeccionCard(
      titulo: 'Qué es y cómo funciona',
      icono: Icons.auto_awesome_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DescripcionGeneralSeccion(d: e.descripcionGeneral, soloIntroduccion: true),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditarDescripcionExpedienteScreen(proyectoId: proyecto.id, expediente: e)),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Corregir'),
            ),
          ),
        ],
      ),
    );
  }
}

/// B. IDEAS -- qué cosas puedes hacer ya (catálogo coloquial) y qué
/// posibilidades futuras, claramente separadas.
class _TabIdeas extends StatelessWidget {
  const _TabIdeas({required this.proyecto, required this.expediente});

  final Proyecto proyecto;
  final Expediente? expediente;

  @override
  Widget build(BuildContext context) {
    final e = expediente;
    if (e == null) return _EstadoVacioExpediente(proyecto: proyecto);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpedienteSeccionCard(
          titulo: 'Qué puedes hacer ya (${e.catalogoFuncionalidades.length})',
          icono: Icons.checklist_outlined,
          child: CatalogoFuncionalidadesSeccion(funcionalidades: e.catalogoFuncionalidades),
        ),
        ExpedienteSeccionCard(
          titulo: 'Posibilidades futuras (${e.posibilidadesFuturas.length})',
          icono: Icons.lightbulb_outline,
          child: PosibilidadesFuturasSeccion(posibilidades: e.posibilidadesFuturas),
        ),
      ],
    );
  }
}

/// C. DOCUMENTOS -- la auditoría completa generada por IA (arquitectura,
/// calidad, seguridad, progreso y valor) y, debajo, el historial de
/// auditorías manuales/pegadas desde el chat (se conservan, solo cambian
/// de sitio).
class _TabDocumentos extends StatelessWidget {
  const _TabDocumentos({required this.proyecto, required this.expediente, required this.auditorias});

  final Proyecto proyecto;
  final Expediente? expediente;
  final List<Auditoria>? auditorias;

  @override
  Widget build(BuildContext context) {
    final e = expediente;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (e == null)
          _EstadoVacioExpediente(proyecto: proyecto)
        else ...[
          MetaGeneracionAviso(expediente: e),
          const SizedBox(height: 12),
          ExpedienteSeccionCard(titulo: 'Arquitectura', icono: Icons.architecture_outlined, child: ArquitecturaSeccion(a: e.arquitectura)),
          ExpedienteSeccionCard(
            titulo: 'Calidad del código',
            icono: Icons.verified_outlined,
            child: HallazgosSeccion(resumen: e.calidad.resumen, hallazgos: e.calidad.hallazgos),
          ),
          ExpedienteSeccionCard(
            titulo: 'Seguridad',
            icono: Icons.shield_outlined,
            child: HallazgosSeccion(resumen: e.seguridad.resumen, hallazgos: e.seguridad.hallazgos),
          ),
          ExpedienteSeccionCard(titulo: 'Progreso y valor', icono: Icons.insights_outlined, child: ProgresoValorSeccion(p: e.progresoValor)),
        ],
        const SizedBox(height: 8),
        _SeccionAuditorias(proyectoId: proyecto.id, auditorias: auditorias),
      ],
    );
  }
}

/// D. PANTALLAS -- qué pantallas se detectaron y la galería de capturas
/// manuales (Fase 10, reutilizada tal cual, solo embebida sin su propio
/// Scaffold).
class _TabPantallas extends StatelessWidget {
  const _TabPantallas({required this.proyecto, required this.expediente});

  final Proyecto proyecto;
  final Expediente? expediente;

  @override
  Widget build(BuildContext context) {
    final e = expediente;
    if (e == null) return _EstadoVacioExpediente(proyecto: proyecto);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpedienteSeccionCard(
          titulo: 'Pantallas detectadas (${e.pantallas.length})',
          icono: Icons.dashboard_outlined,
          child: ListaPantallasSeccion(pantallas: e.pantallas),
        ),
        ExpedienteSeccionCard(
          titulo: 'Capturas',
          icono: Icons.photo_library_outlined,
          child: GaleriaCapturasWidget(proyectoId: proyecto.id, pantallas: e.pantallas),
        ),
      ],
    );
  }
}

/// E. POTENCIAL -- valoración económica y potencial de usuarios, ya en el
/// formato de 3 escenarios + supuestos/limitaciones/confianza que pedía el
/// CEO.
class _TabPotencial extends StatelessWidget {
  const _TabPotencial({required this.proyecto, required this.expediente});

  final Proyecto proyecto;
  final Expediente? expediente;

  @override
  Widget build(BuildContext context) {
    final e = expediente;
    if (e == null) return _EstadoVacioExpediente(proyecto: proyecto);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpedienteSeccionCard(
          titulo: 'Valoración económica',
          icono: Icons.payments_outlined,
          child: ValoracionEconomicaSeccion(v: e.valoracionEconomica),
        ),
        ExpedienteSeccionCard(
          titulo: 'Potencial de usuarios',
          icono: Icons.groups_outlined,
          child: PotencialUsuariosSeccion(p: e.potencialUsuarios),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpedienteVersionesScreen(proyectoId: proyecto.id))),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('Versiones anteriores'),
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
        SeccionHeader(
          titulo: 'Auditorías manuales',
          icono: Icons.fact_check_outlined,
          accion: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Añadir auditoría',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuditoriaFormScreen(proyectoId: proyectoId))),
          ),
        ),
        if (auditorias == null)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else if (auditorias!.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin auditorías manuales todavía (también puedes pegar una desde el chat del asistente).', style: TextStyle(color: colors.textMuted)),
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
