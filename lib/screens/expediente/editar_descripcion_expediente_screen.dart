// lib/screens/expediente/editar_descripcion_expediente_screen.dart
//
// Corrección manual de la descripción general de un expediente YA
// confirmado -- vía ExpedienteService.editarCampo(), in-place, sin generar
// una versión nueva. El resto de secciones (pantallas, catálogo, hallazgos,
// valoración...) no tienen edición manual todavía: para corregirlas hay que
// volver a generar el expediente.
import 'package:flutter/material.dart';

import '../../models/expediente.dart';
import '../../services/expediente_service.dart';
import '../../theme/design_tokens.dart';

class EditarDescripcionExpedienteScreen extends StatefulWidget {
  const EditarDescripcionExpedienteScreen({required this.proyectoId, required this.expediente, super.key});

  final String proyectoId;
  final Expediente expediente;

  @override
  State<EditarDescripcionExpedienteScreen> createState() => _EditarDescripcionExpedienteScreenState();
}

class _EditarDescripcionExpedienteScreenState extends State<EditarDescripcionExpedienteScreen> {
  late final _resumenCtrl = TextEditingController(text: widget.expediente.descripcionGeneral.resumen);
  late final _propuestaValorCtrl = TextEditingController(text: widget.expediente.descripcionGeneral.propuestaValor);
  late final _publicoObjetivoCtrl = TextEditingController(text: widget.expediente.descripcionGeneral.publicoObjetivo);
  late final _estadoMadurezCtrl = TextEditingController(text: widget.expediente.descripcionGeneral.estadoMadurez);

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _resumenCtrl.dispose();
    _propuestaValorCtrl.dispose();
    _publicoObjetivoCtrl.dispose();
    _estadoMadurezCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ExpedienteService.editarCampo(widget.proyectoId, widget.expediente.id, {
        'descripcionGeneral': SeccionDescripcionGeneral(
          resumen: _resumenCtrl.text.trim(),
          propuestaValor: _propuestaValorCtrl.text.trim(),
          publicoObjetivo: _publicoObjetivoCtrl.text.trim(),
          estadoMadurez: _estadoMadurezCtrl.text.trim(),
        ).toJson(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Corregir descripción general')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _resumenCtrl, decoration: const InputDecoration(labelText: 'Resumen'), maxLines: 4, minLines: 2),
              const SizedBox(height: 16),
              TextFormField(
                controller: _propuestaValorCtrl,
                decoration: const InputDecoration(labelText: 'Cómo funciona'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _publicoObjetivoCtrl,
                decoration: const InputDecoration(labelText: 'Público objetivo'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _estadoMadurezCtrl,
                decoration: const InputDecoration(labelText: 'Estado de madurez'),
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
                    : const Text('Guardar correcciones'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
