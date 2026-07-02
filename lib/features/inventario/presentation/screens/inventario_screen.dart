import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/bien_inventario.dart';
import '../providers/inventario_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatMonto(double monto) {
  final fmt = monto == monto.truncateToDouble()
      ? NumberFormat('#,##0', 'es_AR')
      : NumberFormat('#,##0.##', 'es_AR');
  return '\$${fmt.format(monto)}';
}

String _formatFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.year}';

Color _colorEstado(String estado) => switch (estado) {
      'bueno' => AppTheme.verdeIngreso,
      'regular' => AppTheme.amarilloAlerta,
      'malo' => const Color(0xFFE67E22),
      _ => AppTheme.textoSecundario,
    };

String _labelEstado(String estado) => switch (estado) {
      'bueno' => 'Bueno',
      'regular' => 'Regular',
      'malo' => 'Malo',
      'dado_de_baja' => 'Baja',
      _ => estado,
    };

// ── Screen ────────────────────────────────────────────────────────────────────

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  // 'todos' | 'activos' | 'baja'
  String _filtroEstado = 'todos';
  String _busqueda = '';

  List<BienInventario> _aplicarFiltros(List<BienInventario> lista) {
    var r = lista;
    if (_filtroEstado == 'activos') {
      r = r.where((b) => b.estado != 'dado_de_baja').toList();
    } else if (_filtroEstado == 'baja') {
      r = r.where((b) => b.estado == 'dado_de_baja').toList();
    }
    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      r = r
          .where((b) =>
              b.descripcion.toLowerCase().contains(q) ||
              b.codigo.toLowerCase().contains(q))
          .toList();
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventarioProvider>();
    final auth = context.watch<AuthProvider>();
    final puedeEditar = auth.esEditor || auth.esAdmin;
    final bienes = _aplicarFiltros(provider.todos);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: AppTheme.blanco,
        iconTheme: const IconThemeData(color: AppTheme.blanco),
        titleTextStyle: const TextStyle(
          color: AppTheme.blanco,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: const Text('Inventario'),
        actions: const [AccionAuthWidget()],
      ),
      floatingActionButton: puedeEditar
          ? FloatingActionButton(
              onPressed: () => _mostrarModalAlta(context),
              backgroundColor: AppTheme.verdeTeal,
              child: const Icon(Icons.add, color: AppTheme.blanco),
            )
          : null,
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : bienes.isEmpty
                    ? _buildVacio()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: bienes.length,
                        itemBuilder: (ctx, i) => _BienCard(
                          bien: bienes[i],
                          puedeEditar: puedeEditar,
                          onEditar: () =>
                              _mostrarModalAlta(context, bien: bienes[i]),
                          onBaja: () =>
                              _mostrarModalBaja(context, bienes[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      color: AppTheme.celesteFondo,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Chips de estado
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: 'Todos',
                  activo: _filtroEstado == 'todos',
                  onTap: () => setState(() => _filtroEstado = 'todos'),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Activos',
                  activo: _filtroEstado == 'activos',
                  onTap: () => setState(() => _filtroEstado = 'activos'),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Dados de baja',
                  activo: _filtroEstado == 'baja',
                  onTap: () => setState(() => _filtroEstado = 'baja'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Buscador
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por descripción o código...',
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.textoSecundario),
              suffixIcon: _busqueda.isNotEmpty
                  ? GestureDetector(
                      onTap: () => setState(() => _busqueda = ''),
                      child: const Icon(Icons.close,
                          color: AppTheme.textoSecundario),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: AppTheme.blanco,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppTheme.celesteBorde),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: AppTheme.celesteBorde),
              ),
            ),
            onChanged: (v) => setState(() => _busqueda = v),
          ),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: AppTheme.textoSecundario.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _busqueda.isNotEmpty || _filtroEstado != 'todos'
                ? 'Sin resultados para los filtros aplicados'
                : 'No hay bienes registrados en el inventario',
            style:
                const TextStyle(color: AppTheme.textoSecundario, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _mostrarModalAlta(BuildContext context, {BienInventario? bien}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ModalAlta(bien: bien),
    );
  }

  void _mostrarModalBaja(BuildContext context, BienInventario bien) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ModalBaja(bien: bien),
    );
  }
}

