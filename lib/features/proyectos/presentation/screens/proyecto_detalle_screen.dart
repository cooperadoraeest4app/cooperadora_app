import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../home/presentation/screens/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/widgets/nombre_usuario_widget.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../admin/presentation/providers/usuarios_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ingresos/presentation/screens/movimientos_screen.dart';
import '../../data/repositories/proyecto_repository.dart';
import '../../domain/models/item_proyecto.dart';
import '../../domain/models/presupuesto_proyecto.dart';
import '../../domain/models/proyecto.dart';
import '../providers/proyecto_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';

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
    ('⚪', 'pendiente', 'Pendiente', AppTheme.textoSecundario,
        'El ítem está identificado pero aún no se comenzó a gestionar'),
    ('🔵', 'en_gestion', 'En gestión', AppTheme.azulMedio,
        'Los responsables están cotizando y buscando proveedores'),
    ('🟡', 'presupuestos_aprobados', 'Presupuestos aprobados', AppTheme.amarilloAlerta,
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
      final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
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
        ultimaModificacionPor: uid.isNotEmpty ? uid : null,
        ultimaModificacionFecha: DateTime.now(),
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

    return PopScope(
      canPop: !_hayCambios,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final accion = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cambios sin guardar'),
            content:
                const Text('Tenés cambios sin guardar. ¿Qué querés hacer?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancelar'),
                child: const Text('Seguir editando'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'descartar'),
                child: const Text('Descartar',
                    style: TextStyle(color: AppTheme.rojoGasto)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'guardar'),
                child: const Text('Guardar y salir'),
              ),
            ],
          ),
        );
        if (accion == 'guardar') await _guardar(p);
        if (accion != 'cancelar' && accion != null && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: AppTheme.azulOscuro,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          titleSpacing: 0,
          title: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(width: 1, height: 20, color: Colors.white.withOpacity(0.3)),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: Icon(Icons.home, color: Colors.white.withOpacity(0.8), size: 20),
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  ),
                ),
              ),
              Container(width: 1, height: 20, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Proyectos · $estadoLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          actions: [AccionAuthWidget()],
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
                  _PresupuestosCard(proyectoId: p.id),
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

// ── _MetaRow ──────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.usuarioId, this.sufijo});

  final String label;
  final String usuarioId;
  final String? sufijo;

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isLoggedIn) return const SizedBox.shrink();
    if (usuarioId.isEmpty) return const SizedBox.shrink();

    final prov = context.watch<UsuariosProvider>();
    if (prov.isLoading) {
      return const SizedBox(
        height: 16,
        width: 100,
        child: LinearProgressIndicator(),
      );
    }

    final usuario = prov.usuarios.firstWhere(
      (u) => u['id'] == usuarioId || u['authUid'] == usuarioId,
      orElse: () => {},
    );
    final nombre = usuario['nombreCompleto'] as String? ??
        usuario['email'] as String? ??
        usuarioId;

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, color: AppTheme.textoPrincipal),
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: nombre),
          if (sufijo != null)
            TextSpan(
              text: sufijo,
              style: const TextStyle(color: AppTheme.textoSecundario),
            ),
        ],
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
            if (proyecto.usuarioId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _MetaRow(
                  label: 'Creado por: ',
                  usuarioId: proyecto.usuarioId,
                ),
              ),
            if (proyecto.ultimaModificacionPor != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _MetaRow(
                  label: 'Última modificación: ',
                  usuarioId: proyecto.ultimaModificacionPor!,
                  sufijo: proyecto.ultimaModificacionFecha != null
                      ? ' · ${DateFormat('dd/MM/yyyy HH:mm').format(proyecto.ultimaModificacionFecha!)}'
                      : null,
                ),
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
            if (proyecto.usuarioId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _MetaRow(
                  label: 'Creado por: ',
                  usuarioId: proyecto.usuarioId,
                ),
              ),
            if (proyecto.ultimaModificacionPor != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _MetaRow(
                  label: 'Última modificación: ',
                  usuarioId: proyecto.ultimaModificacionPor!,
                  sufijo: proyecto.ultimaModificacionFecha != null
                      ? ' · ${DateFormat('dd/MM/yyyy HH:mm').format(proyecto.ultimaModificacionFecha!)}'
                      : null,
                ),
              ),
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
                Column(
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
                            title: NombreUsuarioWidget(
                              usuarioId: uid,
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
  List<PresupuestoProyecto> _presupuestos = [];
  StreamSubscription<List<PresupuestoProyecto>>? _presupuestosSub;

  @override
  void initState() {
    super.initState();
    _stream = _repo.obtenerItems(widget.proyectoId);
    _presupuestosSub = _repo
        .obtenerPresupuestos(widget.proyectoId)
        .listen((list) {
      if (mounted) setState(() => _presupuestos = list);
    });
  }

  @override
  void dispose() {
    _presupuestosSub?.cancel();
    super.dispose();
  }

  void _abrirModal([ItemProyecto? item]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ModalItem(
        proyectoId: widget.proyectoId,
        item: item,
        presupuestos: _presupuestos,
      ),
    );
  }

  Future<void> _eliminarItem(String id) async {
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
    if (confirm == true) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
      await _repo.eliminarItem(id, uid);
    }
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
                            presupuestos: _presupuestos,
                            puedeGestionar: puedeGestionar,
                            onEdit: () => _abrirModal(item),
                            onDelete: () => _eliminarItem(item.id),
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

// ── _ChipEstado ───────────────────────────────────────────────────────────────

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({required this.estado});
  final String estado;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (estado) {
      'en_gestion' => (AppTheme.azulMedio, 'Gestión'),
      'presupuestos_aprobados' => (AppTheme.amarilloAlerta, 'Aprobado'),
      'comprado' => (AppTheme.verdeIngreso, 'Comprado'),
      _ => (AppTheme.textoSecundario, 'Pendiente'),
    };
    return GestureDetector(
      onTap: () => _mostrarPopupEstadoItem(context, estado),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ── _ItemTile ─────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.presupuestos,
    required this.puedeGestionar,
    required this.onEdit,
    required this.onDelete,
  });

  final ItemProyecto item;
  final List<PresupuestoProyecto> presupuestos;
  final bool puedeGestionar;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Fila principal (tabla sin bordes) ──
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 24,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.descripcion,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 24,
                child: Center(
                  child: Text(
                    item.cantidad != null
                        ? '${item.cantidad} ${item.unidad ?? ''}'.trim()
                        : '',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textoSecundario),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 24,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    item.montoEstimado > 0 ? _fmt(item.montoEstimado) : '',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textoSecundario),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 24,
                child: Center(child: _ChipEstado(estado: item.estado)),
              ),
            ),
            if (puedeGestionar)
              SizedBox(
                height: 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      onPressed: onEdit,
                      color: AppTheme.azulMedio,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          maxWidth: 24, maxHeight: 24),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      onPressed: onDelete,
                      color: AppTheme.rojoGasto,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          maxWidth: 24, maxHeight: 24),
                    ),
                  ],
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
        if (item.presupuestosIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              spacing: 4,
              children: item.presupuestosIds.map((pid) {
                final idx = presupuestos.indexWhere((p) => p.id == pid);
                if (idx == -1) return const SizedBox.shrink();
                return Chip(
                  label: Text('Pres. ${idx + 1}',
                      style: const TextStyle(fontSize: 10)),
                  backgroundColor: AppTheme.celesteFondo,
                  side: const BorderSide(color: AppTheme.azulMedio),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
        // ── Línea de auditoría ──
        if (auth.isLoggedIn) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              NombreUsuarioWidget(
                usuarioId: item.usuarioId,
                prefijo: 'Creó: ',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textoSecundario),
              ),
              Text(
                ' · ${DateFormat('dd/MM/yyyy').format(item.fechaCreacion)}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textoSecundario),
              ),
              if (item.ultimaModificacionPor != null) ...[
                const Text(
                  '  |  ',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textoSecundario),
                ),
                NombreUsuarioWidget(
                  usuarioId: item.ultimaModificacionPor!,
                  prefijo: 'Modificó: ',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textoSecundario),
                ),
                if (item.ultimaModificacionFecha != null)
                  Text(
                    ' · ${DateFormat('dd/MM/yyyy').format(item.ultimaModificacionFecha!)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textoSecundario),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 4),
        const Divider(color: AppTheme.celesteBorde, height: 1),
      ],
    );
  }
}

