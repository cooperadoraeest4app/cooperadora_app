import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/proyecto_repository.dart';
import '../../domain/models/item_proyecto.dart';
import '../../domain/models/proyecto.dart';
import '../providers/proyecto_provider.dart';
import '../../../ingresos/presentation/screens/movimientos_screen.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(double monto) {
  final f = monto == monto.truncateToDouble()
      ? NumberFormat('#,##0', 'es_AR')
      : NumberFormat('#,##0.##', 'es_AR');
  return '\$${f.format(monto)}';
}

String _fmtFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

IconData _iconForTipo(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('evento')) return Icons.celebration_outlined;
  if (n.contains('infraestructura')) return Icons.construction_outlined;
  if (n.contains('viaje')) return Icons.directions_bus_outlined;
  if (n.contains('equipamiento')) return Icons.warehouse_outlined;
  return Icons.category_outlined;
}

// ── Popups de estados ─────────────────────────────────────────────────────────

void _mostrarPopupEstadoProyecto(BuildContext context, String estadoActual) {
  final estados = [
    ('🟡', 'planificado', 'Planificado', AppTheme.amarilloAlerta,
        'El proyecto está definido y aguarda aprobación para comenzar'),
    ('🟢', 'en_curso', 'En curso', AppTheme.verdeIngreso,
        'El proyecto fue aprobado y está actualmente en ejecución'),
    ('✅', 'finalizado', 'Finalizado', AppTheme.verdeTeal,
        'El proyecto fue completado exitosamente'),
    ('❌', 'cancelado', 'Cancelado', AppTheme.textoSecundario,
        'El proyecto fue discontinuado antes de su finalización'),
  ];

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Estados del proyecto'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: estados.map((e) {
          final (icono, clave, nombre, color, desc) = e;
          final esCurrent = clave == estadoActual;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: esCurrent ? AppTheme.celesteFondo : null,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(icono, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: color)),
                      const SizedBox(height: 2),
                      Text(desc,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textoSecundario)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

void _mostrarPopupEstadoItem(BuildContext context, String estadoActual) {
  final estados = [
    ('⚪', 'pendiente', 'Pendiente', AppTheme.amarilloAlerta,
        'El ítem está identificado pero aún no se comenzó a gestionar'),
    ('🔵', 'en_gestion', 'En gestión', AppTheme.azulMedio,
        'Los responsables están cotizando y buscando proveedores'),
    ('🟡', 'presupuestos_aprobados', 'Presupuestos aprobados', AppTheme.verdeTeal,
        'Un presupuesto fue aprobado, listo para comprar'),
    ('🟢', 'comprado', 'Comprado', AppTheme.verdeIngreso,
        'El ítem fue adquirido y el gasto registrado'),
  ];

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Estados del ítem'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: estados.map((e) {
          final (icono, clave, nombre, color, desc) = e;
          final esCurrent = clave == estadoActual;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: esCurrent ? AppTheme.celesteFondo : null,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(icono, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: color)),
                      const SizedBox(height: 2),
                      Text(desc,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textoSecundario)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

// ── ProyectoPublicoDetalleScreen ──────────────────────────────────────────────

class ProyectoPublicoDetalleScreen extends StatelessWidget {
  const ProyectoPublicoDetalleScreen({super.key, required this.proyecto});

  final Proyecto proyecto;

  @override
  Widget build(BuildContext context) {
    final p = context.select<ProyectoProvider, Proyecto>((prov) {
      final all = [...prov.enCurso, ...prov.planificados, ...prov.finalizados];
      try {
        return all.firstWhere((e) => e.id == proyecto.id);
      } catch (_) {
        return proyecto;
      }
    });

    final appBarColor = switch (p.estado) {
      'en_curso' => AppTheme.verdeTeal,
      'planificado' => AppTheme.amarilloAlerta,
      _ => AppTheme.textoSecundario,
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        title: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(proyecto: p),
            const SizedBox(height: 12),
            _PresupuestoCard(proyecto: p),
            const SizedBox(height: 12),
            _FechasCard(proyecto: p),
            const SizedBox(height: 12),
            _ItemsCard(proyectoId: p.id),
            const SizedBox(height: 12),
            _MovimientosCard(proyecto: p),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── _HeaderCard ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.proyecto});

  final Proyecto proyecto;

