import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/proyecto_repository.dart';
import '../../domain/models/item_proyecto.dart';
import '../../domain/models/proyecto.dart';
import '../providers/proyecto_provider.dart';
import 'proyectos_screen.dart';

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

void _mostrarPopupEstadoProyecto(
    BuildContext context, String estadoActual) {
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: esCurrent ? AppTheme.celesteFondo : null,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(icono,
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textoSecundario,
                        ),
                      ),
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
    ('🟡', 'presupuestos_aprobados', 'Presupuestos aprobados',
        AppTheme.verdeTeal,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: esCurrent ? AppTheme.celesteFondo : null,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(icono,
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textoSecundario,
                        ),
                      ),
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

// ── ProyectoDetalleScreen ─────────────────────────────────────────────────────

class ProyectoDetalleScreen extends StatelessWidget {
  const ProyectoDetalleScreen({super.key, required this.proyecto});

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

    final auth = context.watch<AuthProvider>();
    final puedeEditar = auth.esAdmin || auth.esEditor;

    final appBarColor = switch (p.estado) {
      'en_curso' => AppTheme.verdeTeal,
      'planificado' => AppTheme.amarilloAlerta,
      _ => AppTheme.textoSecundario,
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        title: Text(
          p.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (puedeEditar)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar proyecto',
              onPressed: () => mostrarModalProyecto(context, p),
            ),
        ],
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
    final prov = context.read<ProyectoProvider>();
    final auth = context.watch<AuthProvider>();
    final tipoNombre = prov.nombreTipo(proyecto.tipoProyectoId);

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
            Row(
              children: [
                GestureDetector(
                  onTap: () => _mostrarPopupEstadoProyecto(
                      context, proyecto.estado),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (!proyecto.publico) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock_outline,
                      size: 14, color: AppTheme.textoSecundario),
                  const SizedBox(width: 4),
                  const Text(
                    'Privado',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textoSecundario),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(_iconForTipo(tipoNombre),
                    size: 16, color: AppTheme.azulMedio),
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
            if (auth.esAdmin) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible al público'),
                value: proyecto.publico,
                activeThumbColor: AppTheme.verdeTeal,
                onChanged: (v) => context
                    .read<ProyectoProvider>()
                    .actualizar(proyecto.copyWith(publico: v)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _PresupuestoCard ──────────────────────────────────────────────────────────

class _PresupuestoCard extends StatelessWidget {
  const _PresupuestoCard({required this.proyecto});

  final Proyecto proyecto;

  @override
  Widget build(BuildContext context) {
    final total = proyecto.presupuestoActual;
    const gastado = 0.0;
    final disponible = total - gastado;
    final progress = total > 0 ? (gastado / total).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Presupuesto',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
                    monto: gastado,
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
          Text(
            label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textoSecundario),
          ),
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
              'Fechas y responsables',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
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
            if (proyecto.responsables.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Responsables',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: proyecto.responsables
                    .map(
                      (r) => Chip(
                        label: Text(r,
                            style: const TextStyle(fontSize: 12)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    )
                    .toList(),
              ),
            ],
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
            child: Text(
              label,
              style: const TextStyle(
                  color: AppTheme.textoSecundario, fontSize: 13),
            ),
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
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.rojoGasto),
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
                const Text(
                  'Ítems',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
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
                      child: Text(
                        'Sin ítems',
                        style:
                            TextStyle(color: AppTheme.textoSecundario),
                      ),
                    ),
                  );
                }
                return Column(
                  children: items
                      .map((item) => _ItemTile(
                            item: item,
                            puedeGestionar: puedeGestionar,
                            onEdit: () => _abrirModal(item),
                            onDelete: () =>
                                _eliminarItem(context, item.id),
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
      title: Text(
        item.descripcion,
        style:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          children: [
            GestureDetector(
              onTap: () =>
                  _mostrarPopupEstadoItem(context, item.estado),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: estadoColor.withAlpha(30),
                  borderRadius:
                      const BorderRadius.all(Radius.circular(8)),
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

  String _formatearMonto(double v) {
    if (v <= 0) return '';
    if (v == v.truncateToDouble()) {
      return NumberFormat('#,##0', 'es_AR').format(v);
    }
    return NumberFormat('#,##0.##', 'es_AR').format(v);
  }

  double _parseMonto(String s) {
    final clean = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0;
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final monto = _parseMonto(_montoCtrl.text);
      final cantidad = double.tryParse(
          _cantidadCtrl.text.trim().replaceAll(',', '.'));
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
            Text(
              esNuevo ? 'Agregar ítem' : 'Editar ítem',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(esNuevo ? 'Agregar' : 'Guardar'),
              ),
            ),
          ],
        ),
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

    // Allow only digits, dot (thousands) and one comma (decimal)
    final commas = raw.split('').where((c) => c == ',').length;
    if (commas > 1) return old;
    final allowed = RegExp(r'^[\d.,]*$');
    if (!allowed.hasMatch(raw)) return old;

    // Limit 2 decimal digits after comma
    final commaIdx = raw.indexOf(',');
    if (commaIdx != -1 && raw.length - commaIdx - 1 > 2) return old;

    // Reformat integer part
    final intPart =
        commaIdx != -1 ? raw.substring(0, commaIdx) : raw;
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
