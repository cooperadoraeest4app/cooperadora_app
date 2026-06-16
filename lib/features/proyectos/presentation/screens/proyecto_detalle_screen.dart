import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../admin/presentation/providers/usuarios_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ingresos/presentation/screens/movimientos_screen.dart';
import '../../data/repositories/proyecto_repository.dart';
import '../../domain/models/item_proyecto.dart';
import '../../domain/models/proyecto.dart';
import '../providers/proyecto_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(double monto) {
  final f = monto == monto.truncateToDouble()
      ? NumberFormat('#,##0', 'es_AR')
      : NumberFormat('#,##0.##', 'es_AR');
  return '\$${f.format(monto)}';
}

String _fmtFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _formatearMonto(double v) {
  if (v <= 0) return '';
  if (v == v.truncateToDouble()) return NumberFormat('#,##0', 'es_AR').format(v);
  return NumberFormat('#,##0.##', 'es_AR').format(v);
}

double _parseMonto(String s) {
  final clean = s.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(clean) ?? 0;
}

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
            onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
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
            onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
      ],
    ),
  );
}

// ── ProyectoDetalleScreen ─────────────────────────────────────────────────────

class ProyectoDetalleScreen extends StatefulWidget {
  const ProyectoDetalleScreen({super.key, required this.proyecto});

  final Proyecto proyecto;

  @override
  State<ProyectoDetalleScreen> createState() => _ProyectoDetalleScreenState();
}

class _ProyectoDetalleScreenState extends State<ProyectoDetalleScreen> {
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _presupuestoCtrl = TextEditingController();

  late String _tipoProyectoId;
  late String _estado;
  late DateTime _fechaInicio;
  DateTime? _fechaFinEstimada;
  late bool _publico;
  late List<String> _responsables;

