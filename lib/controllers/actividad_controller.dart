// lib/controllers/actividad_controller.dart
//
// Actividad general (Fase 8): junta el historial -- que ya existe por
// proyecto desde la Fase 4 -- de todos los proyectos del usuario en un
// único listado ordenado por fecha. Es solo lectura y no añade ningún
// dato ni servicio nuevo: se suscribe al stream de proyectos ya existente
// (ProyectoService.streamProyectos) y, por cada uno, a su propio stream de
// historial (HistorialService.streamHistorial), combinando y reordenando
// en memoria cada vez que cualquiera de los dos cambia.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/evento_historial.dart';
import '../models/proyecto.dart';
import '../services/historial_service.dart';
import '../services/proyecto_service.dart';

class EventoConProyecto {
  const EventoConProyecto({required this.evento, required this.proyectoId, required this.proyectoNombre});

  final EventoHistorial evento;
  final String proyectoId;
  final String proyectoNombre;
}

class ActividadController extends ChangeNotifier {
  ActividadController({
    Stream<List<Proyecto>>? proyectosStream,
    Stream<List<EventoHistorial>> Function(String proyectoId)? historialStreamFactory,
  }) : _historialStreamFactory = historialStreamFactory ?? HistorialService.streamHistorial {
    _subProyectos = (proyectosStream ?? ProyectoService.streamProyectos()).listen(_onProyectos, onError: _onError);
  }

  final Stream<List<EventoHistorial>> Function(String proyectoId) _historialStreamFactory;
  late final StreamSubscription<List<Proyecto>> _subProyectos;
  final Map<String, StreamSubscription<List<EventoHistorial>>> _subsHistorial = {};
  final Map<String, List<EventoHistorial>> _eventosPorProyecto = {};

  List<Proyecto>? _proyectos;
  Object? _error;

  Object? get error => _error;
  bool get cargando => _proyectos == null && _error == null;

  /// `null` mientras carga; lista (posiblemente vacía) de eventos de todos
  /// los proyectos, más reciente primero.
  List<EventoConProyecto>? get eventos {
    final proyectos = _proyectos;
    if (proyectos == null) return null;
    final todos = <EventoConProyecto>[];
    for (final p in proyectos) {
      final eventosDelProyecto = _eventosPorProyecto[p.id];
      if (eventosDelProyecto == null) continue;
      for (final e in eventosDelProyecto) {
        todos.add(EventoConProyecto(evento: e, proyectoId: p.id, proyectoNombre: p.nombre));
      }
    }
    todos.sort((a, b) => b.evento.fecha.compareTo(a.evento.fecha));
    return todos;
  }

  void _onProyectos(List<Proyecto> proyectos) {
    _proyectos = proyectos;
    _error = null;

    final idsActuales = proyectos.map((p) => p.id).toSet();
    for (final id in _subsHistorial.keys.where((id) => !idsActuales.contains(id)).toList()) {
      unawaited(_subsHistorial.remove(id)?.cancel());
      _eventosPorProyecto.remove(id);
    }
    for (final p in proyectos) {
      _subsHistorial.putIfAbsent(
        p.id,
        () => _historialStreamFactory(p.id).listen((eventos) {
          _eventosPorProyecto[p.id] = eventos;
          notifyListeners();
        }, onError: _onError),
      );
    }
    notifyListeners();
  }

  void _onError(Object error) {
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subProyectos.cancel());
    for (final sub in _subsHistorial.values) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }
}