// ── Chip de filtro ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.activo,
    required this.onTap,
  });

  final String label;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? AppTheme.azulMedio : AppTheme.blanco,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(
            color: activo ? AppTheme.azulMedio : AppTheme.celesteBorde,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: activo ? AppTheme.blanco : AppTheme.textoSecundario,
            fontSize: 13,
            fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Card de bien ──────────────────────────────────────────────────────────────

class _BienCard extends StatelessWidget {
  const _BienCard({
    required this.bien,
    required this.puedeEditar,
    required this.onEditar,
    required this.onBaja,
  });

  final BienInventario bien;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onBaja;

  @override
  Widget build(BuildContext context) {
    final estadoColor = _colorEstado(bien.estado);
    final esBaja = bien.estado == 'dado_de_baja';

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Código + chips
            Row(
              children: [
                Text(
                  bien.codigo,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppTheme.textoSecundario,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                _ChipEstado(
                  label: _labelEstado(bien.estado),
                  color: estadoColor,
                ),
                const SizedBox(width: 6),
                _ChipTipoAlta(tipoAlta: bien.tipoAlta),
              ],
            ),
            const SizedBox(height: 8),
            // Descripción
            Text(
              bien.descripcion,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppTheme.textoPrincipal,
              ),
            ),
            const SizedBox(height: 6),
            // Detalles
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _DetalleTxt(
                    icon: Icons.calendar_today_outlined,
                    txt: _formatFecha(bien.fechaAlta)),
                _DetalleTxt(
                    icon: Icons.tag,
                    txt: 'Acta ${bien.nroActa}'),
                if (bien.cantidad > 1)
                  _DetalleTxt(
                      icon: Icons.numbers,
                      txt: 'x${bien.cantidad}'),
                if (bien.valor != null)
                  _DetalleTxt(
                      icon: Icons.sell_outlined,
                      txt: _formatMonto(bien.valor!)),
                if (bien.ubicacion?.isNotEmpty == true)
                  _DetalleTxt(
                      icon: Icons.place_outlined,
                      txt: bien.ubicacion!),
              ],
            ),
            if (puedeEditar && !esBaja) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.azulMedio,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onBaja,
                    icon: const Icon(Icons.remove_circle_outline, size: 16),
                    label: const Text('Dar de baja'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.rojoGasto,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ChipTipoAlta extends StatelessWidget {
  const _ChipTipoAlta({required this.tipoAlta});
  final String tipoAlta;

  @override
  Widget build(BuildContext context) {
    final esDonacion = tipoAlta == 'donacion';
    final color = esDonacion ? AppTheme.verdeIngreso : AppTheme.azulMedio;
    final label = esDonacion ? 'Donación' : 'Compra';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DetalleTxt extends StatelessWidget {
  const _DetalleTxt({required this.icon, required this.txt});
  final IconData icon;
  final String txt;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textoSecundario),
        const SizedBox(width: 3),
        Text(
          txt,
          style:
              const TextStyle(fontSize: 12, color: AppTheme.textoSecundario),
        ),
      ],
    );
  }
}

// ── Modal de alta / edición ───────────────────────────────────────────────────

class _ModalAlta extends StatefulWidget {
  const _ModalAlta({this.bien});
  final BienInventario? bien;

  @override
  State<_ModalAlta> createState() => _ModalAltaState();
}

