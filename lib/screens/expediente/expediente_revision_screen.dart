// lib/screens/expediente/expediente_revision_screen.dart
//
// Esta pantalla ES "Analizar con IA" desde la reorganización de pestañas
// post-Fase-10 -- antes convivía con AnalisisRepositorioScreen (Fase 9),
// que dejó de usarse desde ProyectoDetailScreen para no tener dos
// operaciones de IA distintas y confusas entre sí. Generar -> revisar ->
// confirmar: la IA solo propone un borrador completo; nada queda como
// versión vigente del proyecto hasta que el usuario lo revisa y pulsa
// "Confirmar expediente". Si algo no convence, "Descartar y repetir" borra
// el borrador sin dejar rastro.
import 'package:flutter/material.dart';

import '../../models/expediente.dart';
import '../../models/proyecto.dart';
import '../../services/expediente_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/expediente/expediente_detalle_widget.dart';

class ExpedienteRevisionScreen extends StatefulWidget {
  const ExpedienteRevisionScreen({required this.proyecto, super.key});

  final Proyecto proyecto;

  @override
  State<ExpedienteRevisionScreen> createState() => _ExpedienteRevisionScreenState();
}

class _ExpedienteRevisionScreenState extends State<ExpedienteRevisionScreen> {
  bool _generando = false;
  bool _confirmando = false;
  String? _error;
  Expediente? _borrador;

  bool get _hayBorrador => _borrador != null;

  Future<void> _generar() async {
    setState(() {
      _generando = true;
      _error = null;
    });
    try {
      final expediente = await ExpedienteService.generar(proyectoId: widget.proyecto.id);
      setState(() => _borrador = expediente);
    } on ExpedienteException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _confirmar() async {
    final borrador = _borrador;
    if (borrador == null) return;
    setState(() {
      _confirmando = true;
      _error = null;
    });
    try {
      await ExpedienteService.confirmar(widget.proyecto.id, borrador.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expediente confirmado')));
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _confirmando = false;
      });
    }
  }

  Future<void> _descartarYRepetir() async {
    final borrador = _borrador;
    if (borrador == null) return;
    setState(() => _confirmando = true);
    try {
      await ExpedienteService.descartarBorrador(widget.proyecto.id, borrador.id);
      if (!mounted) return;
      setState(() {
        _borrador = null;
        _confirmando = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _confirmando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analizar con IA')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _hayBorrador ? _buildRevision(context, _borrador!) : _buildInicial(context),
        ),
      ),
    );
  }

  Widget _buildInicial(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.folder_special_outlined, size: 48, color: colors.accent),
        const SizedBox(height: 16),
        Text(
          'La IA leerá el repositorio de "${widget.proyecto.repoPropietario}/${widget.proyecto.repoNombre}" por etapas '
          '(pantallas, servicios, modelos, backend, configuración, documentación) y construirá un expediente completo: '
          'descripción, pantallas, catálogo de funcionalidades, arquitectura, calidad, seguridad, valoración económica '
          'y potencial de usuarios.',
          style: TextStyle(color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        Text(
          'La valoración económica y el potencial de usuarios son estimaciones razonadas por la IA, nunca datos de '
          'mercado reales. Nada se guarda como versión vigente hasta que confirmes el borrador.',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
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
          onPressed: _generando ? null : _generar,
          child: _generando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Generar expediente'),
        ),
        if (_generando) ...[
          const SizedBox(height: 12),
          Text('Esto puede tardar varios minutos…', textAlign: TextAlign.center, style: TextStyle(color: colors.textMuted)),
        ],
      ],
    );
  }

  Widget _buildRevision(BuildContext context, Expediente borrador) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpedienteDetalleWidget(expediente: borrador),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: colors.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: TextStyle(color: colors.danger))),
            ],
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _confirmando ? null : _confirmar,
          child: _confirmando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirmar expediente'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: _confirmando ? null : _descartarYRepetir, child: const Text('Descartar y repetir')),
      ],
    );
  }
}