  bool _hayCambios = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarDesde(widget.proyecto);
    _nombreCtrl.addListener(_marcarCambios);
    _descripcionCtrl.addListener(_marcarCambios);
    _presupuestoCtrl.addListener(_marcarCambios);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _presupuestoCtrl.dispose();
    super.dispose();
  }

  void _cargarDesde(Proyecto p) {
    _nombreCtrl.text = p.nombre;
    _descripcionCtrl.text = p.descripcion ?? '';
    _presupuestoCtrl.text = _formatearMonto(p.presupuestoActual);
    _tipoProyectoId = p.tipoProyectoId;
    _estado = p.estado;
    _fechaInicio = p.fechaInicio;
    _fechaFinEstimada = p.fechaFinEstimada;
    _publico = p.publico;
    _responsables = List.from(p.responsables);
    _hayCambios = false;
  }

  void _marcarCambios() {
    if (!_hayCambios) setState(() => _hayCambios = true);
  }

  void _setEstado(String v) => setState(() {
        _estado = v;
        _hayCambios = true;
      });

  void _setTipo(String v) => setState(() {
        _tipoProyectoId = v;
        _hayCambios = true;
      });

  void _setPublico(bool v) => setState(() {
        _publico = v;
        _hayCambios = true;
      });

  void _setFechaInicio(DateTime v) => setState(() {
        _fechaInicio = v;
        _hayCambios = true;
      });

  void _setFechaFinEstimada(DateTime? v) => setState(() {
        _fechaFinEstimada = v;
        _hayCambios = true;
      });

  void _setResponsables(List<String> v) => setState(() {
        _responsables = v;
        _hayCambios = true;
      });

  Future<void> _seleccionarFecha(
      BuildContext context, DateTime inicial, void Function(DateTime) onPick) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPick(picked);
  }

  Future<void> _guardar(Proyecto p) async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _guardando = true);
    try {
      final descripcion = _descripcionCtrl.text.trim();
      final updated = p.copyWith(
        nombre: nombre,
        descripcion: descripcion.isEmpty ? null : descripcion,
        clearDescripcion: descripcion.isEmpty,
        tipoProyectoId: _tipoProyectoId,
        presupuestoActual: _parseMonto(_presupuestoCtrl.text),
        estado: _estado,
        fechaInicio: _fechaInicio,
        fechaFinEstimada: _fechaFinEstimada,
        clearFechaFinEstimada: _fechaFinEstimada == null,
        publico: _publico,
        responsables: _responsables,
      );
      await context.read<ProyectoProvider>().actualizar(updated);
      if (mounted) setState(() => _hayCambios = false);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.select<ProyectoProvider, Proyecto>((prov) {
      final all = [...prov.enCurso, ...prov.planificados, ...prov.finalizados];
      try {
        return all.firstWhere((e) => e.id == widget.proyecto.id);
      } catch (_) {
        return widget.proyecto;
      }
    });

    final auth = context.watch<AuthProvider>();
    final puedeEditar = auth.esAdmin || auth.esEditor;

    final estadoLabel = switch (p.estado) {
      'en_curso' => 'En curso',
      'planificado' => 'Planificado',
      'finalizado' => 'Finalizado',
      'cancelado' => 'Cancelado',
      _ => p.estado,
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
        title: Text(
          'Proyectos · $estadoLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [AccionAuthWidget()],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoCard(
                    proyecto: p,
                    puedeEditar: puedeEditar,
                    nombreCtrl: _nombreCtrl,
                    descripcionCtrl: _descripcionCtrl,
                    tipoProyectoId: _tipoProyectoId,
                    estado: _estado,
                    publico: _publico,
                    onTipoChanged: _setTipo,
                    onEstadoChanged: _setEstado,
                    onPublicoChanged: _setPublico,
                  ),
                  const SizedBox(height: 12),
                  _PresupuestoCard(
                    proyecto: p,
                    puedeEditar: puedeEditar,
                    presupuestoCtrl: _presupuestoCtrl,
                  ),
                  const SizedBox(height: 12),
                  _FechasCard(
                    proyecto: p,
                    puedeEditar: puedeEditar,
                    fechaInicio: _fechaInicio,
                    fechaFinEstimada: _fechaFinEstimada,
                    responsables: _responsables,
                    onFechaInicioTap: () => _seleccionarFecha(
                        context, _fechaInicio, _setFechaInicio),
                    onFechaFinTap: () => _seleccionarFecha(
                      context,
                      _fechaFinEstimada ?? DateTime.now(),
                      _setFechaFinEstimada,
                    ),
                    onFechaFinClear: () => _setFechaFinEstimada(null),
                    onResponsablesChanged: _setResponsables,
                  ),
                  const SizedBox(height: 12),
                  _ItemsCard(proyectoId: p.id),
                  const SizedBox(height: 12),
                  _MovimientosCard(proyecto: p),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (puedeEditar && _hayCambios)
            _BarraGuardar(
              guardando: _guardando,
              onGuardar: () => _guardar(p),
            ),
        ],
      ),
    );
  }
}

// ── _BarraGuardar ─────────────────────────────────────────────────────────────

class _BarraGuardar extends StatelessWidget {
  const _BarraGuardar({required this.guardando, required this.onGuardar});

