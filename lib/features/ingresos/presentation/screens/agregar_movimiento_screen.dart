import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../admin/presentation/providers/categoria_provider.dart';
import '../../../admin/presentation/providers/metodo_pago_provider.dart';
import '../../../gastos/domain/models/gasto.dart';
import '../../../ingresos/domain/models/ingreso.dart';
import '../providers/frecuencia_provider.dart';
import '../providers/movimientos_provider.dart';

const _miembrosPrueba = [
  'Ana García',
  'Carlos López',
  'María Martínez',
  'Juan Rodríguez',
  'Laura Sánchez',
  'Pedro Fernández',
];

IconData _iconoMetodoPago(String nombre) {
  switch (nombre.toLowerCase()) {
    case 'efectivo':
      return Icons.payments;
    case 'transferencia':
    case 'transferencia bancaria':
      return Icons.swap_horiz;
    case 'débito':
    case 'debito':
      return Icons.credit_card;
    case 'crédito':
    case 'credito':
      return Icons.credit_score;
    case 'cheque':
      return Icons.description;
    default:
      return Icons.payment;
  }
}

IconData _iconoCategoria(String? nombre) {
  switch (nombre) {
    case 'people':
      return Icons.people;
    case 'favorite':
      return Icons.favorite;
    case 'account_balance':
      return Icons.account_balance;
    case 'celebration':
      return Icons.celebration;
    case 'sell':
      return Icons.sell;
    case 'add_circle':
      return Icons.add_circle;
    case 'bolt':
      return Icons.bolt;
    case 'menu_book':
      return Icons.menu_book;
    case 'warehouse':
      return Icons.warehouse;
    case 'build':
      return Icons.build;
    case 'point_of_sale':
      return Icons.point_of_sale;
    case 'remove_circle':
      return Icons.remove_circle;
    default:
      return Icons.category;
  }
}

class AgregarMovimientoScreen extends StatefulWidget {
  const AgregarMovimientoScreen({
    super.key,
    this.tipoInicial = 'ingreso',
    this.ingresoEditar,
    this.gastoEditar,
  });

  final String tipoInicial;
  final Ingreso? ingresoEditar;
  final Gasto? gastoEditar;

  @override
  State<AgregarMovimientoScreen> createState() =>
      _AgregarMovimientoScreenState();
}

