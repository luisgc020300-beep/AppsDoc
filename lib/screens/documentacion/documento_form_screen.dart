// lib/screens/documentacion/documento_form_screen.dart
import 'package:flutter/material.dart';

import '../../models/categoria_documento.dart';
import '../../models/documento.dart';
import '../../services/documento_service.dart';
import '../../theme/design_tokens.dart';

class DocumentoFormScreen extends StatefulWidget {
  const DocumentoFormScreen({required this.proyectoId, this.documentoExistente, super.key});

  final String proyectoId;
  final Documento? documentoExistente;

  @override
  State<DocumentoFormScreen> createState() => _DocumentoFormScreenState();
}

class _DocumentoFormScreenState extends State<DocumentoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _tituloCtrl = TextEditingController(text: widget.documentoExistente?.titulo ?? '');
  late final _contenidoCtrl = TextEditingController(text: widget.documentoExistente?.contenido ?? '');
  late CategoriaDocumento _categoria = widget.documentoExistente?.categoria ?? CategoriaDocumento.nota;

  bool _guardando = false;
  String? _error;

  bool get _esNuevo => widget.documentoExistente == null;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _contenidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      if (_esNuevo) {
        await DocumentoService.crear(
          proyectoId: widget.proyectoId,
          titulo: _tituloCtrl.text,
          categoria: _categoria,
          contenido: _contenidoCtrl.text,
        );
      } else {
        await DocumentoService.actualizar(
          widget.proyectoId,
          widget.documentoExistente!.id,
          titulo: _tituloCtrl.text,
          categoria: _categoria,
          contenido: _contenidoCtrl.text,
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
        title: const Text('¿Eliminar este documento?'),
        content: Text('Se borrará "${widget.documentoExistente!.titulo}". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    try {
      await DocumentoService.eliminar(widget.proyectoId, widget.documentoExistente!.id);
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
        title: Text(_esNuevo ? 'Nuevo documento' : widget.documentoExistente!.titulo),
        actions: [
          if (!_esNuevo)
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
                const SizedBox(height: 20),
                Text('Categoría', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CategoriaDocumento.values.map((categoria) {
                    final seleccionada = categoria == _categoria;
                    return ChoiceChip(
                      label: Text(categoria.etiqueta),
                      avatar: Icon(categoria.icono, size: 16, color: seleccionada ? colors.onAccent : categoria.color),
                      selected: seleccionada,
                      onSelected: _guardando ? null : (_) => setState(() => _categoria = categoria),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contenidoCtrl,
                  decoration: const InputDecoration(labelText: 'Contenido'),
                  maxLines: 10,
                  minLines: 4,
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
                      : Text(_esNuevo ? 'Crear documento' : 'Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