  @override
  Widget build(BuildContext context) {
    final tipoNombre =
        context.read<ProyectoProvider>().nombreTipo(proyecto.tipoProyectoId);

    final (chipColor, chipLabel) = switch (proyecto.estado) {
      'en_curso' => (AppTheme.verdeIngreso, 'En curso'),
      'planificado' => (AppTheme.amarilloAlerta, 'Planificado'),
      'cancelado' => (AppTheme.textoSecundario, 'Cancelado'),
      _ => (AppTheme.textoSecundario, 'Finalizado'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _mostrarPopupEstadoProyecto(context, proyecto.estado),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withAlpha(30),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  chipLabel,
                  style: TextStyle(
                    color: chipColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(_iconForTipo(tipoNombre), size: 16, color: AppTheme.azulMedio),
                const SizedBox(width: 6),
                Text(
                  tipoNombre,
                  style: const TextStyle(
                    color: AppTheme.azulMedio,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (proyecto.descripcion?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                proyecto.descripcion!,
                style: const TextStyle(color: AppTheme.textoPrincipal),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _PresupuestoCard ──────────────────────────────────────────────────────────

class _PresupuestoCard extends StatefulWidget {
  const _PresupuestoCard({required this.proyecto});
  final Proyecto proyecto;

  @override
  State<_PresupuestoCard> createState() => _PresupuestoCardState();
}

class _PresupuestoCardState extends State<_PresupuestoCard> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  double _gastado = 0.0;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('gastos')
        .where('proyectoId', isEqualTo: widget.proyecto.id)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final total = snap.docs.fold<double>(
        0.0,
        (acc, d) => acc + (d.data()['monto'] as num? ?? 0).toDouble(),
      );
      setState(() => _gastado = total);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.proyecto.presupuestoActual;
    final disponible = total - _gastado;
    final progress = total > 0 ? (_gastado / total).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Presupuesto',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MontoItem(
                    label: 'Total',
                    monto: total,
                    color: AppTheme.textoPrincipal),
                _MontoItem(
                    label: 'Gastado',
                    monto: _gastado,
                    color: AppTheme.rojoGasto),
                _MontoItem(
                    label: 'Disponible',
                    monto: disponible,
                    color: AppTheme.verdeIngreso),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.rojoGasto.withAlpha(25),
                color: AppTheme.rojoGasto,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).toStringAsFixed(1)}% utilizado',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

class _MontoItem extends StatelessWidget {
  const _MontoItem(
      {required this.label, required this.monto, required this.color});

  final String label;
  final double monto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textoSecundario)),
          const SizedBox(height: 4),
          Text(
            _fmt(monto),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _FechasCard ───────────────────────────────────────────────────────────────

class _FechasCard extends StatelessWidget {
  const _FechasCard({required this.proyecto});
  final Proyecto proyecto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fechas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            _FechaRow(label: 'Inicio', fecha: proyecto.fechaInicio),
            if (proyecto.fechaFinEstimada != null)
              _FechaRow(
                  label: 'Fin estimado', fecha: proyecto.fechaFinEstimada!),
            if (proyecto.fechaFinReal != null)
              _FechaRow(
                label: 'Fin real',
                fecha: proyecto.fechaFinReal!,
                color: AppTheme.verdeIngreso,
              ),
          ],
        ),
      ),
    );
  }
}

class _FechaRow extends StatelessWidget {
  const _FechaRow({
    required this.label,
    required this.fecha,
    this.color = AppTheme.textoPrincipal,
  });