class _AgregarMovimientoScreenState extends State<AgregarMovimientoScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _tipo;
  DateTime _fecha = DateTime.now();
  String? _metodoPago;
  String? _categoria;
  bool _esMiembro = false;
  bool _esYoDonante = false;
  String? _donanteMiembroSeleccionado;
  TextEditingController? _miembroFieldController;
  String? _nombreComprobante;
  Uint8List? _comprobanteBytes;
  String? _comprobanteUrl;
  bool _subiendo = false;
  bool _recurrente = false;
  String? _frecuenciaId;

  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _fechaController = TextEditingController();
  final _donanteController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();

  bool get _modoEdicion =>
      widget.ingresoEditar != null || widget.gastoEditar != null;

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
    _fechaController.text = _formatFecha(DateTime.now());
    if (widget.ingresoEditar != null) {
      _cargarIngreso(widget.ingresoEditar!);
    } else if (widget.gastoEditar != null) {
      _cargarGasto(widget.gastoEditar!);
    }
  }

  void _cargarIngreso(Ingreso i) {
    _tipo = 'ingreso';
    _montoController.text = i.monto == i.monto.truncateToDouble()
        ? i.monto.toInt().toString()
        : i.monto.toString();
    _fecha = i.fecha;
    _fechaController.text = _formatFecha(i.fecha);
    _descripcionController.text = i.descripcion ?? '';
    _metodoPago = i.metodoPagoId;
    _categoria = i.categoriaId;
    _comprobanteUrl = i.comprobante;
    _recurrente = i.recurrente;
    _frecuenciaId = i.frecuenciaId;
    if (i.donanteUsuarioId != null) {
      _esMiembro = true;
      _donanteMiembroSeleccionado = i.donanteUsuarioId;
    } else {
      _donanteController.text = i.donante ?? '';
      _emailController.text = i.donanteEmail ?? '';
      _telefonoController.text = i.donanteTelefono ?? '';
    }
  }

  void _cargarGasto(Gasto g) {
    _tipo = 'gasto';
    _montoController.text = g.monto == g.monto.truncateToDouble()
        ? g.monto.toInt().toString()
        : g.monto.toString();
    _fecha = g.fecha;
    _fechaController.text = _formatFecha(g.fecha);
    _descripcionController.text = g.descripcion ?? '';
    _metodoPago = g.metodoPagoId;
    _categoria = g.categoriaId;
    _comprobanteUrl = g.comprobante;
    _recurrente = g.recurrente;
    _frecuenciaId = g.frecuenciaId;
  }

  @override
  void dispose() {
    _montoController.dispose();
    _descripcionController.dispose();
    _fechaController.dispose();
    _donanteController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  bool get _esIngreso => _tipo == 'ingreso';

  Color get _colorActivo =>
      _esIngreso ? AppTheme.verdeIngreso : AppTheme.rojoGasto;

  String _formatFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  void _cambiarTipo(String tipo) {
    if (_tipo == tipo) return;
    setState(() {
      _tipo = tipo;
      _categoria = null;
    });
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _fecha = picked;
        _fechaController.text = _formatFecha(picked);
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<MovimientosProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();

    String? comprobanteUrl;
    if (_comprobanteBytes != null && _nombreComprobante != null) {
      setState(() => _subiendo = true);
      try {
        final tipo = _esIngreso ? 'ingresos' : 'gastos';
        final path =
            '$tipo/${now.year}/${now.month.toString().padLeft(2, '0')}';
        comprobanteUrl = await StorageService()
            .subirComprobante(path, _comprobanteBytes!, _nombreComprobante!);
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text('No se pudo subir el comprobante: $e'),
          backgroundColor: AppTheme.rojoGasto,
        ));
      } finally {
        if (mounted) setState(() => _subiendo = false);
      }
    }

    final comprobanteResultante = comprobanteUrl ?? _comprobanteUrl;
    final descripcion = _descripcionController.text.trim().isEmpty
        ? null
        : _descripcionController.text.trim();
    final monto = double.parse(_montoController.text);

    if (_modoEdicion) {
      if (_esIngreso && widget.ingresoEditar != null) {
        final updated = widget.ingresoEditar!.copyWith(
          monto: monto,
          fecha: _fecha,
          descripcion: descripcion,
          metodoPagoId: _metodoPago!,
          categoriaId: _categoria!,
          comprobante: comprobanteResultante,
          recurrente: _recurrente,
          frecuenciaId: _recurrente ? _frecuenciaId : null,
          proximaFecha: _recurrente ? _calcularProximaFecha() : null,
          donante: !_esMiembro && _donanteController.text.trim().isNotEmpty
              ? _donanteController.text.trim()
              : null,
          donanteEmail:
              !_esMiembro && _emailController.text.trim().isNotEmpty
                  ? _emailController.text.trim()
                  : null,
          donanteTelefono:
              !_esMiembro && _telefonoController.text.trim().isNotEmpty
                  ? _telefonoController.text.trim()
                  : null,
          donanteUsuarioId:
              _esYoDonante ? 'usuario_prueba' : _donanteMiembroSeleccionado,
        );
        await provider.actualizarIngreso(updated);
      } else if (!_esIngreso && widget.gastoEditar != null) {
        final updated = widget.gastoEditar!.copyWith(
          monto: monto,
          fecha: _fecha,
          descripcion: descripcion,
          metodoPagoId: _metodoPago!,
          categoriaId: _categoria!,
          comprobante: comprobanteResultante,
          recurrente: _recurrente,
          frecuenciaId: _recurrente ? _frecuenciaId : null,
          proximaFecha: _recurrente ? _calcularProximaFecha() : null,
        );
        await provider.actualizarGasto(updated);
      }
    } else {
      if (_esIngreso) {
        final ingreso = Ingreso(
          id: '',
          monto: monto,
          fecha: _fecha,
          descripcion: descripcion,
          metodoPagoId: _metodoPago!,
          categoriaId: _categoria!,
          usuarioId: 'usuario_prueba',
          fechaCreacion: now,
          comprobante: comprobanteResultante,
          recurrente: _recurrente,
          frecuenciaId: _recurrente ? _frecuenciaId : null,
          proximaFecha: _recurrente ? _calcularProximaFecha() : null,
          donante: !_esMiembro && _donanteController.text.trim().isNotEmpty
              ? _donanteController.text.trim()
              : null,
          donanteEmail:
              !_esMiembro && _emailController.text.trim().isNotEmpty
                  ? _emailController.text.trim()
                  : null,
          donanteTelefono:
              !_esMiembro && _telefonoController.text.trim().isNotEmpty
                  ? _telefonoController.text.trim()
                  : null,
          donanteUsuarioId:
              _esYoDonante ? 'usuario_prueba' : _donanteMiembroSeleccionado,
        );
        await provider.agregarIngreso(ingreso);
      } else {
        final gasto = Gasto(
          id: '',
          monto: monto,
          fecha: _fecha,
          descripcion: descripcion,
          metodoPagoId: _metodoPago!,
          categoriaId: _categoria!,
          usuarioId: 'usuario_prueba',
          fechaCreacion: now,
          comprobante: comprobanteResultante,
          recurrente: _recurrente,
          frecuenciaId: _recurrente ? _frecuenciaId : null,
          proximaFecha: _recurrente ? _calcularProximaFecha() : null,
        );
        await provider.agregarGasto(gasto);
      }
    }

    if (!mounted) return;

    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: AppTheme.rojoGasto,
        ),
      );
      provider.limpiarError();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_modoEdicion
              ? 'Movimiento actualizado correctamente'
              : 'Movimiento guardado correctamente'),
          backgroundColor: AppTheme.verdeIngreso,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context.watch<MovimientosProvider>().isLoading || _subiendo;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _colorActivo,
        foregroundColor: AppTheme.blanco,
        iconTheme: const IconThemeData(color: AppTheme.blanco),
        titleTextStyle: const TextStyle(
          color: AppTheme.blanco,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: Text(_modoEdicion
            ? (_esIngreso ? 'Editar Ingreso' : 'Editar Gasto')
            : (_esIngreso ? 'Nuevo Ingreso' : 'Nuevo Gasto')),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSelectorTipo(),
                  const SizedBox(height: 16),
                  _buildFormCard(),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorActivo,
                      foregroundColor: AppTheme.blanco,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    onPressed: isLoading ? null : _guardar,
                    child: Text(
                      _modoEdicion
                          ? 'Guardar cambios'
                          : (_esIngreso ? 'Guardar Ingreso' : 'Guardar Gasto'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          if (isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectorTipo() {
    return IgnorePointer(
      ignoring: _modoEdicion,
      child: Opacity(
        opacity: _modoEdicion ? 0.5 : 1.0,
        child: Row(
      children: [
        Expanded(
          child: _BotonTipo(
            label: 'Ingreso',
            icono: Icons.arrow_downward,
            activo: _esIngreso,
            color: AppTheme.verdeIngreso,
            onTap: () => _cambiarTipo('ingreso'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BotonTipo(
            label: 'Gasto',
            icono: Icons.arrow_upward,
            activo: !_esIngreso,
            color: AppTheme.rojoGasto,
            onTap: () => _cambiarTipo('gasto'),
          ),
        ),
      ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final catProvider = context.watch<CategoriaProvider>();
    final metodoProvider = context.watch<MetodoPagoProvider>();
    final cats = catProvider.obtenerActivas(_tipo);
    final metodos = metodoProvider.obtenerActivos();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _montoController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: '\$ ',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresá el monto';
                final parsed = double.tryParse(v);
                if (parsed == null || parsed <= 0) {
                  return 'Ingresá un monto válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fechaController,
              readOnly: true,
              onTap: _seleccionarFecha,
              decoration: const InputDecoration(
                labelText: 'Fecha',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _metodoPago,
              decoration:
                  const InputDecoration(labelText: 'Método de pago'),
              items: metodoProvider.isLoading
                  ? [const DropdownMenuItem<String>(enabled: false, value: '', child: Text('Cargando...'))]
                  : metodos.isEmpty
                      ? [const DropdownMenuItem<String>(enabled: false, value: '', child: Text('Sin métodos disponibles'))]
                      : metodos
                          .map((m) => DropdownMenuItem<String>(
                                value: m['nombre'] as String,
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                      _iconoMetodoPago(m['nombre'] as String),
                                      size: 20,
                                      color: AppTheme.azulMedio),
                                  title: Text(m['nombre'] as String),
                                ),
                              ))
                          .toList(),
              selectedItemBuilder: metodoProvider.isLoading || metodos.isEmpty
                  ? null
                  : (ctx) => metodos
                      .map((m) => Text(m['nombre'] as String))
                      .toList(),
              onChanged: metodoProvider.isLoading || metodos.isEmpty
                  ? null
                  : (v) => setState(() => _metodoPago = v),
              validator: (v) =>
                  v == null ? 'Seleccioná un método de pago' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('$_tipo-${cats.length}'),
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: catProvider.isLoading
                  ? [const DropdownMenuItem<String>(enabled: false, value: '', child: Text('Cargando...'))]
                  : cats.isEmpty
                      ? [const DropdownMenuItem<String>(enabled: false, value: '', child: Text('Sin categorías disponibles'))]
                      : cats.map((c) {
                          final color = Color(int.parse(
                              (c['color'] as String).replaceAll('#', '0xFF')));
                          return DropdownMenuItem<String>(
                            value: c['id'] as String,
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  // ignore: deprecated_member_use
                                  color: color.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _iconoCategoria(c['icono'] as String?),
                                  size: 16,
                                  color: color,
                                ),
                              ),
                              title: Text(c['nombre'] as String),
                            ),
                          );
                        }).toList(),
              selectedItemBuilder: catProvider.isLoading || cats.isEmpty
                  ? null
                  : (ctx) =>
                      cats.map((c) => Text(c['nombre'] as String)).toList(),
              onChanged: catProvider.isLoading || cats.isEmpty
                  ? null
                  : (v) => setState(() => _categoria = v),
              validator: (v) =>
                  v == null ? 'Seleccioná una categoría' : null,
            ),
            if (_esIngreso) ..._buildCamposIngreso(),
            _buildRecurrencia(),
            _buildComprobante(),
          ],
        ),
      ),
    );
  }

  Future<void> _seleccionarFoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    // ignore: avoid_print
    print('File name: ${file.name}');
    // ignore: avoid_print
    print('Bytes length: ${file.bytes?.length}');
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer el archivo')),
        );
      }
      return;
    }
    setState(() {
      _nombreComprobante = file.name;
      _comprobanteBytes = file.bytes;
    });
  }

  Future<void> _adjuntarArchivo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    // ignore: avoid_print
    print('File name: ${file.name}');
    // ignore: avoid_print
    print('Bytes length: ${file.bytes?.length}');
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer el archivo')),
        );
      }
      return;
    }
    setState(() {
      _nombreComprobante = file.name;
      _comprobanteBytes = file.bytes;
    });
  }

  DateTime? _calcularProximaFecha() {
    if (!_recurrente || _frecuenciaId == null) return null;
    final frecs = context.read<FrecuenciaProvider>().frecuencias;
    final matches = frecs.where((f) => f.id == _frecuenciaId).toList();
    if (matches.isEmpty) return null;
    return _fecha.add(Duration(days: matches.first.diasIntervalo));
  }

  Widget _buildRecurrencia() {
    final frecProvider = context.watch<FrecuenciaProvider>();
    final frecs = frecProvider.frecuencias;

    if (_frecuenciaId != null &&
        frecs.isNotEmpty &&
        !frecs.any((f) => f.id == _frecuenciaId)) {
      _frecuenciaId = null;
    }

    DateTime? proximaFecha;
    if (_recurrente && _frecuenciaId != null) {
      final matches = frecs.where((f) => f.id == _frecuenciaId).toList();
      if (matches.isNotEmpty) {
        proximaFecha = _fecha.add(Duration(days: matches.first.diasIntervalo));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_esIngreso ? 'Ingreso recurrente' : 'Gasto recurrente'),
          subtitle: const Text('Se repetirá automáticamente'),
          value: _recurrente,
          activeThumbColor: _colorActivo,
          onChanged: (v) => setState(() {
            _recurrente = v;
            if (!v) _frecuenciaId = null;
          }),
        ),
        if (_recurrente) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _frecuenciaId,
            decoration: const InputDecoration(labelText: 'Frecuencia'),
            items: frecs.isEmpty
                ? [
                    const DropdownMenuItem<String>(
                      enabled: false,
                      value: '',
                      child: Text('Cargando...'),
                    )
                  ]
                : frecs
                    .map((f) => DropdownMenuItem<String>(
                          value: f.id,
                          child: Text(f.nombre),
                        ))
                    .toList(),
            onChanged: frecs.isEmpty
                ? null
                : (v) => setState(() => _frecuenciaId = v),
            validator: (v) =>
                _recurrente && v == null ? 'Seleccioná una frecuencia' : null,
          ),
          if (proximaFecha != null) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _colorActivo.withAlpha(20),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_repeat, size: 18, color: _colorActivo),
                  const SizedBox(width: 8),
                  Text(
                    'Próximo recordatorio: ${_formatFecha(proximaFecha)}',
                    style: TextStyle(fontSize: 13, color: _colorActivo),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildComprobante() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Comprobante (opcional)',
          style: TextStyle(
            color: AppTheme.textoSecundario,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        if (_comprobanteUrl != null && _nombreComprobante == null) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _colorActivo.withAlpha(25),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(color: _colorActivo.withAlpha(80)),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 18, color: _colorActivo),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Comprobante existente',
                    style: TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _comprobanteUrl = null),
                  child: const Icon(Icons.close,
                      size: 18, color: AppTheme.textoSecundario),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_nombreComprobante != null) ...[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _colorActivo.withAlpha(25),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(color: _colorActivo.withAlpha(80)),
            ),
            child: Row(
              children: [
                Icon(Icons.insert_drive_file_outlined,
                    size: 18, color: _colorActivo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nombreComprobante!,
                    style:
                        TextStyle(color: _colorActivo, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _nombreComprobante = null;
                    _comprobanteBytes = null;
                  }),
                  child: const Icon(Icons.close,
                      size: 18, color: AppTheme.textoSecundario),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _colorActivo,
                  side: BorderSide(color: _colorActivo),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _seleccionarFoto,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Sacar foto'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _colorActivo,
                  side: BorderSide(color: _colorActivo),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _adjuntarArchivo,
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Adjuntar archivo'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildCamposIngreso() {
    return [
      const SizedBox(height: 8),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('¿El donante es miembro de la Cooperadora?'),
        value: _esMiembro,
        activeColor: AppTheme.verdeIngreso,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (v) => setState(() {
          _esMiembro = v ?? false;
          _esYoDonante = false;
          _donanteMiembroSeleccionado = null;
          _miembroFieldController?.clear();
          _donanteController.clear();
          _emailController.clear();
          _telefonoController.clear();
        }),
      ),
      if (_esMiembro) ...[
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() {
            _esYoDonante = !_esYoDonante;
            if (_esYoDonante) {
              _donanteMiembroSeleccionado = null;
              _miembroFieldController?.clear();
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color:
                  _esYoDonante ? AppTheme.verdeIngreso : AppTheme.blanco,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(color: AppTheme.verdeIngreso, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person,
                  color: _esYoDonante
                      ? AppTheme.blanco
                      : AppTheme.verdeIngreso,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Soy yo',
                  style: TextStyle(
                    color: _esYoDonante
                        ? AppTheme.blanco
                        : AppTheme.verdeIngreso,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: _esYoDonante ? 0.4 : 1.0,
          child: IgnorePointer(
            ignoring: _esYoDonante,
            child: Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return const [];
                final query = textEditingValue.text.toLowerCase();
                return _miembrosPrueba
                    .where((m) => m.toLowerCase().contains(query));
              },
              fieldViewBuilder: (ctx, controller, focusNode, onSubmitted) {
                _miembroFieldController = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Buscar otro miembro',
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: (text) {
                    if (text.isNotEmpty && _esYoDonante) {
                      setState(() => _esYoDonante = false);
                    }
                  },
                );
              },
              onSelected: (value) => setState(() {
                _donanteMiembroSeleccionado = value;
                _esYoDonante = false;
              }),
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius:
                        const BorderRadius.all(Radius.circular(8)),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(option),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ] else ...[
        const SizedBox(height: 16),
        TextFormField(
          controller: _donanteController,
          decoration: const InputDecoration(labelText: 'Nombre donante'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email donante'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _telefonoController,
          keyboardType: TextInputType.phone,
          decoration:
              const InputDecoration(labelText: 'Teléfono donante'),
        ),
      ],
    ];
  }
}

class _BotonTipo extends StatelessWidget {
  const _BotonTipo({
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: activo ? color : AppTheme.blanco,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icono,
              color: activo ? AppTheme.blanco : color,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: activo ? AppTheme.blanco : color,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