// ── _ModalItem ────────────────────────────────────────────────────────────────

class _ModalItem extends StatefulWidget {
  const _ModalItem({
    required this.proyectoId,
    this.item,
    required this.presupuestos,
  });

  final String proyectoId;
  final ItemProyecto? item;
  final List<PresupuestoProyecto> presupuestos;

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
  List<String> _presupuestosIds = [];
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
      _presupuestosIds = List.from(item.presupuestosIds);
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
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    try {
      final monto = _parseMonto(_montoCtrl.text);
      final cantidad =
          double.tryParse(_cantidadCtrl.text.trim().replaceAll(',', '.'));
      final unidad = _unidadCtrl.text.trim();

      if (widget.item == null) {
        await _repo.agregarItem(
          ItemProyecto(
            id: '',
            proyectoId: widget.proyectoId,
            descripcion: _descripcionCtrl.text.trim(),
            cantidad: cantidad,
            unidad: unidad.isEmpty ? null : unidad,
            montoEstimado: monto,
            estado: _estado,
            responsables: [],
            fechaCreacion: DateTime.now(),
            usuarioId: uid,
            presupuestosIds: _presupuestosIds,
          ),
          uid,
        );
      } else {
        await _repo.actualizarItem(
          widget.item!.copyWith(
            descripcion: _descripcionCtrl.text.trim(),
            cantidad: cantidad,
            clearCantidad: cantidad == null,
            unidad: unidad.isEmpty ? null : unidad,
            clearUnidad: unidad.isEmpty,
            montoEstimado: monto,
            estado: _estado,
            presupuestosIds: _presupuestosIds,
          ),
          uid,
        );
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
            if (widget.presupuestos.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Incluido en presupuestos:',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textoSecundario),
              ),
              ...widget.presupuestos.asMap().entries.map((e) {
                final numero = e.key + 1;
                final presupuesto = e.value;
                final incluido = _presupuestosIds.contains(presupuesto.id);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Presupuesto $numero'),
                  subtitle: presupuesto.descripcion.isNotEmpty
                      ? Text(
                          presupuesto.descripcion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                  value: incluido,
                  activeColor: AppTheme.azulMedio,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _presupuestosIds.add(presupuesto.id);
                    } else {
                      _presupuestosIds.remove(presupuesto.id);
                    }
                  }),
                );
              }),
            ],
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