  final String label;
  final DateTime fecha;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textoSecundario, fontSize: 13)),
          ),
          Text(
            _fmtFecha(fecha),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ItemsCard (solo lectura) ─────────────────────────────────────────────────

class _ItemsCard extends StatefulWidget {
  const _ItemsCard({required this.proyectoId});
  final String proyectoId;

  @override
  State<_ItemsCard> createState() => _ItemsCardState();
}

class _ItemsCardState extends State<_ItemsCard> {
  final _repo = ProyectoRepository();
  late final Stream<List<ItemProyecto>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repo.obtenerItems(widget.proyectoId);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ítems',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            StreamBuilder<List<ItemProyecto>>(
              stream: _stream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('Sin ítems',
                          style:
                              TextStyle(color: AppTheme.textoSecundario)),
                    ),
                  );
                }
                return Column(
                  children: items.map((item) => _ItemTile(item: item)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final ItemProyecto item;

  @override
  Widget build(BuildContext context) {
    final (estadoColor, estadoLabel) = switch (item.estado) {
      'en_gestion' => (AppTheme.azulMedio, 'En gestión'),
      'presupuestos_aprobados' => (AppTheme.verdeTeal, 'Pres. aprobados'),
      'comprado' => (AppTheme.verdeIngreso, 'Comprado'),
      _ => (AppTheme.amarilloAlerta, 'Pendiente'),
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        item.descripcion,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          children: [
            GestureDetector(
              onTap: () => _mostrarPopupEstadoItem(context, item.estado),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: estadoColor.withAlpha(30),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Text(
                  estadoLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: estadoColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (item.montoEstimado > 0)
              Text(
                _fmt(item.montoEstimado),
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario),
              ),
            if (item.cantidad != null && item.unidad != null)
              Text(
                '${item.cantidad} ${item.unidad}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario),
              ),
          ],
        ),
      ),
    );
  }
}

// ── _MovimientosCard ──────────────────────────────────────────────────────────

class _MovItem {
  final bool esIngreso;
  final double monto;
  final DateTime fecha;
  final String? descripcion;
  final String? comprobante;

  const _MovItem({
    required this.esIngreso,
    required this.monto,
    required this.fecha,
    this.descripcion,
    this.comprobante,
  });
}

class _MovimientosCard extends StatefulWidget {
  const _MovimientosCard({required this.proyecto});
  final Proyecto proyecto;

  @override
  State<_MovimientosCard> createState() => _MovimientosCardState();
}

class _MovimientosCardState extends State<_MovimientosCard> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subI;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subG;
  List<_MovItem> _ingresos = [];
  List<_MovItem> _gastos = [];

  @override
  void initState() {
    super.initState();
    final id = widget.proyecto.id;

    _subI = FirebaseFirestore.instance
        .collection('ingresos')
        .where('proyectoId', isEqualTo: id)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _ingresos = snap.docs.map((d) {
          final data = d.data();
          return _MovItem(
            esIngreso: true,
            monto: (data['monto'] as num? ?? 0).toDouble(),
            fecha: data['fecha'] is Timestamp
                ? (data['fecha'] as Timestamp).toDate()
                : DateTime.now(),
            descripcion: data['descripcion'] as String?,
            comprobante: data['comprobante'] as String?,
          );
        }).toList();
      });
    });

    _subG = FirebaseFirestore.instance
        .collection('gastos')
        .where('proyectoId', isEqualTo: id)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _gastos = snap.docs.map((d) {
          final data = d.data();
          return _MovItem(
            esIngreso: false,
            monto: (data['monto'] as num? ?? 0).toDouble(),
            fecha: data['fecha'] is Timestamp
                ? (data['fecha'] as Timestamp).toDate()
                : DateTime.now(),
            descripcion: data['descripcion'] as String?,
            comprobante: data['comprobante'] as String?,
          );
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _subI?.cancel();
    _subG?.cancel();
    super.dispose();
  }

  String _fmtFechaCorta(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final all = [..._ingresos, ..._gastos]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final top5 = all.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Movimientos',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (top5.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Sin movimientos registrados',
                    style: TextStyle(color: AppTheme.textoSecundario)),
              )
            else
              ...top5.map(_buildMovRow),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.list_alt_outlined, size: 16),
                label: const Text('Ver todos los movimientos'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MovimientosScreen(proyectoId: widget.proyecto.id),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovRow(_MovItem m) {
    final color = m.esIngreso ? AppTheme.verdeIngreso : AppTheme.rojoGasto;
    final signo = m.esIngreso ? '+' : '-';
    final label = m.descripcion?.isNotEmpty == true
        ? m.descripcion!
        : (m.esIngreso ? 'Ingreso' : 'Gasto');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(
            _fmtFechaCorta(m.fecha),
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textoSecundario),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$signo${_fmt(m.monto)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 13,
            ),
          ),
          if (m.comprobante?.isNotEmpty == true) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(m.comprobante!)),
              child: const Icon(Icons.receipt_outlined,
                  size: 16, color: AppTheme.azulMedio),
            ),
          ],
        ],
      ),
    );
  }
}