  final bool guardando;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.celesteFondo, width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.verdeTeal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
          ),
          onPressed: guardando ? null : onGuardar,
          icon: guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 18),
          label:
              Text(guardando ? 'Guardando...' : 'Guardar cambios',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ── _InfoCard ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.proyecto,
    required this.puedeEditar,
    required this.nombreCtrl,
    required this.descripcionCtrl,
    required this.tipoProyectoId,
    required this.estado,
    required this.publico,
    required this.onTipoChanged,
    required this.onEstadoChanged,
    required this.onPublicoChanged,
  });

  final Proyecto proyecto;
  final bool puedeEditar;
  final TextEditingController nombreCtrl;
  final TextEditingController descripcionCtrl;
  final String tipoProyectoId;
  final String estado;
  final bool publico;
  final void Function(String) onTipoChanged;
  final void Function(String) onEstadoChanged;
  final void Function(bool) onPublicoChanged;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProyectoProvider>();
    final tipos = prov.tipos;

    if (!puedeEditar) {
      return _InfoCardReadOnly(proyecto: proyecto, prov: prov);
    }

    // Guard: tipoProyectoId must exist in loaded tipos
    final tipoValido =
        tipos.isEmpty || tipos.any((t) => t.id == tipoProyectoId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descripcionCtrl,
              decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)'),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('tipo-${tipos.length}-$tipoProyectoId'),
              initialValue: tipoValido && tipos.isNotEmpty ? tipoProyectoId : null,
              decoration: const InputDecoration(labelText: 'Tipo de proyecto'),
              items: tipos
                  .map((t) => DropdownMenuItem(
                        value: t.id,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(_iconForTipo(t.nombre),
                              size: 18, color: AppTheme.azulMedio),
                          title: Text(t.nombre,
                              style: const TextStyle(fontSize: 14)),
                        ),
                      ))
                  .toList(),
              selectedItemBuilder: (_) => tipos
                  .map((t) => Text(t.nombre,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis))
                  .toList(),
              onChanged: (v) {
                if (v != null) onTipoChanged(v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('estado-$estado'),
              initialValue: estado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(
                    value: 'planificado',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Text('🟡', style: TextStyle(fontSize: 16)),
                      title: Text('Planificado', style: TextStyle(fontSize: 14)),
                    )),
                DropdownMenuItem(
                    value: 'en_curso',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Text('🟢', style: TextStyle(fontSize: 16)),
                      title: Text('En curso', style: TextStyle(fontSize: 14)),
                    )),
                DropdownMenuItem(
                    value: 'finalizado',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Text('✅', style: TextStyle(fontSize: 16)),
                      title: Text('Finalizado', style: TextStyle(fontSize: 14)),
                    )),
                DropdownMenuItem(
                    value: 'cancelado',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Text('❌', style: TextStyle(fontSize: 16)),
                      title: Text('Cancelado', style: TextStyle(fontSize: 14)),
                    )),
              ],
              selectedItemBuilder: (_) => const [
                Text('Planificado', style: TextStyle(fontSize: 14)),
                Text('En curso', style: TextStyle(fontSize: 14)),
                Text('Finalizado', style: TextStyle(fontSize: 14)),
                Text('Cancelado', style: TextStyle(fontSize: 14)),
              ],
              onChanged: (v) {
                if (v != null) onEstadoChanged(v);
              },
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible al público'),
              value: publico,
              activeThumbColor: AppTheme.verdeTeal,
              onChanged: onPublicoChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _InfoCardReadOnly ─────────────────────────────────────────────────────────

class _InfoCardReadOnly extends StatelessWidget {
  const _InfoCardReadOnly({required this.proyecto, required this.prov});

  final Proyecto proyecto;
  final ProyectoProvider prov;

