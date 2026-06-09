import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.year}';

String _formatearPresupuesto(double monto) {
  if (monto <= 0) return '';
  final intFmt = NumberFormat('#,##0', 'es_AR');
  if (monto == monto.truncateToDouble()) {
    return intFmt.format(monto.toInt());
  }
  final entero = monto.truncate();
  final decimales = ((monto - entero) * 100).round().toString().padLeft(2, '0');
  return '${intFmt.format(entero)},$decimales';
}

class _MontoArgentinoFormatter extends TextInputFormatter {
  static final _intFmt = NumberFormat('#,##0', 'es_AR');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Solo una coma permitida
    if (','.allMatches(text).length > 1) return oldValue;

    final hasComa = text.contains(',');
    final parts = text.split(',');
    final rawInt = parts[0].replaceAll('.', ''); // quita separadores de miles
    final rawDec = hasComa ? parts[1] : null;

    // Parte entera: solo dígitos
    if (rawInt.isNotEmpty && !RegExp(r'^\d+$').hasMatch(rawInt)) return oldValue;

    // Parte decimal: solo dígitos, máximo 2
    if (rawDec != null && !RegExp(r'^\d{0,2}$').hasMatch(rawDec)) return oldValue;

    final formattedInt = rawInt.isEmpty
        ? ''
        : _intFmt.format(int.parse(rawInt));

    final result = hasComa ? '$formattedInt,$rawDec' : formattedInt;

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

IconData _iconForTipo(String nombre) => switch (nombre) {
      'Evento' => Icons.celebration,
      'Infraestructura' => Icons.construction,
      'Viaje de Estudios' => Icons.directions_bus,
      'Equipamiento' => Icons.warehouse,
      _ => Icons.category,
    };

void _mostrarModal(BuildContext context, [Proyecto? proyecto]) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ModalProyecto(proyecto: proyecto),
  );
}

// ── ProyectosScreen ───────────────────────────────────────────────────────────

class ProyectosScreen extends StatefulWidget {
  const ProyectosScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<ProyectosScreen> createState() => _ProyectosScreenState();
}

class _ProyectosScreenState extends State<ProyectosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Tab _buildTab(String label, int count) {
    final hasItems = count > 0;
    return Tab(
      child: Text(
        hasItems ? '$label ($count)' : label,
        style: TextStyle(
          fontWeight: hasItems ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puedeGestionar = context.select<AuthProvider, bool>(
      (a) => a.esEditor || a.esAdmin,
    );
    final provider = context.watch<ProyectoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proyectos'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.blanco,
          unselectedLabelColor: AppTheme.celesteAccento,
          indicatorColor: AppTheme.celesteAccento,
          tabs: [
            _buildTab('En curso', provider.enCurso.length),
            _buildTab('Planificados', provider.planificados.length),
            _buildTab('Finalizados', provider.finalizados.length),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TabProyectos(estado: 'en_curso'),
          _TabProyectos(estado: 'planificado'),
          _TabProyectos(estado: 'finalizado'),
        ],
      ),
      floatingActionButton: puedeGestionar
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.verdeTeal,
              foregroundColor: AppTheme.blanco,
              onPressed: () => _mostrarModal(context),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo proyecto'),
            )
          : null,
    );
  }
}

// ── Tab ───────────────────────────────────────────────────────────────────────

