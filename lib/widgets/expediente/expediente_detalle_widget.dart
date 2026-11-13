// lib/widgets/expediente/expediente_detalle_widget.dart
//
// Renderiza las nueve secciones de un Expediente (Fase 10) en modo lectura.
// Lo usan la pantalla de revisión del borrador, la pestaña "Expediente" del
// detalle de proyecto y el visor de versiones anteriores -- siempre el mismo
// widget, para que lo que se confirma sea exactamente lo que se ve antes de
// confirmar.
import 'package:flutter/material.dart';

import '../../models/expediente.dart';
import '../../theme/design_tokens.dart';
import '../estado_badge.dart';
import '../seccion_header.dart';

class ExpedienteDetalleWidget extends StatelessWidget {
  const ExpedienteDetalleWidget({required this.expediente, super.key});

  final Expediente expediente;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetaAviso(expediente: expediente),
        const SizedBox(height: 12),
        _tarjeta(context, titulo: 'Descripción general', icono: Icons.description_outlined, child: _DescripcionGeneral(d: expediente.descripcionGeneral)),
        _tarjeta(
          context,
          titulo: 'Pantallas (${expediente.pantallas.length})',
          icono: Icons.dashboard_outlined,
          child: _ListaPantallas(pantallas: expediente.pantallas),
        ),
        _tarjeta(
          context,
          titulo: 'Catálogo de funcionalidades (${expediente.catalogoFuncionalidades.length})',
          icono: Icons.checklist_outlined,
          child: _ListaFuncionalidades(funcionalidades: expediente.catalogoFuncionalidades),
        ),
        _tarjeta(context, titulo: 'Arquitectura', icono: Icons.architecture_outlined, child: _Arquitectura(a: expediente.arquitectura)),
        _tarjeta(
          context,
          titulo: 'Calidad del código',
          icono: Icons.verified_outlined,
          child: _SeccionHallazgos(resumen: expediente.calidad.resumen, hallazgos: expediente.calidad.hallazgos),
        ),
        _tarjeta(
          context,
          titulo: 'Seguridad',
          icono: Icons.shield_outlined,
          child: _SeccionHallazgos(resumen: expediente.seguridad.resumen, hallazgos: expediente.seguridad.hallazgos),
        ),
        _tarjeta(
          context,
          titulo: 'Valoración económica',
          icono: Icons.payments_outlined,
          child: _ValoracionEconomica(v: expediente.valoracionEconomica),
        ),
        _tarjeta(
          context,
          titulo: 'Potencial de usuarios',
          icono: Icons.groups_outlined,
          child: _PotencialUsuarios(p: expediente.potencialUsuarios),
        ),
        _tarjeta(
          context,
          titulo: 'Progreso y valor',
          icono: Icons.insights_outlined,
          child: _ProgresoValor(p: expediente.progresoValor),
        ),
      ],
    );
  }

  Widget _tarjeta(BuildContext context, {required String titulo, required IconData icono, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [SeccionHeader(titulo: titulo, icono: icono), const SizedBox(height: 10), child],
          ),
        ),
      ),
    );
  }
}

class _MetaAviso extends StatelessWidget {
  const _MetaAviso({required this.expediente});
  final Expediente expediente;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = expediente.metaGeneracion;
    if (!m.truncado && m.archivosAnalizados == 0) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(m.truncado ? Icons.info_outline : Icons.auto_awesome, size: 14, color: colors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            m.truncado
                ? 'Repositorio grande: se analizaron ${m.archivosAnalizados} archivos de ${m.archivosAnalizados + m.archivosOmitidos} relevantes, en ${m.etapasEjecutadas} etapas.'
                : 'Analizado en ${m.etapasEjecutadas} etapas (${m.archivosAnalizados} archivos).',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _DescripcionGeneral extends StatelessWidget {
  const _DescripcionGeneral({required this.d});
  final SeccionDescripcionGeneral d;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(d.resumen.isEmpty ? '(sin resumen)' : d.resumen),
        if (d.estadoMadurez.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Estado: ${d.estadoMadurez}', style: TextStyle(color: colors.textMuted, fontSize: 12)),
        ],
        if (d.propuestaValor.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Propuesta de valor', style: Theme.of(context).textTheme.labelMedium),
          Text(d.propuestaValor),
        ],
        if (d.publicoObjetivo.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Público objetivo', style: Theme.of(context).textTheme.labelMedium),
          Text(d.publicoObjetivo),
        ],
      ],
    );
  }
}

