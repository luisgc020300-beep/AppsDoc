// lib/controllers/proyectos_list_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/proyecto.dart';
import '../services/proyecto_service.dart';

/// ChangeNotifier puro (mismo criterio que RiskRunner -- sin Provider ni
/// Riverpod) que traduce el stream de [ProyectoService.streamProyectos] en
/// tres estados posibles para la UI: cargando, error, o la lista (que
/// puede estar vacía). [proyectosStream] es inyectable para poder testear
/// cada estado con un stream falso, sin tocar Firestore real.
class ProyectosListController extends ChangeNotifier {
  ProyectosListController({Stream<List<Proyecto>>? proyectosStream}) {
    _sub = (proyectosStream ?? ProyectoService.streamProyectos()).listen(_onData, onError: _onError);
  }

  late final StreamSubscription<List<Proyecto>> _sub;

  List<Proyecto>? _proyectos;
  Object? _error;

  List<Proyecto>? get proyectos => _proyectos;
  Object? get error => _error;
  bool get cargando => _proyectos == null && _error == null;

  void _onData(List<Proyecto> proyectos) {
    _proyectos = proyectos;
    _error = null;
    notifyListeners();
  }

  void _onError(Object error) {
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
