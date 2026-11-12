// lib/screens/analisis/analisis_repositorio_screen.dart
//
// Analizar -> revisar -> confirmar, igual criterio que
// PegarAuditoriaScreen (Fase 7): la IA solo propone (lee el repositorio
// completo y audita su código), nada se guarda hasta que el usuario
// revisa la propuesta y pulsa "Guardar selección". Puede desmarcar
// cualquier documento, funcionalidad, hallazgo, tarea o idea, y puede
// cambiar el estado sugerido de cada funcionalidad antes de guardar --
// el progreso nunca se concede solo porque la IA haya visto código
// relacionado (ver reglas del backend en functions/index.js).
import 'package:flutter/material.dart';

import '../../models/estado_funcionalidad.dart';
import '../../models/hallazgo.dart';
import '../../models/origen_auditoria.dart';
import '../../models/proyecto.dart';
import '../../models/propuesta_analisis_repositorio.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/auditoria_service.dart';
import '../../services/documento_service.dart';
import '../../services/funcionalidad_service.dart';
import '../../services/idea_service.dart';
import '../../services/tarea_service.dart';
import '../../theme/design_tokens.dart';

class AnalisisRepositorioScreen extends StatefulWidget {
  const AnalisisRepositorioScreen({required this.proyecto, super.key});

  final Proyecto proyecto;

  @override
  State<AnalisisRepositorioScreen> createState() => _AnalisisRepositorioScreenState();
}

class _AnalisisRepositorioScreenState extends State<AnalisisRepositorioScreen> {
  bool _analizando = false;
  bool _guardando = false;
  String? _error;
  PropuestaAnalisisRepositorio? _propuesta;

  late List<bool> _documentosSeleccionados;
  late List<bool> _funcionalidadesSeleccionadas;
  late List<EstadoFuncionalidad> _estadosElegidos;
  late List<bool> _hallazgosSeleccionados;
  late List<bool> _tareasSeleccionadas;
  late List<bool> _ideasSeleccionadas;

  bool get _hayPropuesta => _propuesta != null;

