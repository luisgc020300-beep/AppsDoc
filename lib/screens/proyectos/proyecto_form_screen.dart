// lib/screens/proyectos/proyecto_form_screen.dart
//
// Ficha básica de un proyecto (Fase 1): crear y editar comparten la misma
// pantalla (si [proyectoExistente] es null, es un alta nueva). El botón
// de eliminar solo aparece al editar uno ya existente.
import 'package:flutter/material.dart';

import '../../models/estado_proyecto.dart';
import '../../models/proyecto.dart';
import '../../services/proyecto_service.dart';
import '../../theme/design_tokens.dart';

class ProyectoFormScreen extends StatefulWidget {
  const ProyectoFormScreen({this.proyectoExistente, super.key});

  final Proyecto? proyectoExistente;

  @override
  State<ProyectoFormScreen> createState() => _ProyectoFormScreenState();
}

class _ProyectoFormScreenState extends State<ProyectoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreCtrl = TextEditingController(text: widget.proyectoExistente?.nombre ?? '');
  late final _descripcionCtrl = TextEditingController(text: widget.proyectoExistente?.descripcion ?? '');
  late EstadoProyecto _estado = widget.proyectoExistente?.estado ?? EstadoProyecto.idea;

  bool _guardando = false;
  String? _error;

  bool get _esNuevo => widget.proyectoExistente == null;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
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
        await ProyectoService.crear(nombre: _nombreCtrl.text, descripcion: _descripcionCtrl.text, estado: _estado);
      } else {
        await ProyectoService.actualizar(
          widget.proyectoExistente!.id,
          nombre: _nombreCtrl.text,
          descripcion: _descripcionCtrl.text,
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
        title: const Text('¿Eliminar este proyecto?'),
        content: Text('Se borrará "${widget.proyectoExistente!.nombre}" de AppsDoc. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    try {
      await ProyectoService.eliminar(widget.proyectoExistente!.id);
      // true = "se eliminó" -- quien abrió esta pantalla (el detalle del
      // proyecto) lo usa para cerrarse también, ya que no tiene sentido
      // seguir mostrando la ficha de un proyecto que ya no existe.
      if (mounted) Navigator.pop(context, true);
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
        title: Text(_esNuevo ? 'Nuevo proyecto' : widget.proyectoExistente!.nombre),
        actions: [
          if (!_esNuevo)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              onPressed: _guardando ? null : _eliminar,
            ),
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
                  children: EstadoProyecto.values.map((estado) {
                    final seleccionado = estado == _estado;
                    return ChoiceChip(
                      label: Text(estado.etiqueta),
                      avatar: Icon(estado.icono, size: 16, color: seleccionado ? colors.onAccent : estado.color),
                      selected: seleccionado,
                      onSelected: _guardando ? null : (_) => setState(() => _estado = estado),
                    );
                  }).toList(),
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
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_esNuevo ? 'Crear proyecto' : 'Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
