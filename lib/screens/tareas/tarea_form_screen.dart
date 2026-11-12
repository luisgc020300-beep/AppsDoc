// lib/screens/tareas/tarea_form_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/estado_tarea.dart';
import '../../models/prioridad_tarea.dart';
import '../../models/tarea.dart';
import '../../services/tarea_service.dart';
import '../../theme/design_tokens.dart';

class TareaFormScreen extends StatefulWidget {
  const TareaFormScreen({required this.proyectoId, this.tareaExistente, super.key});

  final String proyectoId;
  final Tarea? tareaExistente;

  @override
  State<TareaFormScreen> createState() => _TareaFormScreenState();
}

class _TareaFormScreenState extends State<TareaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _tituloCtrl = TextEditingController(text: widget.tareaExistente?.titulo ?? '');
  late final _descripcionCtrl = TextEditingController(text: widget.tareaExistente?.descripcion ?? '');
  late EstadoTarea _estado = widget.tareaExistente?.estado ?? EstadoTarea.pendiente;
  late PrioridadTarea _prioridad = widget.tareaExistente?.prioridad ?? PrioridadTarea.media;
  DateTime? _fechaLimite;

  bool _guardando = false;
  String? _error;

  bool get _esNueva => widget.tareaExistente == null;

  @override
  void initState() {
    super.initState();
    _fechaLimite = widget.tareaExistente?.fechaLimite;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaLimite ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null) setState(() => _fechaLimite = elegida);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      if (_esNueva) {
        await TareaService.crear(
          proyectoId: widget.proyectoId,
          titulo: _tituloCtrl.text,
          descripcion: _descripcionCtrl.text,
          estado: _estado,
          prioridad: _prioridad,
          fechaLimite: _fechaLimite,
        );
      } else {
        await TareaService.actualizar(
          widget.proyectoId,
          widget.tareaExistente!.id,
          titulo: _tituloCtrl.text,
          descripcion: _descripcionCtrl.text,
          estado: _estado,
          prioridad: _prioridad,
          fechaLimite: _fechaLimite,
          quitarFechaLimite: _fechaLimite == null,
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
        title: const Text('¿Eliminar esta tarea?'),
        content: Text('Se borrará "${widget.tareaExistente!.titulo}". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    try {
      await TareaService.eliminar(widget.proyectoId, widget.tareaExistente!.id);
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
        title: Text(_esNueva ? 'Nueva tarea' : widget.tareaExistente!.titulo),
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
                  children: EstadoTarea.values.map((estado) {
                    final seleccionado = estado == _estado;
                    return ChoiceChip(
                      label: Text(estado.etiqueta),
                      avatar: Icon(estado.icono, size: 16, color: seleccionado ? colors.onAccent : estado.color),
                      selected: seleccionado,
                      onSelected: _guardando ? null : (_) => setState(() => _estado = estado),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text('Prioridad', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PrioridadTarea.values.map((prioridad) {
                    final seleccionada = prioridad == _prioridad;
                    return ChoiceChip(
                      label: Text(prioridad.etiqueta),
                      avatar: Icon(prioridad.icono, size: 16, color: seleccionada ? colors.onAccent : prioridad.color),
                      selected: seleccionada,
                      onSelected: _guardando ? null : (_) => setState(() => _prioridad = prioridad),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text('Fecha límite', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _guardando ? null : _elegirFecha,
                        icon: const Icon(Icons.calendar_today_outlined, size: 18),
                        label: Text(_fechaLimite == null ? 'Sin fecha' : DateFormat('dd/MM/yyyy').format(_fechaLimite!)),
                      ),
                    ),
                    if (_fechaLimite != null)
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Quitar fecha',
                        onPressed: _guardando ? null : () => setState(() => _fechaLimite = null),
                      ),
                  ],
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
                      : Text(_esNueva ? 'Crear tarea' : 'Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
