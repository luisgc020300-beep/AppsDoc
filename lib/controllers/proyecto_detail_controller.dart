// lib/controllers/proyecto_detail_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/documento.dart';
import '../models/funcionalidad.dart';
import '../models/idea.dart';
import '../models/proyecto.dart';
import '../models/tarea.dart';
import '../services/documento_service.dart';
import '../services/funcionalidad_service.dart';
import '../services/idea_service.dart';
import '../services/proyecto_service.dart';
import '../services/tarea_service.dart';

/// Combina las cinco fuentes que necesita el detalle de un proyecto
/// (ficha, funcionalidades, documentos, tareas, ideas) en un único
/// ChangeNotifier. Los cinco streams son inyectables para poder testear
/// cada combinación de estados sin tocar Firestore real.
class ProyectoDetailController extends ChangeNotifier {
  ProyectoDetailController({
    required this.proyectoId,
    Stream<Proyecto?>? proyectoStream,
    Stream<List<Funcionalidad>>? funcionalidadesStream,
    Stream<List<Documento>>? documentosStream,
    Stream<List<Tarea>>? tareasStream,
    Stream<List<Idea>>? ideasStream,
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
    _subTareas = (tareasStream ?? TareaService.streamTareas(proyectoId)).listen(
      (t) {
        tareas = t;
        notifyListeners();
      },
      onError: (Object e) {
        error = e;
        notifyListeners();
      },
    );
    _subIdeas = (ideasStream ?? IdeaService.streamIdeas(proyectoId)).listen(
      (i) {
        ideas = i;
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
  late final StreamSubscription<List<Tarea>> _subTareas;
  late final StreamSubscription<List<Idea>> _subIdeas;

  Proyecto? proyecto;
  bool proyectoCargando = true;
  List<Funcionalidad>? funcionalidades;
  List<Documento>? documentos;
  List<Tarea>? tareas;
  List<Idea>? ideas;
  Object? error;

  @override
  void dispose() {
    unawaited(_subProyecto.cancel());
    unawaited(_subFuncionalidades.cancel());
    unawaited(_subDocumentos.cancel());
    unawaited(_subTareas.cancel());
    unawaited(_subIdeas.cancel());
    super.dispose();
  }
}
