// lib/screens/asistente/asistente_screen.dart
//
// Chat efímero: las preguntas y respuestas viven solo en esta pantalla
// (no se guardan en Firestore) -- cada pregunta se envía con el contexto
// completo del proyecto ya recalculado en el backend, así que no hace
// falta mantener historial de conversación en el cliente ni en el
// servidor. Lo único que deja rastro permanente es confirmar una
// propuesta desde "Pegar auditoría", que usa los servicios de siempre y
// por tanto ya queda en el historial del proyecto.
import 'package:flutter/material.dart';

import '../../models/github_repo_info.dart';
import '../../models/proyecto.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/github_service.dart';
import '../../theme/design_tokens.dart';
import 'pegar_auditoria_screen.dart';

class AsistenteScreen extends StatefulWidget {
  const AsistenteScreen({required this.proyecto, super.key});

  final Proyecto proyecto;

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _MensajeChat {
  const _MensajeChat({required this.texto, required this.esUsuario, this.esError = false});

  final String texto;
  final bool esUsuario;
  final bool esError;
}

const _preguntasSugeridas = ['¿Por dónde iba?', '¿Qué falta para publicar?', '¿Qué debería hacer ahora?'];

class _AsistenteScreenState extends State<AsistenteScreen> {
  final _mensajes = <_MensajeChat>[];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _enviando = false;
  GithubRepoInfo? _githubResumen;
  bool _githubResumenIntentado = false;

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

    setState(() {
      _mensajes.add(_MensajeChat(texto: texto, esUsuario: true));
      _controller.clear();
      _enviando = true;
    });
    _scrollAlFinal();

    await _asegurarGithubResumen();

    try {
      final respuesta = await AiAssistantService.preguntar(
        proyectoId: widget.proyecto.id,
        pregunta: texto,
        githubResumen: _githubResumen,
      );
      setState(() => _mensajes.add(_MensajeChat(texto: respuesta, esUsuario: false)));
    } on AiAssistantException catch (e) {
      setState(() => _mensajes.add(_MensajeChat(texto: e.mensaje, esUsuario: false, esError: true)));
    } finally {
      setState(() => _enviando = false);
    }
    _scrollAlFinal();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text('Asistente · ${widget.proyecto.nombre}'),
        actions: [
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
              child: _mensajes.isEmpty
                  ? _EstadoVacio(onTapSugerencia: _enviar)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _mensajes.length + (_enviando ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _mensajes.length) {
                          return const _BurbujaPensando();
                        }
                        return _BurbujaMensaje(mensaje: _mensajes[i]);
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

  final _MensajeChat mensaje;

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