class _ModalAltaState extends State<_ModalAlta> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _nroActaCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();

  String _estado = 'bueno';
  String _tipoAlta = 'compra';
  DateTime _fechaAlta = DateTime.now();

  bool get _modoEdicion => widget.bien != null;

  @override
  void initState() {
    super.initState();
    final b = widget.bien;
    if (b != null) {
      _descCtrl.text = b.descripcion;
      _nroActaCtrl.text = b.nroActa;
      _cantidadCtrl.text = b.cantidad.toString();
      _valorCtrl.text = b.valor != null
          ? (b.valor! == b.valor!.truncateToDouble()
              ? b.valor!.toInt().toString()
              : b.valor!.toString())
          : '';
      _ubicacionCtrl.text = b.ubicacion ?? '';
      _catCtrl.text = b.categoriaInventario ?? '';
      _estado = b.estado;
      _tipoAlta = b.tipoAlta;
      _fechaAlta = b.fechaAlta;
    } else {
      _cantidadCtrl.text = '1';
    }
    _fechaCtrl.text = _formatFecha(_fechaAlta);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _nroActaCtrl.dispose();
    _cantidadCtrl.dispose();
    _valorCtrl.dispose();
    _ubicacionCtrl.dispose();
    _catCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaAlta,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _fechaAlta = picked;
        _fechaCtrl.text = _formatFecha(picked);
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InventarioProvider>();
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid ?? '';
    final now = DateTime.now();
    final cantidad = int.tryParse(_cantidadCtrl.text) ?? 1;
    final valor = double.tryParse(_valorCtrl.text);
    final ubicacion =
        _ubicacionCtrl.text.trim().isEmpty ? null : _ubicacionCtrl.text.trim();
    final cat =
        _catCtrl.text.trim().isEmpty ? null : _catCtrl.text.trim();

    if (_modoEdicion) {
      final actualizado = widget.bien!.copyWith(
        descripcion: _descCtrl.text.trim(),
        estado: _estado,
        tipoAlta: _tipoAlta,
        fechaAlta: _fechaAlta,
        nroActa: _nroActaCtrl.text.trim(),
        cantidad: cantidad,
        valor: valor,
        ubicacion: ubicacion,
        categoriaInventario: cat,
      );
      await provider.actualizar(actualizado, uid);
    } else {
      final nuevo = BienInventario(
        id: '',
        codigo: '',
        descripcion: _descCtrl.text.trim(),
        estado: _estado,
        tipoAlta: _tipoAlta,
        fechaAlta: _fechaAlta,
        nroActa: _nroActaCtrl.text.trim(),
        cantidad: cantidad,
        valor: valor,
        ubicacion: ubicacion,
        categoriaInventario: cat,
        usuarioId: uid,
        fechaCreacion: now,
      );
      await provider.agregar(nuevo);
    }

    if (provider.error == null && mounted) Navigator.pop(context);
    if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${provider.error}'),
        backgroundColor: AppTheme.rojoGasto,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventarioProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 24, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _modoEdicion ? 'Editar bien' : 'Agregar bien al inventario',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textoPrincipal,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descCtrl,
                decoration:
                    const InputDecoration(labelText: 'Descripción del bien'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresá una descripción' : null,
              ),
              const SizedBox(height: 14),
              // Estado
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Estado'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _estado,
                    isExpanded: true,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'bueno',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.check_circle, color: AppTheme.verdeIngreso, size: 20),
                          title: Text('Bueno'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'regular',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.warning_amber, color: AppTheme.amarilloAlerta, size: 20),
                          title: Text('Regular'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'malo',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.error_outline, color: Color(0xFFE67E22), size: 20),
                          title: Text('Malo'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'dado_de_baja',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.remove_circle_outline, color: AppTheme.textoSecundario, size: 20),
                          title: Text('Dado de baja'),
                        ),
                      ),
                    ],
                    selectedItemBuilder: (ctx) => [
                      const Text('Bueno'),
                      const Text('Regular'),
                      const Text('Malo'),
                      const Text('Dado de baja'),
                    ],
                    onChanged: (v) => setState(() => _estado = v ?? 'bueno'),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Tipo de alta
              const Text(
                'Tipo de alta',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _BotonTipoAlta(
                      label: 'Compra',
                      icono: Icons.shopping_cart_outlined,
                      activo: _tipoAlta == 'compra',
                      color: AppTheme.azulMedio,
                      onTap: () => setState(() => _tipoAlta = 'compra'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BotonTipoAlta(
                      label: 'Donación',
                      icono: Icons.volunteer_activism_outlined,
                      activo: _tipoAlta == 'donacion',
                      color: AppTheme.verdeIngreso,
                      onTap: () => setState(() => _tipoAlta = 'donacion'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _fechaCtrl,
                readOnly: true,
                onTap: _seleccionarFecha,
                decoration: const InputDecoration(
                  labelText: 'Fecha de alta',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nroActaCtrl,
                decoration: const InputDecoration(labelText: 'Nro. de acta'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresá el nro. de acta' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cantidadCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Cantidad'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresá la cantidad';
                  if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _valorCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Valor (opcional)', prefixText: '\$ '),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ubicacionCtrl,
                decoration:
                    const InputDecoration(labelText: 'Ubicación (opcional)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _catCtrl,
                decoration: const InputDecoration(
                    labelText: 'Categoría de inventario (opcional)'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: provider.isSaving ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.verdeTeal,
                  foregroundColor: AppTheme.blanco,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
                child: provider.isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: AppTheme.blanco, strokeWidth: 2))
                    : Text(
                        _modoEdicion ? 'Guardar cambios' : 'Agregar al inventario',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonTipoAlta extends StatelessWidget {
  const _BotonTipoAlta({
    required this.label,
    required this.icono,
    required this.activo,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icono;
  final bool activo;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: activo ? color.withAlpha(30) : Colors.transparent,
          border: Border.all(
              color: activo ? color : AppTheme.celesteBorde, width: 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 18, color: activo ? color : AppTheme.textoSecundario),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: activo ? color : AppTheme.textoSecundario,
                fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modal de baja ─────────────────────────────────────────────────────────────

class _ModalBaja extends StatefulWidget {
  const _ModalBaja({required this.bien});
  final BienInventario bien;

  @override
  State<_ModalBaja> createState() => _ModalBajaState();
}

class _ModalBajaState extends State<_ModalBaja> {
  final _formKey = GlobalKey<FormState>();
  final _nroActaBajaCtrl = TextEditingController();
  final _cantidadBajaCtrl = TextEditingController();
  final _valorBajaCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();

  String? _motivo;
  String? _motivoError;
  DateTime _fechaBaja = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fechaCtrl.text = _formatFecha(_fechaBaja);
    _cantidadBajaCtrl.text = widget.bien.cantidad.toString();
  }

  @override
  void dispose() {
    _nroActaBajaCtrl.dispose();
    _cantidadBajaCtrl.dispose();
    _valorBajaCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaBaja,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _fechaBaja = picked;
        _fechaCtrl.text = _formatFecha(picked);
      });
    }
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_motivo == null) {
      setState(() => _motivoError = 'Seleccioná un motivo');
      return;
    }
    final provider = context.read<InventarioProvider>();
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    final datosBaja = {
      'fechaBaja': _fechaBaja,
      'nroActaBaja': _nroActaBajaCtrl.text.trim(),
      'cantidadBaja': int.tryParse(_cantidadBajaCtrl.text) ?? 1,
      if (_motivo != null) 'motivoBaja': _motivo,
      if (_valorBajaCtrl.text.isNotEmpty)
        'valorBaja': double.tryParse(_valorBajaCtrl.text),
    };
    await provider.registrarBaja(widget.bien.id, datosBaja, uid);
    if (provider.error == null && mounted) Navigator.pop(context);
    if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${provider.error}'),
        backgroundColor: AppTheme.rojoGasto,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventarioProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 24, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Dar de baja',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textoPrincipal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.bien.descripcion,
                style: const TextStyle(
                    color: AppTheme.textoSecundario, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _fechaCtrl,
                readOnly: true,
                onTap: _seleccionarFecha,
                decoration: const InputDecoration(
                  labelText: 'Fecha de baja',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nroActaBajaCtrl,
                decoration: const InputDecoration(labelText: 'Nro. de acta de baja'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresá el nro. de acta' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cantidadBajaCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    const InputDecoration(labelText: 'Cantidad que se da de baja'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresá la cantidad';
                  if ((int.tryParse(v) ?? 0) <= 0) return 'Debe ser mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Motivo de baja',
                  errorText: _motivoError,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _motivo,
                    isExpanded: true,
                    isDense: true,
                    hint: const Text('Seleccioná un motivo'),
                    items: const [
                      DropdownMenuItem(
                        value: 'venta',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.sell_outlined, size: 18),
                          title: Text('Venta'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'deterioro',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.warning_outlined, size: 18),
                          title: Text('Deterioro'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'rotura',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.broken_image_outlined, size: 18),
                          title: Text('Rotura'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'robo',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.security_outlined, size: 18),
                          title: Text('Robo'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'donacion',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.volunteer_activism_outlined, size: 18),
                          title: Text('Donación'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'permuta',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.swap_horiz, size: 18),
                          title: Text('Permuta'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'otro',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.more_horiz, size: 18),
                          title: Text('Otro'),
                        ),
                      ),
                    ],
                    selectedItemBuilder: (ctx) => [
                      const Text('Venta'),
                      const Text('Deterioro'),
                      const Text('Rotura'),
                      const Text('Robo'),
                      const Text('Donación'),
                      const Text('Permuta'),
                      const Text('Otro'),
                    ],
                    onChanged: (v) => setState(() {
                      _motivo = v;
                      _motivoError = null;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _valorBajaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Valor de baja (opcional)',
                    prefixText: '\$ '),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: provider.isSaving ? null : _confirmar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.rojoGasto,
                  foregroundColor: AppTheme.blanco,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
                child: provider.isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: AppTheme.blanco, strokeWidth: 2))
                    : const Text(
                        'Confirmar baja',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
