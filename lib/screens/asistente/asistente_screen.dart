// lib/screens/asistente/asistente_screen.dart
//
// El historial de la conversación se persiste en Firestore
// (MensajeAsistenteService) -- sobrevive a salir y volver a entrar. Cada
// pregunta se envía con el contexto completo del proyecto ya recalculado
// en el backend, así que no hace falta reenviar el historial anterior a la
// IA: cada turno sigue siendo independiente, solo la UI recuerda la
// conversación. "Nueva conversación" borra el historial (irreversible, con
// confirmación). Lo único que además deja rastro permanente en el propio
// proyecto es confirmar una propuesta desde "Pegar auditoría", que usa los
// servicios de siempre y por tanto ya queda en el historial del proyecto.
import 'package:flutter/material.dart';

import '../../models/github_repo_info.dart';
import '../../models/mensaje_asistente.dart';
import '../../models/proyecto.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/github_service.dart';
import '../../services/mensaje_asistente_service.dart';
import '../../theme/design_tokens.dart';
import 'pegar_auditoria_screen.dart';

class AsistenteScreen extends StatefulWidget {
  const AsistenteScreen({required this.proyecto, super.key});

  final Proyecto proyecto;

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

const _preguntasSugeridas = ['¿Por dónde iba?', '¿Qué falta para publicar?', '¿Qué debería hacer ahora?'];

class _AsistenteScreenState extends State<AsistenteScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _enviando = false;
  GithubRepoInfo? _githubResumen;
  bool _githubResumenIntentado = false;

  // Creado UNA sola vez, no dentro de build(): si StreamBuilder recibe una
  // instancia de Stream nueva en cada reconstrucción (p.ej. cada vez que
  // _enviando cambia), cancela y vuelve a suscribirse cada vez -- con
  // fake_cloud_firestore eso puede perder la emisión final de una
  // suscripción cancelada a destiempo (confirmado al depurar que "Nueva
  // conversación" a veces no refrescaba la pantalla).
  late final Stream<List<MensajeAsistente>> _mensajesStream = MensajeAsistenteService.streamMensajes(widget.proyecto.id);

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _asegurarGithubResumen() async {
    if (_githubResumenIntentado || !widget.proyecto.repoConectado) return;
    _githubResumenIntentado = true;
    try {
      _githubResumen = await GithubService.obtenerResumenRepo(
        propietario: widget.proyecto.repoPropietario,
        nombre: widget.proyecto.repoNombre,
      );
    } catch (_) {
      // Mejor esfuerzo: si GitHub no responde, el asistente sigue
      // funcionando solo con los datos propios del proyecto.
    }
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _enviar([String? textoSugerido]) async {
    final texto = (textoSugerido ?? _controller.text).trim();
    if (texto.isEmpty || _enviando) return;

    _controller.clear();
    setState(() => _enviando = true);
    await MensajeAsistenteService.agregar(proyectoId: widget.proyecto.id, texto: texto, esUsuario: true);
    _scrollAlFinal();

    await _asegurarGithubResumen();

    try {
      final respuesta = await AiAssistantService.preguntar(
        proyectoId: widget.proyecto.id,
        pregunta: texto,
        githubResumen: _githubResumen,
      );
      await MensajeAsistenteService.agregar(proyectoId: widget.proyecto.id, texto: respuesta, esUsuario: false);
    } on AiAssistantException catch (e) {
      await MensajeAsistenteService.agregar(proyectoId: widget.proyecto.id, texto: e.mensaje, esUsuario: false, esError: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
    _scrollAlFinal();
  }

  Future<void> _nuevaConversacion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Empezar una conversación nueva?'),
        content: const Text('Se borrará todo el historial de este chat. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Empezar de nuevo')),
        ],
      ),
    );
    if (confirmar != true) return;
    await MensajeAsistenteService.limpiar(widget.proyecto.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text('Asistente · ${widget.proyecto.nombre}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Nueva conversación',
            onPressed: _nuevaConversacion,
          ),
          IconButton(
            icon: const Icon(Icons.content_paste_outlined),
            tooltip: 'Pegar auditoría',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PegarAuditoriaScreen(proyectoId: widget.proyecto.id)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MensajeAsistente>>(
                stream: _mensajesStream,
                builder: (context, snapshot) {
                  final mensajes = snapshot.data;
                  if (mensajes == null) return const Center(child: CircularProgressIndicator());
                  if (mensajes.isEmpty && !_enviando) return _EstadoVacio(onTapSugerencia: _enviar);
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: mensajes.length + (_enviando ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= mensajes.length) {
                        return const _BurbujaPensando();
                      }
                      return _BurbujaMensaje(mensaje: mensajes[i]);
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_enviando,
                        decoration: const InputDecoration(hintText: 'Pregúntale algo sobre este proyecto…'),
                        onSubmitted: (_) => _enviar(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.arrow_upward),
                      tooltip: 'Enviar',
                      onPressed: _enviando ? null : () => _enviar(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: colors.background,
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.onTapSugerencia});

  final void Function(String) onTapSugerencia;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: colors.accent),
            const SizedBox(height: 16),
            Text(
              'Pregúntale al asistente sobre este proyecto',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Conoce las funcionalidades, tareas, ideas, auditorías, historial y el repositorio de GitHub.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _preguntasSugeridas
                  .map((p) => ActionChip(label: Text(p), onPressed: () => onTapSugerencia(p)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BurbujaMensaje extends StatelessWidget {
  const _BurbujaMensaje({required this.mensaje});

  final MensajeAsistente mensaje;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fondo = mensaje.esError
        ? colors.danger.withValues(alpha: 0.12)
        : mensaje.esUsuario
        ? colors.accent
        : colors.surfaceMuted;
    final texto = mensaje.esUsuario ? colors.onAccent : (mensaje.esError ? colors.danger : colors.textPrimary);

    return Align(
      alignment: mensaje.esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14)),
        child: Text(mensaje.texto, style: TextStyle(color: texto)),
      ),
    );
  }
}

class _BurbujaPensando extends StatelessWidget {
  const _BurbujaPensando();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.textMuted),
        ),
      ),
    );
  }
}
