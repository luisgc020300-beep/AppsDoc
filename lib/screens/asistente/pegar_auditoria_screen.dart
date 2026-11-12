// lib/screens/asistente/pegar_auditoria_screen.dart
//
// Pegar -> extraer -> revisar -> confirmar. La IA solo propone (resumen,
// hallazgos, tareas); nada se guarda hasta que el usuario pulsa
// "Guardar" sobre la propuesta ya revisada, y puede desmarcar cualquier
// hallazgo o tarea que no quiera conservar. Guardar reutiliza
// AuditoriaService/TareaService de siempre, que ya dejan su propio
// rastro en el historial del proyecto -- no hace falta nada nuevo para
// eso aquí.
import 'package:flutter/material.dart';

import '../../models/hallazgo.dart';
import '../../models/origen_auditoria.dart';
import '../../models/propuesta_auditoria.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/auditoria_service.dart';
import '../../services/tarea_service.dart';
import '../../theme/design_tokens.dart';

class PegarAuditoriaScreen extends StatefulWidget {
  const PegarAuditoriaScreen({required this.proyectoId, super.key});

  final String proyectoId;

  @override
  State<PegarAuditoriaScreen> createState() => _PegarAuditoriaScreenState();
}

class _PegarAuditoriaScreenState extends State<PegarAuditoriaScreen> {
  final _textoCtrl = TextEditingController();
  TextEditingController? _resumenCtrl;
  PropuestaAuditoria? _propuesta;
  List<bool> _hallazgosSeleccionados = [];
  List<bool> _tareasSeleccionadas = [];

  bool _extrayendo = false;
  bool _guardando = false;
  String? _error;

  bool get _hayPropuesta => _propuesta != null;

  @override
  void dispose() {
    _textoCtrl.dispose();
    _resumenCtrl?.dispose();
    super.dispose();
  }

  Future<void> _extraer() async {
    if (_textoCtrl.text.trim().isEmpty) return;
    setState(() {
      _extrayendo = true;
      _error = null;
    });
    try {
      final propuesta = await AiAssistantService.extraerAuditoria(proyectoId: widget.proyectoId, texto: _textoCtrl.text);
      setState(() {
        _propuesta = propuesta;
        _resumenCtrl = TextEditingController(text: propuesta.resumen);
        _hallazgosSeleccionados = List.filled(propuesta.hallazgos.length, true);
        _tareasSeleccionadas = List.filled(propuesta.tareas.length, true);
      });
    } on AiAssistantException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      setState(() => _extrayendo = false);
    }
  }

  void _volverAPegar() {
    setState(() {
      _propuesta = null;
      _resumenCtrl = null;
      _error = null;
    });
  }

  Future<void> _guardar() async {
    final propuesta = _propuesta;
    if (propuesta == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final hallazgos = <Hallazgo>[
        for (var i = 0; i < propuesta.hallazgos.length; i++)
          if (_hallazgosSeleccionados[i])
            Hallazgo(
              id: '${DateTime.now().microsecondsSinceEpoch}-$i',
              titulo: propuesta.hallazgos[i].titulo,
              descripcion: propuesta.hallazgos[i].descripcion,
              gravedad: propuesta.hallazgos[i].gravedad,
            ),
      ];

      await AuditoriaService.crear(
        proyectoId: widget.proyectoId,
        fecha: DateTime.now(),
        origen: OrigenAuditoria.claude,
        resumen: _resumenCtrl!.text,
        hallazgos: hallazgos,
      );

      for (var i = 0; i < propuesta.tareas.length; i++) {
        if (!_tareasSeleccionadas[i]) continue;
        await TareaService.crear(
          proyectoId: widget.proyectoId,
          titulo: propuesta.tareas[i].titulo,
          descripcion: propuesta.tareas[i].descripcion,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auditoría guardada')));
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_hayPropuesta ? 'Revisar propuesta' : 'Pegar auditoría')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _hayPropuesta ? _buildRevision(context) : _buildPegar(context),
        ),
      ),
    );
  }

  Widget _buildPegar(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pega aquí el texto de una auditoría o revisión (por ejemplo, generada por Claude en otra conversación). '
          'La IA extraerá un resumen, los hallazgos y posibles tareas -- podrás revisarlo todo antes de guardar nada.',
          style: TextStyle(color: colors.textMuted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _textoCtrl,
          enabled: !_extrayendo,
          decoration: const InputDecoration(labelText: 'Texto de la auditoría'),
          maxLines: 14,
          minLines: 8,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: colors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: TextStyle(color: colors.danger))),
            ],
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _extrayendo ? null : _extraer,
          child: _extrayendo
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Extraer'),
        ),
      ],
    );
  }

  Widget _buildRevision(BuildContext context) {
    final colors = context.colors;
    final propuesta = _propuesta!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Resumen', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(controller: _resumenCtrl, maxLines: 4, minLines: 2),
        const SizedBox(height: 20),
        Text('Hallazgos (${propuesta.hallazgos.length})', style: Theme.of(context).textTheme.titleSmall),
        if (propuesta.hallazgos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('La IA no detectó hallazgos en el texto pegado.', style: TextStyle(color: colors.textMuted)),
          )
        else
          ...List.generate(propuesta.hallazgos.length, (i) {
            final h = propuesta.hallazgos[i];
            return CheckboxListTile(
              value: _hallazgosSeleccionados[i],
              onChanged: (v) => setState(() => _hallazgosSeleccionados[i] = v ?? false),
              title: Text(h.titulo),
              subtitle: Text(
                '${h.gravedad.etiqueta}${h.descripcion.isNotEmpty ? ' · ${h.descripcion}' : ''}',
                style: TextStyle(color: h.gravedad.color),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
        const SizedBox(height: 12),
        Text('Tareas propuestas (${propuesta.tareas.length})', style: Theme.of(context).textTheme.titleSmall),
        if (propuesta.tareas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('La IA no propuso ninguna tarea.', style: TextStyle(color: colors.textMuted)),
          )
        else
          ...List.generate(propuesta.tareas.length, (i) {
            final t = propuesta.tareas[i];
            return CheckboxListTile(
              value: _tareasSeleccionadas[i],
              onChanged: (v) => setState(() => _tareasSeleccionadas[i] = v ?? false),
              title: Text(t.titulo),
              subtitle: t.descripcion.isNotEmpty ? Text(t.descripcion) : null,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: colors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: TextStyle(color: colors.danger))),
            ],
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Guardar'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: _guardando ? null : _volverAPegar, child: const Text('Volver a pegar otro texto')),
      ],
    );
  }
}