// ── _PresupuestosCard ─────────────────────────────────────────────────────────

class _PresupuestosCard extends StatefulWidget {
  const _PresupuestosCard({required this.proyectoId});
  final String proyectoId;

  @override
  State<_PresupuestosCard> createState() => _PresupuestosCardState();
}

class _PresupuestosCardState extends State<_PresupuestosCard> {
  final _repo = ProyectoRepository();
  late final Stream<List<PresupuestoProyecto>> _stream;
  List<ItemProyecto> _items = [];
  StreamSubscription<List<ItemProyecto>>? _itemsSub;
  final Map<String, bool> _presupuestoExpandido = {};

  @override
  void initState() {
    super.initState();
    _stream = _repo.obtenerPresupuestos(widget.proyectoId);
    _itemsSub = _repo
        .obtenerItems(widget.proyectoId)
        .listen((list) {
      if (mounted) setState(() => _items = list);
    });
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    super.dispose();
  }

  void _abrirModal([PresupuestoProyecto? presupuesto]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ModalPresupuesto(
        proyectoId: widget.proyectoId,
        presupuesto: presupuesto,
      ),
    );
  }

  Future<void> _eliminar(PresupuestoProyecto p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar presupuesto?'),
        content: const Text('Se eliminarán también los archivos adjuntos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.rojoGasto),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    for (final url in p.archivos) {
      await StorageService().eliminarComprobante(url);
    }
    await _repo.eliminarPresupuesto(p.id, uid);
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
                  'Presupuestos',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
            StreamBuilder<List<PresupuestoProyecto>>(
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
                        'Sin presupuestos',
                        style: TextStyle(color: AppTheme.textoSecundario),
                      ),
                    ),
                  );
                }
                return Column(
                  children: items
                      .asMap()
                      .entries
                      .map((e) => _PresupuestoTile(
                            presupuesto: e.value,
                            numero: e.key + 1,
                            expandido:
                                _presupuestoExpandido[e.value.id] ?? false,
                            onToggle: () => setState(() {
                              _presupuestoExpandido[e.value.id] =
                                  !(_presupuestoExpandido[e.value.id] ??
                                      false);
                            }),
                            items: _items,
                            puedeGestionar: puedeGestionar,
                            onEdit: () => _abrirModal(e.value),
                            onDelete: () => _eliminar(e.value),
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

// ── _PresupuestoTile ──────────────────────────────────────────────────────────

class _PresupuestoTile extends StatelessWidget {
  const _PresupuestoTile({
    required this.presupuesto,
    required this.numero,
    required this.expandido,
    required this.onToggle,
    required this.items,
    required this.puedeGestionar,
    required this.onEdit,
    required this.onDelete,
  });

  final PresupuestoProyecto presupuesto;
  final int numero;
  final bool expandido;
  final VoidCallback onToggle;
  final List<ItemProyecto> items;
  final bool puedeGestionar;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = presupuesto;
    final vinculados =
        items.where((i) => i.presupuestosIds.contains(p.id)).toList();

    return InkWell(
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header siempre visible ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Presupuesto $numero',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (p.descripcion.isNotEmpty) ...[
                        const Text(
                          ' — ',
                          style:
                              TextStyle(color: AppTheme.textoSecundario),
                        ),
                        Expanded(
                          child: Text(
                            p.descripcion,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textoSecundario),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  expandido ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textoSecundario,
                ),
                if (puedeGestionar)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppTheme.rojoGasto),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        maxWidth: 32, maxHeight: 32),
                  ),
              ],
            ),
          ),
          // ── Contenido expandido ────────────────────────────────────────
          if (expandido)
            Container(
              width: double.infinity,
              color: AppTheme.celesteFondo,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.proveedor != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.store_outlined,
                            size: 14, color: AppTheme.textoSecundario),
                        const SizedBox(width: 4),
                        Text(
                          p.proveedor!,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textoSecundario),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (p.monto != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.attach_money,
                            size: 14, color: AppTheme.verdeIngreso),
                        const SizedBox(width: 4),
                        Text(
                          _fmt(p.monto!),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.verdeIngreso,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (p.archivos.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: p.archivos.asMap().entries.map((e) {
                        return ActionChip(
                          label: Text(
                            'Archivo ${e.key + 1}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          avatar:
                              const Icon(Icons.attach_file, size: 14),
                          onPressed: () async {
                            final uri = Uri.parse(e.value);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (vinculados.isNotEmpty) ...[
                    const Text(
                      'Ítems incluidos:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textoSecundario,
                      ),
                    ),
                    ...vinculados.map((item) => Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 14, color: AppTheme.verdeIngreso),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(item.descripcion,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              if (item.montoEstimado > 0)
                                Text(
                                  _fmt(item.montoEstimado),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textoSecundario),
                                ),
                            ],
                          ),
                        )),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total ítems vinculados:',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _fmt(vinculados
                                .where((i) => i.montoEstimado > 0)
                                .fold(
                                    0.0, (acc, i) => acc + i.montoEstimado)),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.azulMedio,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      NombreUsuarioWidget(
                        usuarioId: p.usuarioId,
                        prefijo: 'Creó: ',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textoSecundario),
                      ),
                      Text(
                        ' · ${DateFormat('dd/MM/yyyy').format(p.fechaCreacion)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textoSecundario),
                      ),
                    ],
                  ),
                  if (puedeGestionar) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Editar'),
                        onPressed: onEdit,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.azulMedio,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const Divider(height: 1, color: AppTheme.celesteBorde),
        ],
      ),
    );
  }
}

