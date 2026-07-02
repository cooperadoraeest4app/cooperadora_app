import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../admin/presentation/providers/categoria_provider.dart';
import '../../../admin/presentation/providers/metodo_pago_provider.dart';
import '../../../admin/presentation/providers/persona_provider.dart';
import '../../../gastos/domain/models/gasto.dart';
import '../../../ingresos/domain/models/ingreso.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cuenta_bancaria/presentation/providers/cuenta_bancaria_provider.dart';
import '../../../proyectos/presentation/providers/proyecto_provider.dart';
import '../../../inventario/domain/models/bien_inventario.dart';
import '../../../inventario/presentation/providers/inventario_provider.dart';
import '../../../socios/domain/models/cuota.dart';
import '../../../socios/domain/models/socio.dart';
import '../../../socios/domain/models/tipo_cuota.dart';
import '../../../socios/presentation/providers/cuota_provider.dart';
import '../../../socios/presentation/providers/socio_provider.dart';
import '../providers/frecuencia_provider.dart';
import '../providers/movimientos_provider.dart';

const _categoriasInventariables = {
  'Equipamiento',
  'Materiales escolares',
  'Donación',
};

const _miembrosPrueba = [
  'Ana García',
  'Carlos López',
  'María Martínez',
  'Juan Rodríguez',
  'Laura Sánchez',
  'Pedro Fernández',
];

IconData _iconoEstadoProyecto(String estado) => switch (estado) {
      'en_curso' => Icons.play_circle_outline,
      'planificado' => Icons.schedule,
      _ => Icons.folder_outlined,
    };

