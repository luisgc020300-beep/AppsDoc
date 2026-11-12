// lib/controllers/proyecto_detail_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/documento.dart';
import '../models/funcionalidad.dart';
import '../models/proyecto.dart';
import '../services/documento_service.dart';
import '../services/funcionalidad_service.dart';
import '../services/proyecto_service.dart';

/// Combina las tres fuentes que necesita el detalle de un proyecto
/// (ficha, funcionalidades, documentos) en un único ChangeNotifier. Los
/// tres streams son inyectables para poder testear cada combinación de
/// estados sin tocar Firestore real.
class ProyectoDetailController extends ChangeNotifier {
  ProyectoDetailController({
    required this.proyectoId,
    Stream<Proyecto?>? proyectoStream,
    Stream<List<Funcionalidad>>? funcionalidadesStream,
    Stream<List<Documento>>? documentosStream,
  }) {
    _subProyecto = (proyectoStream ?? ProyectoService.streamProyecto(proyectoId)).listen(
      (p) {
        proyecto = p;
        proyectoCargando = false;
        notifyListeners();
      },
      onError: (Object e) {
        error = e;
        proyectoCargando = false;
        notifyListeners();
      },
    );
    _subFuncionalidades = (funcionalidadesStream ?? FuncionalidadService.streamFuncionalidades(proyectoId)).listen(
      (f) {
        funcionalidades = f;
        notifyListeners();
      },
      onError: (Object e) {
        error = e;
        notifyListeners();
      },
    );
    _subDocumentos = (documentosStream ?? DocumentoService.streamDocumentos(proyectoId)).listen(
      (d) {
        documentos = d;
        notifyListeners();
      },
      onError: (Object e) {
        error = e;
        notifyListeners();
      },
    );
  }

  final String proyectoId;
  late final StreamSubscription<Proyecto?> _subProyecto;
  late final StreamSubscription<List<Funcionalidad>> _subFuncionalidades;
  late final StreamSubscription<List<Documento>> _subDocumentos;

  Proyecto? proyecto;
  bool proyectoCargando = true;
  List<Funcionalidad>? funcionalidades;
  List<Documento>? documentos;
  Object? error;

  @override
  void dispose() {
    unawaited(_subProyecto.cancel());
    unawaited(_subFuncionalidades.cancel());
    unawaited(_subDocumentos.cancel());
    super.dispose();
  }
}
