// lib/screens/ideas/idea_form_screen.dart
import 'package:flutter/material.dart';

import '../../models/estado_idea.dart';
import '../../models/idea.dart';
import '../../services/idea_service.dart';
import '../../theme/design_tokens.dart';

class IdeaFormScreen extends StatefulWidget {
  const IdeaFormScreen({required this.proyectoId, this.ideaExistente, super.key});

  final String proyectoId;
  final Idea? ideaExistente;

  @override
  State<IdeaFormScreen> createState() => _IdeaFormScreenState();
}

class _IdeaFormScreenState extends State<IdeaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _tituloCtrl = TextEditingController(text: widget.ideaExistente?.titulo ?? '');
  late final _descripcionCtrl = TextEditingController(text: widget.ideaExistente?.descripcion ?? '');
  late final _notasCtrl = TextEditingController(text: widget.ideaExistente?.notas ?? '');
  late EstadoIdea _estado = widget.ideaExistente?.estado ?? EstadoIdea.nueva;

  bool _guardando = false;
  String? _error;

  bool get _esNueva => widget.ideaExistente == null;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      if (_esNueva) {
        await IdeaService.crear(
          proyectoId: widget.proyectoId,
          titulo: _tituloCtrl.text,
          descripcion: _descripcionCtrl.text,
          notas: _notasCtrl.text,
          estado: _estado,
        );
      } else {
        await IdeaService.actualizar(
          widget.proyectoId,
          widget.ideaExistente!.id,
          titulo: _tituloCtrl.text,
          descripcion: _descripcionCtrl.text,
          notas: _notasCtrl.text,
          estado: _estado,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar esta idea?'),
        content: Text('Se borrará "${widget.ideaExistente!.titulo}". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    try {
      await IdeaService.eliminar(widget.proyectoId, widget.ideaExistente!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(_esNueva ? 'Nueva idea' : widget.ideaExistente!.titulo),
        actions: [
          if (!_esNueva)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Eliminar', onPressed: _guardando ? null : _eliminar),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _tituloCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'El título es obligatorio' : null,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),
                Text('Estado', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: EstadoIdea.values.map((estado) {
                    final seleccionado = estado == _estado;
                    return ChoiceChip(
                      label: Text(estado.etiqueta),
                      avatar: Icon(estado.icono, size: 16, color: seleccionado ? colors.onAccent : estado.color),
                      selected: seleccionado,
                      onSelected: _guardando ? null : (_) => setState(() => _estado = estado),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notasCtrl,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
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
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_esNueva ? 'Crear idea' : 'Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