  @override
  Widget build(BuildContext context) {
    final tipoNombre = prov.nombreTipo(proyecto.tipoProyectoId);
    final (chipColor, chipLabel) = switch (proyecto.estado) {
      'en_curso' => (AppTheme.verdeIngreso, 'En curso'),
      'planificado' => (AppTheme.amarilloAlerta, 'Planificado'),
      'cancelado' => (AppTheme.textoSecundario, 'Cancelado'),
      _ => (AppTheme.verdeTeal, 'Finalizado'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      _mostrarPopupEstadoProyecto(context, proyecto.estado),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor.withAlpha(30),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Text(
                      chipLabel,
                      style: TextStyle(
                          color: chipColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
                  ),
                ),
                if (!proyecto.publico) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock_outline,
                      size: 14, color: AppTheme.textoSecundario),
                  const SizedBox(width: 4),
                  const Text('Privado',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textoSecundario)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(proyecto.nombre,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            if (tipoNombre.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(_iconForTipo(tipoNombre),
                      size: 16, color: AppTheme.azulMedio),
                  const SizedBox(width: 6),
                  Text(tipoNombre,
                      style: const TextStyle(
                          color: AppTheme.azulMedio,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
            if (proyecto.descripcion?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(proyecto.descripcion!,
                  style: const TextStyle(color: AppTheme.textoPrincipal)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _PresupuestoCard ──────────────────────────────────────────────────────────

class _PresupuestoCard extends StatefulWidget {
  const _PresupuestoCard({
    required this.proyecto,
    required this.puedeEditar,
    required this.presupuestoCtrl,
  });

  final Proyecto proyecto;
  final bool puedeEditar;
  final TextEditingController presupuestoCtrl;

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
    final total = widget.puedeEditar
        ? _parseMonto(widget.presupuestoCtrl.text)
        : widget.proyecto.presupuestoActual;
    final disponible = total - _gastado;
    final progress = total > 0 ? (_gastado / total).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Presupuesto',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            if (widget.puedeEditar)
              TextFormField(
                controller: widget.presupuestoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Presupuesto total',
                  prefixText: '\$ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_MontoFormatter()],
              )
            else
              Row(
                children: [
                  _MontoItem(
                      label: 'Total',
                      monto: widget.proyecto.presupuestoActual,
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
          Text(_fmt(monto),
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: color, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── _FechasCard ───────────────────────────────────────────────────────────────

class _FechasCard extends StatelessWidget {
  const _FechasCard({
    required this.proyecto,
    required this.puedeEditar,
    required this.fechaInicio,
    required this.fechaFinEstimada,
    required this.responsables,
    required this.onFechaInicioTap,
    required this.onFechaFinTap,
    required this.onFechaFinClear,
    required this.onResponsablesChanged,
  });

  final Proyecto proyecto;
  final bool puedeEditar;
  final DateTime fechaInicio;
  final DateTime? fechaFinEstimada;
  final List<String> responsables;
  final VoidCallback onFechaInicioTap;
  final VoidCallback onFechaFinTap;
  final VoidCallback onFechaFinClear;
  final void Function(List<String>) onResponsablesChanged;

  void _abrirModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ModalResponsables(
        responsablesActuales: responsables,
        onAgregar: (uid) {
          if (!responsables.contains(uid)) {
            onResponsablesChanged([...responsables, uid]);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.watch<AuthProvider>().isLoggedIn
                  ? 'Fechas y responsables'
                  : 'Fechas',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (puedeEditar) ...[
              _FechaSelector(
                label: 'Fecha de inicio',
                fecha: fechaInicio,
                onTap: onFechaInicioTap,
              ),
              const SizedBox(height: 8),
              _FechaSelector(
                label: 'Fin estimado (opcional)',
                fecha: fechaFinEstimada,
                onTap: onFechaFinTap,
                onClear: fechaFinEstimada != null ? onFechaFinClear : null,
              ),
            ] else ...[
              _FechaRow(label: 'Inicio', fecha: proyecto.fechaInicio),
              if (proyecto.fechaFinEstimada != null)
                _FechaRow(
                    label: 'Fin estimado',
                    fecha: proyecto.fechaFinEstimada!),
              if (proyecto.fechaFinReal != null)
                _FechaRow(
                  label: 'Fin real',
                  fecha: proyecto.fechaFinReal!,
                  color: AppTheme.verdeIngreso,
                ),
            ],
            if (context.watch<AuthProvider>().isLoggedIn) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.people_outline,
                      size: 16, color: AppTheme.textoSecundario),
                  const SizedBox(width: 6),
                  const Text('Responsables',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textoPrincipal)),
                  const Spacer(),
                  if (puedeEditar)
                    IconButton(
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      color: AppTheme.azulMedio,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Agregar responsable',
                      onPressed: () => _abrirModal(context),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (responsables.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Sin responsables asignados',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textoSecundario)),
                )
              else
                Consumer<UsuariosProvider>(
                  builder: (context, usuariosProvider, _) {
                    final usuarios = usuariosProvider.usuarios;

                    String displayName(String uid) {
                      final byId = usuarios.firstWhere(
                        (u) => u['id'] == uid,
                        orElse: () => {},
                      );
                      final u = byId.isNotEmpty
                          ? byId
                          : usuarios.firstWhere(
                              (u) => u['authUid'] == uid,
                              orElse: () => {},
                            );
                      return u['nombre'] as String? ??
                          u['email'] as String? ??
                          'sin mail';
                    }

                    return Column(
                      children: responsables
                          .map((uid) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppTheme.celesteFondo,
                                  child: Icon(Icons.person,
                                      size: 16, color: AppTheme.azulMedio),
                                ),
                                title: Text(
                                  displayName(uid),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                trailing: puedeEditar
                                    ? IconButton(
                                        icon: const Icon(Icons.close, size: 16),
                                        color: AppTheme.textoSecundario,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Quitar responsable',
                                        onPressed: () => onResponsablesChanged(
                                          responsables
                                              .where((id) => id != uid)
                                              .toList(),
                                        ),
                                      )
                                    : null,
                              ))
                          .toList(),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _ModalResponsables ────────────────────────────────────────────────────────

class _ModalResponsables extends StatelessWidget {
  const _ModalResponsables({
    required this.responsablesActuales,
    required this.onAgregar,
  });

  final List<String> responsablesActuales;
  final void Function(String uid) onAgregar;

  @override
  Widget build(BuildContext context) {
    final usuariosProvider = context.watch<UsuariosProvider>();
    final usuarios = usuariosProvider.usuarios;
    final cargando = usuariosProvider.isLoading;

    final disponibles = usuarios
        .where((u) =>
            !responsablesActuales.contains(u['id']) &&
            (u['activo'] as bool? ?? true))
        .toList();

    String displayName(Map<String, dynamic> u) =>
        u['nombre'] as String? ?? u['email'] as String? ?? u['id'] as String? ?? '?';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                const Text('Agregar responsable',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: cargando && usuarios.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : disponibles.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Todos los usuarios activos ya son responsables.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppTheme.textoSecundario),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: disponibles.length,
                        itemBuilder: (ctx, i) {
                          final user = disponibles[i];
                          final uid = user['id'] as String;
                          final rol = user['rol'] as String?;
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppTheme.celesteFondo,
                              child: Icon(Icons.person,
                                  color: AppTheme.azulMedio),
                            ),
                            title: Text(displayName(user)),
                            subtitle: rol != null ? Text(rol) : null,
                            onTap: () {
                              onAgregar(uid);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FechaSelector extends StatelessWidget {
  const _FechaSelector({
    required this.label,
    required this.fecha,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                  tooltip: 'Quitar fecha',
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          fecha != null ? _fmtFecha(fecha!) : 'Sin fecha',
          style: TextStyle(
            color: fecha != null
                ? AppTheme.textoPrincipal
                : AppTheme.textoSecundario,
            fontSize: 14,
          ),
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
          Text(_fmtFecha(fecha),
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

// ── _ItemsCard ────────────────────────────────────────────────────────────────

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

  void _abrirModal([ItemProyecto? item]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _ModalItem(proyectoId: widget.proyectoId, item: item),
    );
  }

  Future<void> _eliminarItem(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar ítem?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.rojoGasto),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) await _repo.eliminarItem(id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final puedeGestionar = auth.esAdmin || auth.esEditor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Ítems',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                if (puedeGestionar)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                    onPressed: _abrirModal,
                  ),
              ],
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
                  children: items
                      .map((item) => _ItemTile(
                            item: item,
                            puedeGestionar: puedeGestionar,
                            onEdit: () => _abrirModal(item),
                            onDelete: () => _eliminarItem(context, item.id),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── _ItemTile ─────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.puedeGestionar,
    required this.onEdit,
    required this.onDelete,
  });

  final ItemProyecto item;
  final bool puedeGestionar;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
      title: Text(item.descripcion,
          style:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
                  borderRadius:
                      const BorderRadius.all(Radius.circular(8)),
                ),
                child: Text(estadoLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: estadoColor,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            if (item.montoEstimado > 0)
              Text(_fmt(item.montoEstimado),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textoSecundario)),
            if (item.cantidad != null && item.unidad != null)
              Text('${item.cantidad} ${item.unidad}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textoSecundario)),
          ],
        ),
      ),
      trailing: puedeGestionar
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  color: AppTheme.azulMedio,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: onDelete,
                  color: AppTheme.rojoGasto,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            )
          : null,
    );
  }
}

// ── _ModalItem ────────────────────────────────────────────────────────────────

class _ModalItem extends StatefulWidget {
  const _ModalItem({required this.proyectoId, this.item});

  final String proyectoId;
  final ItemProyecto? item;

  @override
  State<_ModalItem> createState() => _ModalItemState();
}

class _ModalItemState extends State<_ModalItem> {
  final _repo = ProyectoRepository();
  final _form = GlobalKey<FormState>();
  final _descripcionCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  String _estado = 'pendiente';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _descripcionCtrl.text = item.descripcion;
      _cantidadCtrl.text = item.cantidad?.toString() ?? '';
      _unidadCtrl.text = item.unidad ?? '';
      _montoCtrl.text = _formatearMonto(item.montoEstimado);
      _estado = item.estado;
    }
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _cantidadCtrl.dispose();
    _unidadCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final monto = _parseMonto(_montoCtrl.text);
      final cantidad =
          double.tryParse(_cantidadCtrl.text.trim().replaceAll(',', '.'));
      final unidad = _unidadCtrl.text.trim();

      if (widget.item == null) {
        await _repo.agregarItem(ItemProyecto(
          id: '',
          proyectoId: widget.proyectoId,
          descripcion: _descripcionCtrl.text.trim(),
          cantidad: cantidad,
          unidad: unidad.isEmpty ? null : unidad,
          montoEstimado: monto,
          estado: _estado,
          responsables: [],
          fechaCreacion: DateTime.now(),
        ));
      } else {
        await _repo.actualizarItem(widget.item!.copyWith(
          descripcion: _descripcionCtrl.text.trim(),
          cantidad: cantidad,
          clearCantidad: cantidad == null,
          unidad: unidad.isEmpty ? null : unidad,
          clearUnidad: unidad.isEmpty,
          montoEstimado: monto,
          estado: _estado,
        ));
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.item == null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(esNuevo ? 'Agregar ítem' : 'Editar ítem',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionCtrl,
              decoration:
                  const InputDecoration(labelText: 'Descripción *'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cantidadCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Cantidad'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _unidadCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Unidad'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _montoCtrl,
              decoration: const InputDecoration(
                labelText: 'Monto estimado',
                prefixText: '\$ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_MontoFormatter()],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _estado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const [
                DropdownMenuItem(
                    value: 'pendiente', child: Text('Pendiente')),
                DropdownMenuItem(
                    value: 'en_gestion', child: Text('En gestión')),
                DropdownMenuItem(
                    value: 'presupuestos_aprobados',
                    child: Text('Presupuestos aprobados')),
                DropdownMenuItem(
                    value: 'comprado', child: Text('Comprado')),
              ],
              onChanged: (v) => setState(() => _estado = v!),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _guardar,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(esNuevo ? 'Agregar' : 'Guardar'),
              ),
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

  String _fmtCorta(DateTime d) =>
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
            const Text('Movimientos',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
          Text(_fmtCorta(m.fecha),
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textoSecundario)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text('$signo${_fmt(m.monto)}',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: color, fontSize: 13)),
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

// ── _MontoFormatter ───────────────────────────────────────────────────────────

class _MontoFormatter extends TextInputFormatter {
  final _fmt = NumberFormat('#,##0', 'es_AR');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue value) {
    final raw = value.text;
    if (raw.isEmpty) return value;
    final commas = raw.split('').where((c) => c == ',').length;
    if (commas > 1) return old;
    final allowed = RegExp(r'^[\d.,]*$');
    if (!allowed.hasMatch(raw)) return old;
    final commaIdx = raw.indexOf(',');
    if (commaIdx != -1 && raw.length - commaIdx - 1 > 2) return old;
    final intPart = commaIdx != -1 ? raw.substring(0, commaIdx) : raw;
    final decPart = commaIdx != -1 ? raw.substring(commaIdx) : '';
    final digits = intPart.replaceAll('.', '');
    if (digits.isEmpty) return value;
    final num = int.tryParse(digits);
    if (num == null) return old;
    final formatted = _fmt.format(num) + decPart;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