// ── _ModalPresupuesto ─────────────────────────────────────────────────────────

class _ModalPresupuesto extends StatefulWidget {
  const _ModalPresupuesto({required this.proyectoId, this.presupuesto});
  final String proyectoId;
  final PresupuestoProyecto? presupuesto;

  @override
  State<_ModalPresupuesto> createState() => _ModalPresupuestoState();
}

class _ModalPresupuestoState extends State<_ModalPresupuesto> {
  final _repo = ProyectoRepository();
  final _storage = StorageService();
  final _form = GlobalKey<FormState>();
  final _descripcionCtrl = TextEditingController();
  final _proveedorCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  List<String> _archivosExistentes = [];
  final List<PlatformFile> _archivosNuevos = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.presupuesto;
    if (p != null) {
      _descripcionCtrl.text = p.descripcion;
      _proveedorCtrl.text = p.proveedor ?? '';
      if (p.monto != null) _montoCtrl.text = _formatearMonto(p.monto!);
      _archivosExistentes = List.from(p.archivos);
    }
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _proveedorCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _archivosNuevos.add(result.files.first));
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    try {
      final urlsNuevas = <String>[];
      for (final f in _archivosNuevos) {
        final url = await _storage.subirComprobante(
          'presupuestos_proyecto/${widget.proyectoId}',
          f.bytes!,
          f.name,
        );
        urlsNuevas.add(url);
      }

      if (widget.presupuesto != null) {
        for (final url in widget.presupuesto!.archivos) {
          if (!_archivosExistentes.contains(url)) {
            await _storage.eliminarComprobante(url);
          }
        }
      }

      final archivos = [..._archivosExistentes, ...urlsNuevas];
      final montoStr = _montoCtrl.text.trim();
      final monto = montoStr.isEmpty ? null : _parseMonto(montoStr);
      final proveedorStr = _proveedorCtrl.text.trim();
      final proveedor = proveedorStr.isEmpty ? null : proveedorStr;

      if (widget.presupuesto == null) {
        await _repo.agregarPresupuesto(
          PresupuestoProyecto(
            id: '',
            proyectoId: widget.proyectoId,
            descripcion: _descripcionCtrl.text.trim(),
            proveedor: proveedor,
            monto: monto,
            archivos: archivos,
            usuarioId: uid,
            fechaCreacion: DateTime.now(),
          ),
          uid,
        );
      } else {
        await _repo.actualizarPresupuesto(
          widget.presupuesto!.copyWith(
            descripcion: _descripcionCtrl.text.trim(),
            proveedor: proveedor,
            clearProveedor: proveedor == null,
            monto: monto,
            clearMonto: monto == null,
            archivos: archivos,
          ),
          uid,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.presupuesto == null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                esNuevo ? 'Agregar presupuesto' : 'Editar presupuesto',
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
              TextFormField(
                controller: _proveedorCtrl,
                decoration: const InputDecoration(labelText: 'Proveedor'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _montoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: '\$ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_MontoFormatter()],
              ),
              const SizedBox(height: 16),
              if (_archivosExistentes.isNotEmpty) ...[
                const Text(
                  'Archivos adjuntos',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textoSecundario),
                ),
                const SizedBox(height: 4),
                ..._archivosExistentes.asMap().entries.map(
                      (e) => ListTile(
                        dense: true,
                        leading:
                            const Icon(Icons.attach_file, size: 18),
                        title: Text(
                          'Archivo ${e.key + 1}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: AppTheme.rojoGasto),
                          onPressed: () => setState(() =>
                              _archivosExistentes.removeAt(e.key)),
                          visualDensity: VisualDensity.compact,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                const SizedBox(height: 4),
              ],
              if (_archivosNuevos.isNotEmpty) ...[
                const Text(
                  'Nuevos archivos',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textoSecundario),
                ),
                const SizedBox(height: 4),
                ..._archivosNuevos.asMap().entries.map(
                      (e) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.upload_file,
                            size: 18, color: AppTheme.verdeTeal),
                        title: Text(
                          e.value.name,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: AppTheme.rojoGasto),
                          onPressed: () => setState(
                              () => _archivosNuevos.removeAt(e.key)),
                          visualDensity: VisualDensity.compact,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                const SizedBox(height: 4),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file, size: 16),
                label: const Text('Adjuntar archivo'),
                onPressed: _saving ? null : _pickFile,
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