Color _colorEstadoProyecto(String estado) => switch (estado) {
      'en_curso' => AppTheme.verdeTeal,
      'planificado' => AppTheme.azulMedio,
      _ => AppTheme.textoSecundario,
    };

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
  String? _proyectoId;
  Socio? _socioSeleccionado;
  String? _tipoCuotaId;
  double? _tarifaVigente;
  final _periodoCtrl = TextEditingController();
  // Inventario
  bool _registrarEnInventario = false;
  String? _estadoInicialBien;
  final _descripcionBienCtrl = TextEditingController();
  final _nroActaBienCtrl = TextEditingController();
  final _ubicacionBienCtrl = TextEditingController();

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
    final now = DateTime.now();
    _periodoCtrl.text =
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
    if (widget.ingresoEditar != null) {
      _cargarIngreso(widget.ingresoEditar!);
    } else if (widget.gastoEditar != null) {
      _cargarGasto(widget.gastoEditar!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cuotaProv = context.read<CuotaProvider>();
      final tipoMensual = cuotaProv.tiposCuota.firstWhere(
        (t) => t.nombre.toLowerCase().contains('mensual'),
        orElse: () =>
            const TipoCuota(id: '', nombre: '', orden: 0, activo: false),
      );
      if (tipoMensual.id.isEmpty) return;
      _tipoCuotaId = tipoMensual.id;
      final tarifa = await cuotaProv.obtenerTarifaVigente(tipoMensual.id);
      if (tarifa != null && mounted) {
        setState(() => _tarifaVigente = tarifa.monto);
      }
    });
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
    _proyectoId = i.proyectoId;
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
    _proyectoId = g.proyectoId;
  }

  @override
  void dispose() {
    _montoController.dispose();
    _descripcionController.dispose();
    _fechaController.dispose();
    _donanteController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _periodoCtrl.dispose();
    _descripcionBienCtrl.dispose();
    _nroActaBienCtrl.dispose();
    _ubicacionBienCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTarifaVigente() async {
    if (_tarifaVigente != null) {
      final monto = _tarifaVigente!;
      setState(() {
        _montoController.text = monto == monto.truncateToDouble()
            ? monto.toInt().toString()
            : monto.toString();
      });
      return;
    }
    // Fallback async: race condition donde initState corrió antes de que
    // el provider cargara los tipos de cuota.
    final cuotaProv = context.read<CuotaProvider>();
    final tipoMensual = cuotaProv.tiposCuota.firstWhere(
      (t) => t.nombre.toLowerCase().contains('mensual'),
      orElse: () =>
          const TipoCuota(id: '', nombre: '', orden: 0, activo: false),
    );
    if (tipoMensual.id.isEmpty) return;
    _tipoCuotaId = tipoMensual.id;
    final tarifa = await cuotaProv.obtenerTarifaVigente(tipoMensual.id);
    if (tarifa != null && mounted) {
      setState(() {
        _tarifaVigente = tarifa.monto;
        _montoController.text = tarifa.monto == tarifa.monto.truncateToDouble()
            ? tarifa.monto.toInt().toString()
            : tarifa.monto.toString();
      });
    }
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
      if (tipo == 'ingreso' && _metodoPago == 'Caja Chica') {
        _metodoPago = null;
      }
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
    final cuentaProvider = context.read<CuentaBancariaProvider>();
    final catProvider = context.read<CategoriaProvider>();
    final cuotaProvider = context.read<CuotaProvider>();
    final inventarioProvider = context.read<InventarioProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    final now = DateTime.now();
    final socioSeleccionado = _socioSeleccionado;
    final tipoCuotaId = _tipoCuotaId;
    final catNombreSeleccionada = catProvider
        .obtenerActivas(_tipo)
        .firstWhere((c) => c['id'] == _categoria,
            orElse: () => {'nombre': _esIngreso ? '' : 'Gasto'})['nombre']
        as String;
    final esCuotaSocial = _esIngreso && catNombreSeleccionada == 'Cuota Social';

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
          proyectoId: _proyectoId,
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
              _esYoDonante ? uid : _donanteMiembroSeleccionado,
          ultimaModificacionPor: uid,
          ultimaModificacionFecha: now,
        );
        await provider.actualizarIngreso(updated);
      } else if (!_esIngreso && widget.gastoEditar != null) {
        final updated = widget.gastoEditar!.copyWith(
          monto: monto,
          fecha: _fecha,
          descripcion: descripcion,
          metodoPagoId: _metodoPago!,
          categoriaId: _categoria!,
          proyectoId: _proyectoId,
          comprobante: comprobanteResultante,
          recurrente: _recurrente,
          frecuenciaId: _recurrente ? _frecuenciaId : null,
          proximaFecha: _recurrente ? _calcularProximaFecha() : null,
          ultimaModificacionPor: uid,
          ultimaModificacionFecha: now,
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
          proyectoId: _proyectoId,
          usuarioId: uid,
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
              _esYoDonante ? uid : _donanteMiembroSeleccionado,
        );
        await provider.agregarIngreso(ingreso);
        if (_metodoPago == 'Efectivo' && provider.error == null) {
          await cuentaProvider.sumarACajaChica(
              monto, uid, descripcion ?? catNombreSeleccionada);
        }
        if (esCuotaSocial && socioSeleccionado != null && provider.error == null) {
          await cuotaProvider.registrarPago(Cuota(
            id: '',
            socioId: socioSeleccionado.id,
            tipoCuotaId: tipoCuotaId ?? '',
            periodo: _periodoCtrl.text.trim(),
            monto: monto,
            moneda: 'ARS',
            metodoPagoId: _metodoPago!,
            usuarioId: uid,
            fechaPago: _fecha,
            fechaCreacion: now,
          ));
        }
        if (_registrarEnInventario &&
            catNombreSeleccionada == 'Donación' &&
            provider.error == null) {
          await inventarioProvider.agregar(BienInventario(
            id: '',
            codigo: '',
            descripcion: _descripcionBienCtrl.text.trim(),
            estado: _estadoInicialBien ?? 'bueno',
            tipoAlta: 'donacion',
            fechaAlta: _fecha,
            nroActa: _nroActaBienCtrl.text.trim(),
            cantidad: 1,
            valor: monto,
            ubicacion: _ubicacionBienCtrl.text.trim().isEmpty
                ? null
                : _ubicacionBienCtrl.text.trim(),
            usuarioId: uid,
            fechaCreacion: now,
          ));
        }
      } else {
        final gasto = Gasto(
          id: '',
          monto: monto,
          fecha: _fecha,
          descripcion: descripcion,
          metodoPagoId: _metodoPago!,
          categoriaId: _categoria!,
          proyectoId: _proyectoId,
          usuarioId: uid,
          fechaCreacion: now,
          comprobante: comprobanteResultante,
          recurrente: _recurrente,
          frecuenciaId: _recurrente ? _frecuenciaId : null,
          proximaFecha: _recurrente ? _calcularProximaFecha() : null,
        );
        await provider.agregarGasto(gasto);

        if (_metodoPago == 'Caja Chica' && provider.error == null) {
          final cats = catProvider.obtenerActivas(_tipo);
          final catNombre = cats
              .firstWhere((c) => c['id'] == _categoria,
                  orElse: () => {'nombre': 'Gasto'})['nombre'] as String;
          final observacion = descripcion ?? catNombre;
          await cuentaProvider.descontarDeCajaChica(monto, uid, observacion);
        }
        if (_registrarEnInventario && provider.error == null) {
          await inventarioProvider.agregar(BienInventario(
            id: '',
            codigo: '',
            descripcion: _descripcionBienCtrl.text.trim(),
            estado: _estadoInicialBien ?? 'bueno',
            tipoAlta: 'compra',
            fechaAlta: _fecha,
            nroActa: _nroActaBienCtrl.text.trim(),
            cantidad: 1,
            valor: monto,
            ubicacion: _ubicacionBienCtrl.text.trim().isEmpty
                ? null
                : _ubicacionBienCtrl.text.trim(),
            usuarioId: uid,
            fechaCreacion: now,
          ));
        }
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
    final proyectoProvider = context.watch<ProyectoProvider>();
    final socioProvider = context.watch<SocioProvider>();
    final personaProvider = context.watch<PersonaProvider>();
    final cats = catProvider.obtenerActivas(_tipo);
    final catSeleccionada = _categoria != null
        ? cats.firstWhere((c) => c['id'] == _categoria,
            orElse: () => <String, dynamic>{})
        : <String, dynamic>{};
    final esCuotaSocial = _esIngreso && catSeleccionada['nombre'] == 'Cuota Social';
    final metodos = metodoProvider.obtenerActivos();
    final proyectos = [
      ...proyectoProvider.enCurso,
      ...proyectoProvider.planificados,
      ...proyectoProvider.finalizados,
    ];

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
                  : metodos.isEmpty && _esIngreso
                      ? [const DropdownMenuItem<String>(enabled: false, value: '', child: Text('Sin métodos disponibles'))]
                      : [
                          ...metodos.map((m) => DropdownMenuItem<String>(
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
                              )),
                          if (!_esIngreso)
                            const DropdownMenuItem<String>(
                              value: 'Caja Chica',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.wallet,
                                    size: 20, color: AppTheme.verdeTeal),
                                title: Text('Caja Chica'),
                              ),
                            ),
                        ],
              selectedItemBuilder: metodoProvider.isLoading
                  ? null
                  : (ctx) => [
                        ...metodos.map((m) => Text(m['nombre'] as String)),
                        if (!_esIngreso) const Text('Caja Chica'),
                      ],
              onChanged: (v) => setState(() => _metodoPago = v),
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
                  : (v) {
                      final nom = v != null
                          ? (cats.firstWhere((c) => c['id'] == v,
                                  orElse: () => {})['nombre'] as String?)
                          : null;
                      setState(() {
                        _categoria = v;
                        if (nom != 'Cuota Social') _socioSeleccionado = null;
                        if (!_categoriasInventariables.contains(nom)) {
                          _registrarEnInventario = false;
                        }
                      });
                      if (nom == 'Cuota Social') _cargarTarifaVigente();
                    },
              validator: (v) =>
                  v == null ? 'Seleccioná una categoría' : null,
            ),
            if (!esCuotaSocial) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _proyectoId,
                decoration: const InputDecoration(labelText: 'Proyecto (opcional)'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin proyecto asociado'),
                  ),
                  ...proyectos.map((p) => DropdownMenuItem<String?>(
                        value: p.id,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _iconoEstadoProyecto(p.estado),
                            size: 18,
                            color: _colorEstadoProyecto(p.estado),
                          ),
                          title: Text(p.nombre),
                        ),
                      )),
                ],
                selectedItemBuilder: (ctx) => [
                  const Text('Sin proyecto asociado'),
                  ...proyectos.map((p) => Text(p.nombre)),
                ],
                onChanged: (v) => setState(() => _proyectoId = v),
              ),
            ],
            if (_esIngreso) ...[
              if (!esCuotaSocial) ..._buildCamposIngreso(),
              if (esCuotaSocial)
                ..._buildCamposCuotaSocial(
                  opciones: socioProvider.todos
                      .where((s) => s.activo)
                      .map((s) => (
                            socio: s,
                            nombre: personaProvider.nombreCompleto(s.personaId),
                          ))
                      .toList(),
                ),
            ],
            if (!esCuotaSocial) _buildRecurrencia(),
            _buildComprobante(),
            if (!_modoEdicion &&
                _categoriasInventariables.contains(catSeleccionada['nombre']))
              _buildInventarioSection(
                  esDonacion: catSeleccionada['nombre'] == 'Donación'),
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

  List<Widget> _buildCamposCuotaSocial({
    required List<({Socio socio, String nombre})> opciones,
  }) {
    return [
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 8),
      const Text(
        'Cuota del socio',
        style: TextStyle(
          color: AppTheme.textoSecundario,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 12),
      Autocomplete<({Socio socio, String nombre})>(
        displayStringForOption: (o) => o.nombre,
        optionsBuilder: (val) {
          if (val.text.isEmpty) return opciones.take(5);
          final q = val.text.toLowerCase();
          return opciones.where((o) => o.nombre.toLowerCase().contains(q));
        },
        onSelected: (o) => setState(() => _socioSeleccionado = o.socio),
        fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
          return TextFormField(
            controller: ctrl,
            focusNode: focusNode,
            decoration: const InputDecoration(
              labelText: 'Socio',
              hintText: 'Buscar por nombre',
              suffixIcon: Icon(Icons.search),
            ),
            validator: (_) =>
                _socioSeleccionado == null ? 'Seleccioná un socio' : null,
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final o = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.people_outline, size: 18),
                    title: Text(o.nombre),
                    onTap: () => onSelected(o),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _periodoCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [_PeriodoFormatter()],
        decoration: const InputDecoration(
          labelText: 'Período (MM/AAAA)',
          hintText: 'ej: 06/2026',
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Ingresá el período';
          if (!RegExp(r'^\d{2}/\d{4}$').hasMatch(v)) {
            return 'Formato: MM/AAAA';
          }
          return null;
        },
      ),
    ];
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

  Widget _buildInventarioSection({required bool esDonacion}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(esDonacion
              ? 'Registrar en inventario como bien donado'
              : 'Registrar en inventario'),
          subtitle: Text(esDonacion
              ? 'Esta donación corresponde a un bien mueble inventariable'
              : 'Este gasto corresponde a un bien mueble inventariable'),
          value: _registrarEnInventario,
          activeThumbColor: AppTheme.verdeTeal,
          onChanged: (v) => setState(() => _registrarEnInventario = v),
        ),
        if (_registrarEnInventario) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _descripcionBienCtrl,
            decoration:
                const InputDecoration(labelText: 'Descripción del bien'),
            validator: (v) => _registrarEnInventario &&
                    (v == null || v.trim().isEmpty)
                ? 'Ingresá la descripción del bien'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nroActaBienCtrl,
            decoration: const InputDecoration(labelText: 'Nro. de acta'),
            validator: (v) => _registrarEnInventario &&
                    (v == null || v.trim().isEmpty)
                ? 'Ingresá el nro. de acta'
                : null,
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Estado inicial'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _estadoInicialBien ?? 'bueno',
                isExpanded: true,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: 'bueno',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.check_circle,
                          color: AppTheme.verdeIngreso, size: 18),
                      title: Text('Bueno'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'regular',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.warning_amber,
                          color: AppTheme.amarilloAlerta, size: 18),
                      title: Text('Regular'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'malo',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.error_outline,
                          color: Color(0xFFE67E22), size: 18),
                      title: Text('Malo'),
                    ),
                  ),
                ],
                selectedItemBuilder: (ctx) => const [
                  Text('Bueno'),
                  Text('Regular'),
                  Text('Malo'),
                ],
                onChanged: (v) =>
                    setState(() => _estadoInicialBien = v ?? 'bueno'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ubicacionBienCtrl,
            decoration:
                const InputDecoration(labelText: 'Ubicación (opcional)'),
          ),
        ],
      ],
    );
  }
}

class _PeriodoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length <= 2) {
      return newValue.copyWith(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    final result =
        '${digits.substring(0, 2)}/${digits.substring(2, digits.length.clamp(2, 6))}';
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
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