class _TabProyectos extends StatelessWidget {
  const _TabProyectos({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProyectoProvider>();
    final puedeGestionar = context.select<AuthProvider, bool>(
      (a) => a.esEditor || a.esAdmin,
    );

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final proyectos = switch (estado) {
      'en_curso' => provider.enCurso,
      'planificado' => provider.planificados,
      _ => provider.finalizados,
    };

    if (proyectos.isEmpty) {
      return const Center(
        child: Text(
          'Sin proyectos',
          style: TextStyle(color: AppTheme.textoSecundario),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: proyectos.length,
      itemBuilder: (_, i) => _ProyectoCard(
        proyecto: proyectos[i],
        puedeGestionar: puedeGestionar,
      ),
    );
  }
}

// ── ProyectoCard ──────────────────────────────────────────────────────────────

class _ProyectoCard extends StatelessWidget {
  const _ProyectoCard({required this.proyecto, required this.puedeGestionar});

  final Proyecto proyecto;
  final bool puedeGestionar;

  @override
  Widget build(BuildContext context) {
    final tipoNombre =
        context.read<ProyectoProvider>().nombreTipo(proyecto.tipoProyectoId);

    final (chipColor, chipLabel) = switch (proyecto.estado) {
      'en_curso' => (AppTheme.verdeIngreso, 'En curso'),
      'planificado' => (AppTheme.amarilloAlerta, 'Planificado'),
      _ => (AppTheme.textoSecundario, 'Finalizado'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _EstadoChip(color: chipColor, label: chipLabel),
                if (!proyecto.publico) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.lock_outline,
                      size: 14, color: AppTheme.textoSecundario),
                ],
                const Spacer(),
                if (puedeGestionar) ...[
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: AppTheme.azulMedio,
                      onPressed: () => _mostrarModal(context, proyecto),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppTheme.rojoGasto,
                      onPressed: () => _confirmarEliminar(context),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              proyecto.nombre,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.textoPrincipal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tipoNombre,
              style: const TextStyle(
                  color: AppTheme.textoSecundario, fontSize: 12),
            ),
            if (proyecto.descripcion?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                proyecto.descripcion!,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textoPrincipal),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (proyecto.presupuestoActual > 0)
                  _InfoChip(
                    icon: Icons.account_balance_wallet_outlined,
                    label: _fmt(proyecto.presupuestoActual),
                  ),
                _InfoChip(
                  icon: Icons.play_arrow_outlined,
                  label: 'Inicio: ${_fmtFecha(proyecto.fechaInicio)}',
                ),
                if (proyecto.fechaFinEstimada != null)
                  _InfoChip(
                    icon: Icons.event_outlined,
                    label: 'Est.: ${_fmtFecha(proyecto.fechaFinEstimada!)}',
                  ),
                if (proyecto.fechaFinReal != null)
                  _InfoChip(
                    icon: Icons.check_circle_outline,
                    label: 'Fin: ${_fmtFecha(proyecto.fechaFinReal!)}',
                    color: AppTheme.verdeIngreso,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar proyecto'),
        content: Text('¿Eliminar "${proyecto.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<ProyectoProvider>().eliminar(proyecto.id);
              Navigator.pop(context);
            },
            child: Text('Eliminar',
                style: TextStyle(color: AppTheme.rojoGasto)),
          ),
        ],
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textoSecundario;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: c)),
      ],
    );
  }
}

// ── Modal ─────────────────────────────────────────────────────────────────────

class _ModalProyecto extends StatefulWidget {
  const _ModalProyecto({this.proyecto});

  final Proyecto? proyecto;

  @override
  State<_ModalProyecto> createState() => _ModalProyectoState();
}