  Future<void> _analizar() async {
    setState(() {
      _analizando = true;
      _error = null;
    });
    try {
      final propuesta = await AiAssistantService.analizarRepositorio(proyectoId: widget.proyecto.id);
      setState(() {
        _propuesta = propuesta;
        _documentosSeleccionados = List.filled(propuesta.documentos.length, true);
        _funcionalidadesSeleccionadas = List.filled(propuesta.funcionalidades.length, true);
        _estadosElegidos = propuesta.funcionalidades.map((f) => f.estadoSugerido).toList();
        _hallazgosSeleccionados = List.filled(propuesta.hallazgos.length, true);
        _tareasSeleccionadas = List.filled(propuesta.tareas.length, true);
        _ideasSeleccionadas = List.filled(propuesta.ideas.length, true);
      });
    } on AiAssistantException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      setState(() => _analizando = false);
    }
  }

  void _repetirAnalisis() {
    setState(() {
      _propuesta = null;
      _error = null;
    });
  }

  String _resumenCompleto(PropuestaAnalisisRepositorio p) {
    final buffer = StringBuffer()..writeln(p.resumen);
    if (p.arquitecturaDetectada.isNotEmpty) buffer.writeln('\nArquitectura: ${p.arquitecturaDetectada}');
    if (p.tecnologias.isNotEmpty) buffer.writeln('Tecnologías: ${p.tecnologias.join(', ')}');
    if (p.commitAnalizado != null) buffer.writeln('Commit analizado: ${p.commitAnalizado} (rama ${p.rama ?? '?'})');
    if (p.truncado) {
      buffer.writeln(
        'Nota: el repositorio es grande -- se analizó un subconjunto priorizado '
        '(${p.archivosAnalizados} archivos leídos, ${p.archivosOmitidos} omitidos).',
      );
    }
    return buffer.toString().trim();
  }

  Future<void> _guardarSeleccion() async {
    final propuesta = _propuesta;
    if (propuesta == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final hallazgos = <Hallazgo>[
        for (var i = 0; i < propuesta.hallazgos.length; i++)
          if (_hallazgosSeleccionados[i])
            Hallazgo(
              id: '${DateTime.now().microsecondsSinceEpoch}-$i',
              titulo: propuesta.hallazgos[i].titulo,
              descripcion: propuesta.hallazgos[i].descripcion,
              gravedad: propuesta.hallazgos[i].gravedad,
            ),
      ];

      await AuditoriaService.crear(
        proyectoId: widget.proyecto.id,
        fecha: DateTime.now(),
        origen: OrigenAuditoria.analisisRepositorio,
        resumen: _resumenCompleto(propuesta),
        hallazgos: hallazgos,
      );

      for (var i = 0; i < propuesta.documentos.length; i++) {
        if (!_documentosSeleccionados[i]) continue;
        await DocumentoService.crear(
          proyectoId: widget.proyecto.id,
          titulo: propuesta.documentos[i].titulo,
          categoria: propuesta.documentos[i].categoria,
          contenido: propuesta.documentos[i].contenido,
        );
      }

      for (var i = 0; i < propuesta.funcionalidades.length; i++) {
        if (!_funcionalidadesSeleccionadas[i]) continue;
        final f = propuesta.funcionalidades[i];
        await FuncionalidadService.crear(
          proyectoId: widget.proyecto.id,
          nombre: f.nombre,
          descripcion: f.descripcion,
          estado: _estadosElegidos[i],
          notas: f.evidencia.isEmpty ? '' : 'Detectado automáticamente. Evidencia: ${f.evidencia}',
        );
      }

      for (var i = 0; i < propuesta.tareas.length; i++) {
        if (!_tareasSeleccionadas[i]) continue;
        await TareaService.crear(proyectoId: widget.proyecto.id, titulo: propuesta.tareas[i].titulo, descripcion: propuesta.tareas[i].descripcion);
      }

      for (var i = 0; i < propuesta.ideas.length; i++) {
        if (!_ideasSeleccionadas[i]) continue;
        await IdeaService.crear(proyectoId: widget.proyecto.id, titulo: propuesta.ideas[i].titulo, descripcion: propuesta.ideas[i].descripcion);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Análisis guardado')));
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _guardando = false;
      });
    }
  }

  void _verContenido(String titulo, String contenido) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Text(contenido.isEmpty ? '(sin contenido)' : contenido)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analizar repositorio')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _hayPropuesta ? _buildRevision(context, _propuesta!) : _buildInicial(context),
        ),
      ),
    );
  }

  Widget _buildInicial(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.travel_explore, size: 48, color: colors.accent),
        const SizedBox(height: 16),
        Text(
          'La IA leerá el código de "${widget.proyecto.repoPropietario}/${widget.proyecto.repoNombre}" (solo lectura) '
          'y propondrá documentación, funcionalidades detectadas, hallazgos de auditoría, tareas e ideas. '
          'Nada se guarda hasta que revises la propuesta y confirmes qué quieres conservar.',
          style: TextStyle(color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        Text(
          'En repositorios grandes, el análisis se hace sobre un subconjunto priorizado de archivos, no sobre todo el código.',
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
          onPressed: _analizando ? null : _analizar,
          child: _analizando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Analizar repositorio con IA'),
        ),
        if (_analizando) ...[
          const SizedBox(height: 12),
          Text('Esto puede tardar hasta un minuto…', textAlign: TextAlign.center, style: TextStyle(color: colors.textMuted)),
        ],
      ],
    );
  }

  Widget _buildRevision(BuildContext context, PropuestaAnalisisRepositorio p) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.resumen, style: Theme.of(context).textTheme.bodyMedium),
                if (p.arquitecturaDetectada.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Arquitectura', style: Theme.of(context).textTheme.titleSmall),
                  Text(p.arquitecturaDetectada, style: TextStyle(color: colors.textMuted)),
                ],
                if (p.tecnologias.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: p.tecnologias.map((t) => Chip(label: Text(t))).toList(),
                  ),
                ],
                if (p.truncado) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: colors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Repositorio grande: se analizaron ${p.archivosAnalizados} archivos de '
                          '${p.archivosAnalizados + p.archivosOmitidos} relevantes.',
                          style: TextStyle(color: colors.warning, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Documentos propuestos (${p.documentos.length})', style: Theme.of(context).textTheme.titleSmall),
        if (p.documentos.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Ninguno.', style: TextStyle(color: colors.textMuted)))
        else
          ...List.generate(p.documentos.length, (i) {
            final d = p.documentos[i];
            return CheckboxListTile(
              value: _documentosSeleccionados[i],
              onChanged: (v) => setState(() => _documentosSeleccionados[i] = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(d.titulo),
              subtitle: Text(d.categoria.etiqueta, style: TextStyle(color: d.categoria.color)),
              secondary: IconButton(
                icon: const Icon(Icons.visibility_outlined),
                tooltip: 'Ver contenido',
                onPressed: () => _verContenido(d.titulo, d.contenido),
              ),
            );
          }),
        const SizedBox(height: 12),
        Text('Funcionalidades detectadas (${p.funcionalidades.length})', style: Theme.of(context).textTheme.titleSmall),
        if (p.funcionalidades.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Ninguna.', style: TextStyle(color: colors.textMuted)))
        else
          ...List.generate(p.funcionalidades.length, (i) {
            final f = p.funcionalidades[i];
            return Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: _funcionalidadesSeleccionadas[i],
                      onChanged: (v) => setState(() => _funcionalidadesSeleccionadas[i] = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(f.nombre),
                      subtitle: Text(
                        'Confianza: ${f.confianza.etiqueta}${f.evidencia.isEmpty ? '' : ' · ${f.evidencia}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Text('Estado a guardar: ', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                          DropdownButton<EstadoFuncionalidad>(
                            value: _estadosElegidos[i],
                            isDense: true,
                            items: EstadoFuncionalidad.values
                                .map((e) => DropdownMenuItem(value: e, child: Text(e.etiqueta)))
                                .toList(),
                            onChanged: (nuevo) => setState(() => _estadosElegidos[i] = nuevo ?? _estadosElegidos[i]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        Text('Hallazgos (${p.hallazgos.length})', style: Theme.of(context).textTheme.titleSmall),
        if (p.hallazgos.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Ninguno.', style: TextStyle(color: colors.textMuted)))
        else
          ...List.generate(p.hallazgos.length, (i) {
            final h = p.hallazgos[i];
            return CheckboxListTile(
              value: _hallazgosSeleccionados[i],
              onChanged: (v) => setState(() => _hallazgosSeleccionados[i] = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(h.titulo),
              subtitle: Text(
                '${h.gravedad.etiqueta}${h.descripcion.isEmpty ? '' : ' · ${h.descripcion}'}',
                style: TextStyle(color: h.gravedad.color),
              ),
            );
          }),
        const SizedBox(height: 12),
        Text('Tareas propuestas (${p.tareas.length})', style: Theme.of(context).textTheme.titleSmall),
        if (p.tareas.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Ninguna.', style: TextStyle(color: colors.textMuted)))
        else
          ...List.generate(p.tareas.length, (i) {
            final t = p.tareas[i];
            return CheckboxListTile(
              value: _tareasSeleccionadas[i],
              onChanged: (v) => setState(() => _tareasSeleccionadas[i] = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(t.titulo),
              subtitle: t.descripcion.isNotEmpty ? Text(t.descripcion) : null,
            );
          }),
        const SizedBox(height: 12),
        Text('Ideas propuestas (${p.ideas.length})', style: Theme.of(context).textTheme.titleSmall),
        if (p.ideas.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Ninguna.', style: TextStyle(color: colors.textMuted)))
        else
          ...List.generate(p.ideas.length, (i) {
            final idea = p.ideas[i];
            return CheckboxListTile(
              value: _ideasSeleccionadas[i],
              onChanged: (v) => setState(() => _ideasSeleccionadas[i] = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(idea.titulo),
              subtitle: idea.descripcion.isNotEmpty ? Text(idea.descripcion) : null,
            );
          }),
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
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _guardando ? null : _guardarSeleccion,
          child: _guardando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Guardar selección'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: _guardando ? null : _repetirAnalisis, child: const Text('Repetir el análisis')),
      ],
    );
  }
}
