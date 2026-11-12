// lib/screens/auditorias/auditoria_form_screen.dart
//
// A diferencia de Funcionalidad/Documento/Tarea/Idea, una auditoría ya
// creada no se edita en sus campos de cabecera (fecha/origen/resumen/
// resultado) -- es un registro de un momento concreto. Lo único mutable
// después de crearla son sus hallazgos (añadir, cambiar estado, quitar).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/auditoria.dart';
import '../../models/estado_hallazgo.dart';
import '../../models/gravedad_hallazgo.dart';
import '../../models/origen_auditoria.dart';
import '../../models/resultado_auditoria.dart';
import '../../services/auditoria_service.dart';
import '../../theme/design_tokens.dart';

class AuditoriaFormScreen extends StatefulWidget {
  const AuditoriaFormScreen({required this.proyectoId, this.auditoriaExistente, super.key});

  final String proyectoId;
  final Auditoria? auditoriaExistente;

  @override
  State<AuditoriaFormScreen> createState() => _AuditoriaFormScreenState();
}

class _AuditoriaFormScreenState extends State<AuditoriaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _resumenCtrl = TextEditingController(text: widget.auditoriaExistente?.resumen ?? '');
  late DateTime _fecha = widget.auditoriaExistente?.fecha ?? DateTime.now();
  late OrigenAuditoria _origen = widget.auditoriaExistente?.origen ?? OrigenAuditoria.manual;
  late ResultadoAuditoria _resultado = widget.auditoriaExistente?.resultado ?? ResultadoAuditoria.conObservaciones;

  bool _guardando = false;
  String? _error;

  bool get _esNueva => widget.auditoriaExistente == null;

  @override
  void dispose() {
    _resumenCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await AuditoriaService.crear(
        proyectoId: widget.proyectoId,
        fecha: _fecha,
        origen: _origen,
        resumen: _resumenCtrl.text,
        resultado: _resultado,
      );
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
        title: const Text('¿Eliminar esta auditoría?'),
        content: const Text('Se borrará junto con todos sus hallazgos. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    try {
      await AuditoriaService.eliminar(widget.proyectoId, widget.auditoriaExistente!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _guardando = false;
      });
    }
  }

  Future<void> _agregarHallazgo() async {
    final tituloCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();
    var gravedad = GravedadHallazgo.media;
    final formKey = GlobalKey<FormState>();

    final agregado = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuevo hallazgo'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: tituloCtrl,
                    decoration: const InputDecoration(labelText: 'Título'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'El título es obligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descripcionCtrl,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: GravedadHallazgo.values.map((g) {
                      return ChoiceChip(
                        label: Text(g.etiqueta),
                        selected: g == gravedad,
                        onSelected: (_) => setDialogState(() => gravedad = g),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );

    if (agregado != true) return;
    await AuditoriaService.agregarHallazgo(
      widget.proyectoId,
      widget.auditoriaExistente!.id,
      titulo: tituloCtrl.text,
      descripcion: descripcionCtrl.text,
      gravedad: gravedad,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(_esNueva ? 'Nueva auditoría' : 'Auditoría del ${DateFormat('dd/MM/yyyy').format(widget.auditoriaExistente!.fecha)}'),
        actions: [
          if (!_esNueva)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Eliminar', onPressed: _guardando ? null : _eliminar),
        ],
      ),
      body: SafeArea(
        child: _esNueva ? _buildFormularioCreacion(colors) : _buildVistaExistenteReactiva(colors),
      ),
    );
  }

  /// Los hallazgos se añaden/cambian de estado/quitan sin salir de esta
  /// pantalla -- a diferencia del resto de fichas, aquí sí hace falta un
  /// stream (no basta con el `widget.auditoriaExistente` fijo que llegó al
  /// navegar) para que la lista se mantenga al día.
  Widget _buildVistaExistenteReactiva(AppsDocColorsExt colors) {
    return StreamBuilder<Auditoria?>(
      stream: AuditoriaService.streamAuditoria(widget.proyectoId, widget.auditoriaExistente!.id),
      initialData: widget.auditoriaExistente,
      builder: (context, snapshot) {
        final auditoria = snapshot.data;
        if (auditoria == null) {
          return Center(
            child: Text('Esta auditoría ya no existe.', style: TextStyle(color: colors.textMuted)),
          );
        }
        return _buildVistaExistente(colors, auditoria);
      },
    );
  }

  Widget _buildFormularioCreacion(AppsDocColorsExt colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fecha', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _guardando ? null : _elegirFecha,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
            ),
            const SizedBox(height: 20),
            Text('Origen', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: OrigenAuditoria.values.map((origen) {
                final seleccionado = origen == _origen;
                return ChoiceChip(
                  label: Text(origen.etiqueta),
                  avatar: Icon(origen.icono, size: 16, color: seleccionado ? colors.onAccent : origen.color),
                  selected: seleccionado,
                  onSelected: _guardando ? null : (_) => setState(() => _origen = origen),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _resumenCtrl,
              decoration: const InputDecoration(
                labelText: 'Resumen',
                hintText: 'Puedes pegar aquí el texto completo de una auditoría (por ejemplo, de Claude)',
              ),
              maxLines: 10,
              minLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El resumen es obligatorio' : null,
            ),
            const SizedBox(height: 20),
            Text('Resultado', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ResultadoAuditoria.values.map((resultado) {
                final seleccionado = resultado == _resultado;
                return ChoiceChip(
                  label: Text(resultado.etiqueta),
                  avatar: Icon(resultado.icono, size: 16, color: seleccionado ? colors.onAccent : resultado.color),
                  selected: seleccionado,
                  onSelected: _guardando ? null : (_) => setState(() => _resultado = resultado),
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
              onPressed: _guardando ? null : _crear,
              child: _guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Crear auditoría'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVistaExistente(AppsDocColorsExt colors, Auditoria auditoria) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(auditoria.origen.icono, size: 16, color: auditoria.origen.color),
                        const SizedBox(width: 4),
                        Text(auditoria.origen.etiqueta, style: TextStyle(color: auditoria.origen.color)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(auditoria.resultado.icono, size: 16, color: auditoria.resultado.color),
                        const SizedBox(width: 4),
                        Text(auditoria.resultado.etiqueta, style: TextStyle(color: auditoria.resultado.color)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(auditoria.resumen, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('Hallazgos', style: Theme.of(context).textTheme.titleMedium)),
            IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: 'Añadir hallazgo', onPressed: _agregarHallazgo),
          ],
        ),
        if (auditoria.hallazgos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin hallazgos todavía.', style: TextStyle(color: colors.textMuted)),
          )
        else
          ...auditoria.hallazgos.map(
            (h) => Card(
              child: ListTile(
                leading: Icon(h.gravedad.icono, color: h.gravedad.color),
                title: Text(h.titulo),
                subtitle: Row(
                  children: [
                    Icon(h.estado.icono, size: 14, color: h.estado.color),
                    const SizedBox(width: 4),
                    Text(h.estado.etiqueta, style: TextStyle(color: h.estado.color)),
                    const SizedBox(width: 10),
                    Text(h.gravedad.etiqueta, style: TextStyle(color: h.gravedad.color, fontSize: 12)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<EstadoHallazgo>(
                      tooltip: 'Cambiar estado',
                      initialValue: h.estado,
                      onSelected: (nuevo) => AuditoriaService.actualizarEstadoHallazgo(widget.proyectoId, auditoria.id, h.id, nuevo),
                      itemBuilder: (context) =>
                          EstadoHallazgo.values.map((e) => PopupMenuItem(value: e, child: Text(e.etiqueta))).toList(),
                      child: Icon(Icons.more_vert, color: colors.textMuted),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Quitar hallazgo',
                      onPressed: () => AuditoriaService.eliminarHallazgo(widget.proyectoId, auditoria.id, h.id),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