class _ModalProyectoState extends State<_ModalProyecto> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _presupuestoCtrl;
  late String _tipoId;
  late String _estado;
  late DateTime _fechaInicio;
  DateTime? _fechaFinEstimada;
  late bool _publico;

  bool get _esEdicion => widget.proyecto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.proyecto;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion ?? '');
    _presupuestoCtrl = TextEditingController(
      text: p != null ? _formatearPresupuesto(p.presupuestoActual) : '',
    );
    _tipoId = p?.tipoProyectoId ?? '';
    _estado = p?.estado ?? 'planificado';
    _fechaInicio = p?.fechaInicio ?? DateTime.now();
    _fechaFinEstimada = p?.fechaFinEstimada;
    _publico = p?.publico ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _presupuestoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProyectoProvider>();

    if (_tipoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná un tipo de proyecto')),
      );
      return;
    }

    final presupuesto = double.tryParse(
            _presupuestoCtrl.text.replaceAll('.', '').replaceAll(',', '.')) ??
        0;

    final nuevo = Proyecto(
      id: widget.proyecto?.id ?? '',
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim().isEmpty
          ? null
          : _descripcionCtrl.text.trim(),
      tipoProyectoId: _tipoId,
      presupuestoActual: presupuesto,
      fechaInicio: _fechaInicio,
      fechaFinEstimada: _fechaFinEstimada,
      fechaFinReal: widget.proyecto?.fechaFinReal,
      estado: _estado,
      responsables: widget.proyecto?.responsables ?? [],
      publico: _publico,
      fechaCreacion: widget.proyecto?.fechaCreacion ?? DateTime.now(),
    );

    if (_esEdicion) {
      await provider.actualizar(nuevo);
    } else {
      await provider.agregar(nuevo);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProyectoProvider>();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    _esEdicion ? 'Editar proyecto' : 'Nuevo proyecto',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: AppTheme.textoSecundario,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descripcionCtrl,
                decoration:
                    const InputDecoration(labelText: 'Descripción (opcional)'),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              if (provider.tipos.isEmpty)
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Tipo *'),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Cargando tipos...',
                        style: TextStyle(color: AppTheme.textoSecundario),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _tipoId.isEmpty ? null : _tipoId,
                  decoration: const InputDecoration(labelText: 'Tipo *'),
                  items: provider.tipos
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Row(
                              children: [
                                Icon(
                                  _iconForTipo(t.nombre),
                                  size: 18,
                                  color: AppTheme.azulMedio,
                                ),
                                const SizedBox(width: 10),
                                Text(t.nombre),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _tipoId = v ?? ''),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Requerido' : null,
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _estado,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: const [
                  DropdownMenuItem(
                      value: 'planificado', child: Text('Planificado')),
                  DropdownMenuItem(
                      value: 'en_curso', child: Text('En curso')),
                  DropdownMenuItem(
                      value: 'finalizado', child: Text('Finalizado')),
                ],
                onChanged: (v) => setState(() => _estado = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _presupuestoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Presupuesto estimado (opcional)',
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [_MontoArgentinoFormatter()],
              ),
              const SizedBox(height: 16),
              const Text(
                'Fechas',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textoSecundario,
                ),
              ),
              const SizedBox(height: 8),
              _DatePickerRow(
                label: 'Fecha de inicio *',
                fecha: _fechaInicio,
                onChanged: (d) => setState(() => _fechaInicio = d),
              ),
              const SizedBox(height: 8),
              _DatePickerRow(
                label: 'Fecha fin estimada',
                fecha: _fechaFinEstimada,
                optional: true,
                onChanged: (d) => setState(() => _fechaFinEstimada = d),
                onClear: () => setState(() => _fechaFinEstimada = null),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Público'),
                subtitle: const Text(
                    'Visible para todos sin necesidad de iniciar sesión'),
                value: _publico,
                activeThumbColor: AppTheme.verdeTeal,
                onChanged: (v) => setState(() => _publico = v),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: provider.isSaving ? null : _guardar,
                child: provider.isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.blanco),
                      )
                    : Text(_esEdicion ? 'Guardar cambios' : 'Crear proyecto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.fecha,
    required this.onChanged,
    this.optional = false,
    this.onClear,
  });

  final String label;
  final DateTime? fecha;
  final void Function(DateTime) onChanged;
  final bool optional;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final texto = fecha != null ? _fmtFecha(fecha!) : label;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: fecha ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (d != null) onChanged(d);
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 15),
            label: Text(
              texto,
              style: TextStyle(
                color: fecha != null
                    ? AppTheme.textoPrincipal
                    : AppTheme.textoSecundario,
              ),
            ),
          ),
        ),
        if (optional && fecha != null && onClear != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 16),
              color: AppTheme.textoSecundario,
            ),
          ),
        ],
      ],
    );
  }
}
