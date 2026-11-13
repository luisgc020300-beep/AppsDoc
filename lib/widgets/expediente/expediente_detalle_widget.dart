// lib/widgets/expediente/expediente_detalle_widget.dart
//
// Renderiza las once secciones de un Expediente (Fase 10) en modo lectura.
// Lo usan la pantalla de revisión del borrador y el visor de versiones
// anteriores -- siempre el mismo widget, para que lo que se confirma sea
// exactamente lo que se ve antes de confirmar.
//
// Las tarjetas individuales (DescripcionGeneralSeccion, CatalogoFuncionalidadesSeccion,
// etc.) son públicas a propósito: las 5 pestañas de ProyectoDetailScreen
// (reorganización post-Fase-10) componen solo las que necesitan, reutilizando
// el mismo render que aquí en vez de duplicar lógica.
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
        MetaGeneracionAviso(expediente: expediente),
        const SizedBox(height: 12),
        ExpedienteSeccionCard(
          titulo: 'Descripción general',
          icono: Icons.description_outlined,
          child: DescripcionGeneralSeccion(d: expediente.descripcionGeneral),
        ),
        ExpedienteSeccionCard(
          titulo: 'Pantallas (${expediente.pantallas.length})',
          icono: Icons.dashboard_outlined,
          child: ListaPantallasSeccion(pantallas: expediente.pantallas),
        ),
        ExpedienteSeccionCard(
          titulo: 'Catálogo de funcionalidades (${expediente.catalogoFuncionalidades.length})',
          icono: Icons.checklist_outlined,
          child: CatalogoFuncionalidadesSeccion(funcionalidades: expediente.catalogoFuncionalidades),
        ),
        ExpedienteSeccionCard(
          titulo: 'Posibilidades futuras (${expediente.posibilidadesFuturas.length})',
          icono: Icons.lightbulb_outline,
          child: PosibilidadesFuturasSeccion(posibilidades: expediente.posibilidadesFuturas),
        ),
        ExpedienteSeccionCard(
          titulo: 'Arquitectura',
          icono: Icons.architecture_outlined,
          child: ArquitecturaSeccion(a: expediente.arquitectura),
        ),
        ExpedienteSeccionCard(
          titulo: 'Calidad del código',
          icono: Icons.verified_outlined,
          child: HallazgosSeccion(resumen: expediente.calidad.resumen, hallazgos: expediente.calidad.hallazgos),
        ),
        ExpedienteSeccionCard(
          titulo: 'Seguridad',
          icono: Icons.shield_outlined,
          child: HallazgosSeccion(resumen: expediente.seguridad.resumen, hallazgos: expediente.seguridad.hallazgos),
        ),
        ExpedienteSeccionCard(
          titulo: 'Valoración económica',
          icono: Icons.payments_outlined,
          child: ValoracionEconomicaSeccion(v: expediente.valoracionEconomica),
        ),
        ExpedienteSeccionCard(
          titulo: 'Potencial de usuarios',
          icono: Icons.groups_outlined,
          child: PotencialUsuariosSeccion(p: expediente.potencialUsuarios),
        ),
        ExpedienteSeccionCard(
          titulo: 'Progreso y valor',
          icono: Icons.insights_outlined,
          child: ProgresoValorSeccion(p: expediente.progresoValor),
        ),
      ],
    );
  }
}

/// Envoltorio de tarjeta común a todas las secciones del expediente -- lo
/// usan tanto `ExpedienteDetalleWidget` (las once de golpe) como las 5
/// pestañas de `ProyectoDetailScreen` (un subconjunto cada una).
class ExpedienteSeccionCard extends StatelessWidget {
  const ExpedienteSeccionCard({required this.titulo, required this.icono, required this.child, super.key});

  final String titulo;
  final IconData icono;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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

class MetaGeneracionAviso extends StatelessWidget {
  const MetaGeneracionAviso({required this.expediente, super.key});
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

/// `propuestaValor` se muestra como "Cómo funciona" -- desde la reorganización
/// de pestañas, ese campo ya no pide una propuesta de valor de negocio sino
/// una explicación funcional para un futuro usuario (ver el prompt de
/// `generarExpediente` en el backend).
class DescripcionGeneralSeccion extends StatelessWidget {
  const DescripcionGeneralSeccion({required this.d, this.soloIntroduccion = false, super.key});

  final SeccionDescripcionGeneral d;

  /// true en la pestaña "Funcionalidades": solo resumen + cómo funciona, sin
  /// público objetivo/estado de madurez (esos viven en Documentos/Potencial).
  final bool soloIntroduccion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(d.resumen.isEmpty ? '(sin resumen)' : d.resumen),
        if (!soloIntroduccion && d.estadoMadurez.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Estado: ${d.estadoMadurez}', style: TextStyle(color: colors.textMuted, fontSize: 12)),
        ],
        if (d.propuestaValor.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Cómo funciona', style: Theme.of(context).textTheme.labelMedium),
          Text(d.propuestaValor),
        ],
        if (!soloIntroduccion && d.publicoObjetivo.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Público objetivo', style: Theme.of(context).textTheme.labelMedium),
          Text(d.publicoObjetivo),
        ],
      ],
    );
  }
}

class ListaPantallasSeccion extends StatelessWidget {
  const ListaPantallasSeccion({required this.pantallas, super.key});
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

class CatalogoFuncionalidadesSeccion extends StatelessWidget {
  const CatalogoFuncionalidadesSeccion({required this.funcionalidades, super.key});
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

/// Deliberadamente distinta de CatalogoFuncionalidadesSeccion -- sin
/// confianza/evidencia (es especulación de la IA, no algo verificado en el
/// código) y con un aviso explícito para que nunca se confunda con lo que
/// la app ya hace de verdad.
class PosibilidadesFuturasSeccion extends StatelessWidget {
  const PosibilidadesFuturasSeccion({required this.posibilidades, super.key});
  final List<PosibilidadFutura> posibilidades;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (posibilidades.isEmpty) {
      return Text('Ninguna sugerida todavía.', style: TextStyle(color: colors.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 14, color: colors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Ideas de la IA sobre huecos o extensiones posibles -- todavía NO implementadas.',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...posibilidades.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre, style: Theme.of(context).textTheme.titleSmall),
                if (p.descripcion.isNotEmpty) Text(p.descripcion),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ArquitecturaSeccion extends StatelessWidget {
  const ArquitecturaSeccion({required this.a, super.key});
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

class HallazgosSeccion extends StatelessWidget {
  const HallazgosSeccion({required this.resumen, required this.hallazgos, super.key});
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

class ValoracionEconomicaSeccion extends StatelessWidget {
  const ValoracionEconomicaSeccion({required this.v, super.key});
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

class PotencialUsuariosSeccion extends StatelessWidget {
  const PotencialUsuariosSeccion({required this.p, super.key});
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

class ProgresoValorSeccion extends StatelessWidget {
  const ProgresoValorSeccion({required this.p, super.key});
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