class _ListaPantallas extends StatelessWidget {
  const _ListaPantallas({required this.pantallas});
  final List<PantallaExpediente> pantallas;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (pantallas.isEmpty) return Text('Ninguna detectada.', style: TextStyle(color: colors.textMuted));
    return Column(
      children: pantallas.map((p) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.nombre, style: Theme.of(context).textTheme.titleSmall),
              if (p.descripcionFuncion.isNotEmpty) Text(p.descripcionFuncion),
              if (p.archivoPrincipal.isNotEmpty)
                Text(p.archivoPrincipal, style: TextStyle(color: colors.textMuted, fontSize: 12, fontFamily: 'monospace')),
              if (p.navegacion.isNotEmpty) Text(p.navegacion, style: TextStyle(color: colors.textMuted, fontSize: 12)),
              if (p.pantallasRelacionadas.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: p.pantallasRelacionadas.map((r) => Chip(label: Text(r), visualDensity: VisualDensity.compact)).toList(),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ListaFuncionalidades extends StatelessWidget {
  const _ListaFuncionalidades({required this.funcionalidades});
  final List<FuncionalidadExpediente> funcionalidades;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (funcionalidades.isEmpty) return Text('Ninguna detectada.', style: TextStyle(color: colors.textMuted));
    return Column(
      children: funcionalidades.map((f) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(f.nombre, style: Theme.of(context).textTheme.titleSmall)),
                  EstadoBadge(icono: f.confianza.icono, etiqueta: f.confianza.etiqueta, color: f.confianza.color, compacto: true),
                ],
              ),
              if (f.descripcion.isNotEmpty) Text(f.descripcion),
              if (f.evidencia.isNotEmpty)
                Text('Evidencia: ${f.evidencia}', style: TextStyle(color: colors.textMuted, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Arquitectura extends StatelessWidget {
  const _Arquitectura({required this.a});
  final SeccionArquitectura a;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(a.resumen.isEmpty ? '(sin resumen)' : a.resumen),
        if (a.patrones.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Patrones', style: Theme.of(context).textTheme.labelMedium),
          Wrap(spacing: 6, runSpacing: 6, children: a.patrones.map((p) => Chip(label: Text(p), visualDensity: VisualDensity.compact)).toList()),
        ],
        if (a.tecnologias.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Tecnologías', style: Theme.of(context).textTheme.labelMedium),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: a.tecnologias.map((t) => Chip(label: Text(t), visualDensity: VisualDensity.compact)).toList(),
          ),
        ],
        if (a.resumen.isEmpty && a.patrones.isEmpty && a.tecnologias.isEmpty)
          Text('Sin datos.', style: TextStyle(color: colors.textMuted)),
      ],
    );
  }
}

class _SeccionHallazgos extends StatelessWidget {
  const _SeccionHallazgos({required this.resumen, required this.hallazgos});
  final String resumen;
  final List<HallazgoExpediente> hallazgos;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (resumen.isNotEmpty) Text(resumen),
        if (hallazgos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Sin hallazgos registrados -- esto no implica que no haya riesgos.', style: TextStyle(color: colors.textMuted)),
          )
        else
          ...hallazgos.map(
            (h) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(h.titulo, style: Theme.of(context).textTheme.titleSmall)),
                      EstadoBadge(icono: h.gravedad.icono, etiqueta: h.gravedad.etiqueta, color: h.gravedad.color, compacto: true),
                    ],
                  ),
                  if (h.descripcion.isNotEmpty) Text(h.descripcion),
                  if (h.evidencia.isNotEmpty) Text('Evidencia: ${h.evidencia}', style: TextStyle(color: colors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _dinero(num v, String moneda) => '${v.toStringAsFixed(0)} $moneda';

class _ValoracionEconomica extends StatelessWidget {
  const _ValoracionEconomica({required this.v});
  final SeccionValoracionEconomica v;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            EstadoBadge(icono: v.nivelConfianza.icono, etiqueta: 'Confianza: ${v.nivelConfianza.etiqueta}', color: v.nivelConfianza.color, compacto: true),
          ],
        ),
        const SizedBox(height: 6),
        _filaEscenario(context, 'Conservador', v.conservador),
        _filaEscenario(context, 'Intermedio', v.intermedio),
        _filaEscenario(context, 'Optimista', v.optimista),
        if (v.supuestos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Supuestos', style: Theme.of(context).textTheme.labelMedium),
          ...v.supuestos.map((s) => Text('• $s')),
        ],
        if (v.limitaciones.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: colors.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(v.limitaciones, style: TextStyle(color: colors.textMuted, fontSize: 12))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _filaEscenario(BuildContext context, String etiqueta, EscenarioEconomico e) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: Theme.of(context).textTheme.titleSmall),
          Text('Desarrollo: ${_dinero(e.costeDesarrolloEstimado, e.moneda)} · Reconstrucción: ${_dinero(e.costeReconstruccionEstimado, e.moneda)} · Producto: ${_dinero(e.valorProductoEstimado, e.moneda)}'),
          if (e.razonamiento.isNotEmpty) Text(e.razonamiento, style: TextStyle(color: colors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PotencialUsuarios extends StatelessWidget {
  const _PotencialUsuarios({required this.p});
  final SeccionPotencialUsuarios p;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            EstadoBadge(icono: p.nivelConfianza.icono, etiqueta: 'Confianza: ${p.nivelConfianza.etiqueta}', color: p.nivelConfianza.color, compacto: true),
          ],
        ),
        if (p.segmentoObjetivo.isNotEmpty) ...[const SizedBox(height: 6), Text(p.segmentoObjetivo)],
        const SizedBox(height: 6),
        _filaEscenario(context, 'Conservador', p.conservador),
        _filaEscenario(context, 'Intermedio', p.intermedio),
        _filaEscenario(context, 'Optimista', p.optimista),
        if (p.supuestos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Supuestos', style: Theme.of(context).textTheme.labelMedium),
          ...p.supuestos.map((s) => Text('• $s')),
        ],
        if (p.limitaciones.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: colors.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text('Estimación especulativa, no una predicción. ${p.limitaciones}', style: TextStyle(color: colors.textMuted, fontSize: 12))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _filaEscenario(BuildContext context, String etiqueta, EscenarioUsuarios e) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$etiqueta: ${e.usuariosEstimados.toStringAsFixed(0)} usuarios', style: Theme.of(context).textTheme.titleSmall),
          if (e.razonamiento.isNotEmpty) Text(e.razonamiento, style: TextStyle(color: colors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProgresoValor extends StatelessWidget {
  const _ProgresoValor({required this.p});
  final SeccionProgresoValor p;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Progreso de desarrollo: ${p.progresoPorcentajeLeido}%', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(p.analisisTexto.isEmpty ? '(sin análisis)' : p.analisisTexto),
        const SizedBox(height: 6),
        Text(
          'El progreso mide preparación técnica; el valor y el potencial se evalúan por separado, nunca multiplicando uno por otro.',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}
