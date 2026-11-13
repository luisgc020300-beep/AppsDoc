// lib/screens/expediente/galeria_capturas_screen.dart
//
// Galería de capturas manuales (Fase 10) -- subir desde el dispositivo,
// agrupadas por pantalla detectada en el expediente actual, ver a pantalla
// completa y eliminar. No hay captura automática todavía (ver
// OrigenCaptura.automatica, preparado pero sin infraestructura detrás).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/captura.dart';
import '../../models/expediente.dart';
import '../../services/captura_service.dart';
import '../../theme/design_tokens.dart';

class GaleriaCapturasScreen extends StatefulWidget {
  const GaleriaCapturasScreen({required this.proyectoId, required this.pantallas, super.key});

  final String proyectoId;

  /// Pantallas del expediente CONFIRMADO actual -- de aquí sale la lista de
  /// destinos posibles al subir una captura nueva. Si una pantalla todavía
  /// no tiene claveEstable (no debería pasar tras ExpedienteService.generar,
  /// pero por si acaso) no aparece como destino.
  final List<PantallaExpediente> pantallas;

  @override
  State<GaleriaCapturasScreen> createState() => _GaleriaCapturasScreenState();
}

class _GaleriaCapturasScreenState extends State<GaleriaCapturasScreen> {
  String? _subiendoAPantalla;
  String? _error;

  List<PantallaExpediente> get _pantallasConClave => widget.pantallas.where((p) => p.claveEstable.isNotEmpty).toList();

  String _nombrePantalla(String claveEstable) {
    for (final p in _pantallasConClave) {
      if (p.claveEstable == claveEstable) return p.nombre;
    }
    return '(pantalla eliminada del expediente)';
  }

  Future<void> _subir() async {
    final pantallas = _pantallasConClave;
    if (pantallas.isEmpty) {
      setState(() => _error = 'El expediente actual no tiene pantallas detectadas a las que asociar una captura.');
      return;
    }
    final claveElegida = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('¿A qué pantalla pertenece?'),
        children: pantallas
            .map((p) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, p.claveEstable), child: Text(p.nombre)))
            .toList(),
      ),
    );
    if (claveElegida == null || !mounted) return;

    final archivo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (archivo == null || !mounted) return;

    setState(() {
      _subiendoAPantalla = claveElegida;
      _error = null;
    });
    try {
      final Uint8List bytes = await archivo.readAsBytes();
      final extension = archivo.name.contains('.') ? archivo.name.split('.').last.toLowerCase() : 'jpg';
      await CapturaService.subir(proyectoId: widget.proyectoId, pantallaClave: claveElegida, bytes: bytes, extension: extension);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo subir la captura: $e');
    } finally {
      if (mounted) setState(() => _subiendoAPantalla = null);
    }
  }

  Future<void> _eliminar(Captura captura) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar esta captura?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;
    await CapturaService.eliminar(widget.proyectoId, captura.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Galería de capturas')),
      floatingActionButton: FloatingActionButton(
        onPressed: _subiendoAPantalla != null ? null : _subir,
        tooltip: 'Añadir captura',
        child: _subiendoAPantalla != null
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_a_photo_outlined),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Captura>>(
          stream: CapturaService.streamCapturas(widget.proyectoId),
          builder: (context, snapshot) {
            final capturas = snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Row(
                    children: [
                      Icon(Icons.error_outline, size: 18, color: colors.danger),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: TextStyle(color: colors.danger))),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (capturas == null)
                  const Center(child: CircularProgressIndicator())
                else if (capturas.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'Todavía no hay ninguna captura. Súbelas con el botón de abajo.',
                        style: TextStyle(color: colors.textMuted),
                      ),
                    ),
                  )
                else
                  ..._agrupadasPorPantalla(capturas).entries.map(
                    (entrada) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nombrePantalla(entrada.key), style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: entrada.value.length,
                            itemBuilder: (context, i) => _Miniatura(
                              captura: entrada.value[i],
                              onEliminar: () => _eliminar(entrada.value[i]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Map<String, List<Captura>> _agrupadasPorPantalla(List<Captura> capturas) {
    final mapa = <String, List<Captura>>{};
    for (final c in capturas) {
      mapa.putIfAbsent(c.pantallaClave, () => []).add(c);
    }
    return mapa;
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.captura, required this.onEliminar});

  final Captura captura;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _VisorCapturaScreen(captura: captura, onEliminar: onEliminar))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<String>(
          future: CapturaService.obtenerUrl(captura.storagePath),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(color: context.colors.surfaceMuted, child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            return Image.network(snapshot.data!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined));
          },
        ),
      ),
    );
  }
}

class _VisorCapturaScreen extends StatelessWidget {
  const _VisorCapturaScreen({required this.captura, required this.onEliminar});

  final Captura captura;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Eliminar',
            onPressed: () {
              Navigator.pop(context);
              onEliminar();
            },
          ),
        ],
      ),
      body: Center(
        child: FutureBuilder<String>(
          future: CapturaService.obtenerUrl(captura.storagePath),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            return InteractiveViewer(child: Image.network(snapshot.data!));
          },
        ),
      ),
    );
  }
}
