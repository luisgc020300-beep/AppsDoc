// lib/screens/funcionalidades/funcionalidad_form_screen.dart
//
// Mismo patrón que ProyectoFormScreen: una sola pantalla para crear y
// editar, con el botón de eliminar visible solo al editar una ya existente.
import 'package:flutter/material.dart';

import '../../models/estado_funcionalidad.dart';
import '../../models/funcionalidad.dart';
import '../../services/funcionalidad_service.dart';
import '../../theme/design_tokens.dart';

class FuncionalidadFormScreen extends StatefulWidget {
  const FuncionalidadFormScreen({required this.proyectoId, this.funcionalidadExistente, super.key});

  final String proyectoId;
  final Funcionalidad? funcionalidadExistente;

  @override
  State<FuncionalidadFormScreen> createState() => _FuncionalidadFormScreenState();
}

class _FuncionalidadFormScreenState extends State<FuncionalidadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreCtrl = TextEditingController(text: widget.funcionalidadExistente?.nombre ?? '');
  late final _descripcionCtrl = TextEditingController(text: widget.funcionalidadExistente?.descripcion ?? '');
  late final _notasCtrl = TextEditingController(text: widget.funcionalidadExistente?.notas ?? '');
  late EstadoFuncionalidad _estado = widget.funcionalidadExistente?.estado ?? EstadoFuncionalidad.planificada;

  bool _guardando = false;
  String? _error;

  bool get _esNueva => widget.funcionalidadExistente == null;

  @override
  void dispose() {
    _nombreCtrl.dispose();
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
        await FuncionalidadService.crear(
          proyectoId: widget.proyectoId,
          nombre: _nombreCtrl.text,
          descripcion: _descripcionCtrl.text,
          estado: _estado,
          notas: _notasCtrl.text,
        );
      } else {
        await FuncionalidadService.actualizar(
          widget.proyectoId,
          widget.funcionalidadExistente!.id,
          nombre: _nombreCtrl.text,
          descripcion: _descripcionCtrl.text,
          estado: _estado,
          notas: _notasCtrl.text,
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
        title: const Text('¿Eliminar esta funcionalidad?'),
        content: Text('Se borrará "${widget.funcionalidadExistente!.nombre}". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    try {
      await FuncionalidadService.eliminar(widget.proyectoId, widget.funcionalidadExistente!.id);
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
        title: Text(_esNueva ? 'Nueva funcionalidad' : widget.funcionalidadExistente!.nombre),
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
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
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
                  children: EstadoFuncionalidad.values.map((estado) {
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
                      : Text(_esNueva ? 'Crear funcionalidad' : 'Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
