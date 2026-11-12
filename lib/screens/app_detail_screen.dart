// lib/screens/app_detail_screen.dart
import 'package:flutter/material.dart';

import '../models/app_project.dart';
import '../models/estado_app.dart';
import '../models/pendiente.dart';

class AppDetailScreen extends StatefulWidget {
  const AppDetailScreen({required this.proyecto, super.key});

  final AppProject proyecto;

  @override
  State<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends State<AppDetailScreen> {
  late AppProject _proyecto = widget.proyecto;
  late final _nombreCtrl = TextEditingController(text: _proyecto.nombre);
  late final _descripcionCtrl = TextEditingController(text: _proyecto.descripcion);
  late final _stackCtrl = TextEditingController(text: _proyecto.stack);
  late final _rutaCtrl = TextEditingController(text: _proyecto.ruta);
  final _nuevoPendienteCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _stackCtrl.dispose();
    _rutaCtrl.dispose();
    _nuevoPendienteCtrl.dispose();
    super.dispose();
  }

  void _actualizar(AppProject Function(AppProject) actualizar) {
    setState(() => _proyecto = actualizar(_proyecto));
  }

  void _agregarPendiente() {
    final texto = _nuevoPendienteCtrl.text.trim();
    if (texto.isEmpty) return;
    _actualizar(
      (p) => p.copyWith(
        pendientes: [...p.pendientes, Pendiente(id: DateTime.now().microsecondsSinceEpoch.toString(), texto: texto)],
      ),
    );
    _nuevoPendienteCtrl.clear();
  }

  void _alternarPendiente(Pendiente pendiente) {
    _actualizar(
      (p) => p.copyWith(
        pendientes: p.pendientes.map((x) => x.id == pendiente.id ? x.copyWith(hecho: !x.hecho) : x).toList(),
      ),
    );
  }

  void _borrarPendiente(Pendiente pendiente) {
    _actualizar((p) => p.copyWith(pendientes: p.pendientes.where((x) => x.id != pendiente.id).toList()));
  }

  void _guardarYSalir() {
    final actualizado = _proyecto.copyWith(
      nombre: _nombreCtrl.text.trim().isEmpty ? _proyecto.nombre : _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text,
      stack: _stackCtrl.text,
      ruta: _rutaCtrl.text,
    );
    Navigator.pop(context, actualizado);
  }

  @override
  Widget build(BuildContext context) {
    final pendientesActivos = _proyecto.pendientes.where((p) => !p.hecho).toList();
    final pendientesHechos = _proyecto.pendientes.where((p) => p.hecho).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _guardarYSalir();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_proyecto.nombre),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _guardarYSalir),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 12),
            TextField(
              controller: _descripcionCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _stackCtrl, decoration: const InputDecoration(labelText: 'Stack')),
            const SizedBox(height: 12),
            TextField(controller: _rutaCtrl, decoration: const InputDecoration(labelText: 'Ruta / repo')),
            const SizedBox(height: 16),
            Text('Estado', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: EstadoApp.values.map((estado) {
                final seleccionado = estado == _proyecto.estado;
                return ChoiceChip(
                  label: Text(estado.etiqueta),
                  avatar: Icon(estado.icono, size: 16, color: seleccionado ? null : estado.color),
                  selected: seleccionado,
                  onSelected: (_) => _actualizar((p) => p.copyWith(estado: estado)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text('Pendientes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nuevoPendienteCtrl,
                    decoration: const InputDecoration(hintText: 'Añadir un pendiente...'),
                    onSubmitted: (_) => _agregarPendiente(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add_circle), onPressed: _agregarPendiente),
              ],
            ),
            ...pendientesActivos.map(
              (p) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: p.hecho,
                onChanged: (_) => _alternarPendiente(p),
                title: Text(p.texto),
                secondary: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _borrarPendiente(p)),
              ),
            ),
            if (pendientesHechos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Hechos', style: Theme.of(context).textTheme.labelMedium),
              ...pendientesHechos.map(
                (p) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: p.hecho,
                  onChanged: (_) => _alternarPendiente(p),
                  title: Text(
                    p.texto,
                    style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey),
                  ),
                  secondary: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _borrarPendiente(p)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
