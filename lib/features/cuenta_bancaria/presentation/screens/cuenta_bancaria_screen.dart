import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../../shared/widgets/nombre_usuario_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/cuenta_bancaria.dart';
import '../../domain/models/movimiento_bancario.dart';
import '../providers/cuenta_bancaria_provider.dart';

String _doubleToArgentino(double v) {
  final format = v == v.truncateToDouble()
      ? NumberFormat('#,##0', 'es_AR')
      : NumberFormat('#,##0.##', 'es_AR');
  return format.format(v);
}

Widget _buildSaldoWidget(double saldo) {
  const mainStyle = TextStyle(
    color: AppTheme.textoPrincipal,
    fontSize: 44,
    fontWeight: FontWeight.bold,
    height: 1,
  );
  final cents = (saldo.abs() * 100).round() % 100;
  final intFormatted =
      '\$${NumberFormat('#,##0', 'es_AR').format(saldo.truncate())}';
  if (cents == 0) return Text(intFormatted, style: mainStyle);
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(intFormatted, style: mainStyle),
      Text(
        cents.toString().padLeft(2, '0'),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppTheme.textoPrincipal,
        ),
      ),
    ],
  );
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

class _MontoArgentinoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Strip thousands dots (we inserted them, user didn't type them)
    final stripped = text.replaceAll('.', '');

    // Only digits and comma
    if (!RegExp(r'^[\d,]*$').hasMatch(stripped)) return oldValue;

    // Only one comma
    if (','.allMatches(stripped).length > 1) return oldValue;

    final parts = stripped.split(',');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : null;

    // Max 2 decimal digits
    if (decPart != null && decPart.length > 2) return oldValue;

    // Format integer part with thousand-dot separators
    String formattedInt = '';
    if (intPart.isNotEmpty) {
      final n = int.tryParse(intPart);
      formattedInt = n != null
          ? NumberFormat('#,##0', 'es_AR').format(n)
          : intPart;
    }

    final result = decPart != null ? '$formattedInt,$decPart' : formattedInt;

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class CuentaBancariaScreen extends StatefulWidget {
  const CuentaBancariaScreen({super.key});

  @override
  State<CuentaBancariaScreen> createState() => _CuentaBancariaScreenState();
}

class _CuentaBancariaScreenState extends State<CuentaBancariaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Formulario de configuración
  final _setupFormKey = GlobalKey<FormState>();
  final _bancoCtrl = TextEditingController();
  final _titularCtrl = TextEditingController();
  String? _tipoCuenta;
  final _cbuCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();

  // Formulario de actualizar saldo
  final _saldoFormKey = GlobalKey<FormState>();
  final _saldoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _periodoResumenCtrl = TextEditingController();
  bool _saldoInicializado = false;
  String? _archivoNombre;
  Uint8List? _archivoBytes;
  bool _editandoCuenta = false;
  double? _saldoExistente;

  void _prepararEdicion(CuentaBancaria c) {
    _bancoCtrl.text = c.banco;
    _titularCtrl.text = c.titular ?? '';
    _tipoCuenta = c.tipoCuenta;
    _cbuCtrl.text = c.cbu;
    _aliasCtrl.text = c.alias ?? '';
    _saldoExistente = c.saldoActual;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_saldoInicializado) {
      final cuenta = context.read<CuentaBancariaProvider>().cuenta;
      if (cuenta != null) {
        _saldoCtrl.text = _doubleToArgentino(cuenta.saldoActual);
        _saldoInicializado = true;
      }
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _bancoCtrl.dispose();
    _titularCtrl.dispose();
    _cbuCtrl.dispose();
    _aliasCtrl.dispose();
    _saldoCtrl.dispose();
    _obsCtrl.dispose();
    _periodoResumenCtrl.dispose();
    super.dispose();
  }

  Future<void> _configurarCuenta() async {
    if (!_setupFormKey.currentState!.validate()) return;
    final provider = context.read<CuentaBancariaProvider>();
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    final cuenta = CuentaBancaria(
      id: 'cuenta_principal',
      banco: _bancoCtrl.text.trim(),
      titular: _titularCtrl.text.trim().isEmpty ? null : _titularCtrl.text.trim(),
      tipoCuenta: _tipoCuenta!,
      cbu: _cbuCtrl.text.trim(),
      alias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
      saldoActual: _saldoExistente ?? 0,
      activa: true,
      fechaActualizacion: DateTime.now(),
    );
    await provider.crearCuenta(cuenta, uid);
    if (!mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error!),
        backgroundColor: AppTheme.rojoGasto,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_editandoCuenta
            ? 'Datos actualizados correctamente'
            : 'Cuenta configurada correctamente'),
        backgroundColor: AppTheme.verdeIngreso,
      ));
      setState(() {
        _saldoInicializado = false;
        _editandoCuenta = false;
        _saldoExistente = null;
      });
    }
  }

  Future<void> _actualizarSaldo() async {
    if (!_saldoFormKey.currentState!.validate()) return;
    final provider = context.read<CuentaBancariaProvider>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final nuevoSaldo = double.tryParse(
      _saldoCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    if (nuevoSaldo == null) return;
    final obs = _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim();
    final uid = auth.currentUser?.uid ?? '';

    if (_archivoNombre != null && _archivoBytes != null) {
      final periodo = _periodoResumenCtrl.text.trim();
      if (!RegExp(r'^\d{2}/\d{4}$').hasMatch(periodo)) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Ingresá un período válido (MM/AAAA)'),
          backgroundColor: AppTheme.rojoGasto,
        ));
        return;
      }

      final partes = periodo.split('/');
      final mes = partes[0];
      final anio = partes[1];

      String? archivoUrl;
      try {
        archivoUrl = await StorageService().subirComprobante(
          'resumenes_bancarios/$anio/$mes',
          _archivoBytes!,
          _archivoNombre!,
        );
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text('No se pudo subir el PDF: $e'),
          backgroundColor: AppTheme.rojoGasto,
        ));
      }

      if (archivoUrl != null) {
        await provider.actualizarSaldoConResumen(
          nuevoSaldo, uid, periodo, archivoUrl, observaciones: obs);
      } else {
        await provider.actualizarSaldo(nuevoSaldo, uid, observaciones: obs);
      }
    } else {
      await provider.actualizarSaldo(nuevoSaldo, uid, observaciones: obs);
    }

    if (!mounted) return;
    if (provider.error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(provider.error!),
        backgroundColor: AppTheme.rojoGasto,
      ));
    } else {
      _obsCtrl.clear();
      _clearFile();
      setState(() => _saldoInicializado = false);
      messenger.showSnackBar(const SnackBar(
        content: Text('Saldo actualizado correctamente'),
        backgroundColor: AppTheme.verdeIngreso,
      ));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) return;
    setState(() {
      _archivoNombre = file.name;
      _archivoBytes = file.bytes;
      if (_periodoResumenCtrl.text.isEmpty) {
        final now = DateTime.now();
        _periodoResumenCtrl.text =
            '${now.month.toString().padLeft(2, '0')}/${now.year}';
      }
    });
  }

  void _clearFile() => setState(() {
        _archivoNombre = null;
        _archivoBytes = null;
        _periodoResumenCtrl.clear();
      });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CuentaBancariaProvider>();
    final auth = context.watch<AuthProvider>();
    final esAdmin = auth.esAdmin;
    final cuenta = provider.cuenta;

    // Pre-fill saldo when cuenta loads for the first time
    if (!_saldoInicializado && cuenta != null) {
      _saldoCtrl.text = _doubleToArgentino(cuenta.saldoActual);
      _saldoInicializado = true;
    }

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
        title: const Text('Cuenta Bancaria'),
        actions: const [AccionAuthWidget()],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.blanco,
          labelColor: AppTheme.blanco,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Cuenta Bancaria'),
            Tab(text: 'Caja Chica'),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                (cuenta == null || _editandoCuenta)
                    ? _buildSinCuenta(esAdmin, provider.isSaving)
                    : _buildConCuenta(cuenta, esAdmin, provider),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CajaChicaSection(puedeActualizar: auth.esAdmin || auth.esEditor),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── Sin cuenta configurada ────────────────────────────────────────────────

  Widget _buildSinCuenta(bool esAdmin, bool isSaving) {
    if (!esAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_outlined,
                  size: 64, color: AppTheme.textoSecundario),
              SizedBox(height: 16),
              Text(
                'La cuenta bancaria aún no ha sido configurada.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textoSecundario),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _setupFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editandoCuenta ? 'Editar datos de la cuenta' : 'Configurar cuenta bancaria',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textoPrincipal,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ingresá los datos de la cuenta de la Cooperadora.',
              style: TextStyle(color: AppTheme.textoSecundario, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _bancoCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Banco *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresá el nombre del banco'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titularCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Titular de la cuenta (opcional)',
                        hintText: 'Nombre como figura en el banco',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _tipoCuenta,
                      decoration:
                          const InputDecoration(labelText: 'Tipo de cuenta *'),
                      items: const [
                        DropdownMenuItem(
                          value: 'Caja de ahorro',
                          child: Text('Caja de ahorro'),
                        ),
                        DropdownMenuItem(
                          value: 'Cuenta corriente',
                          child: Text('Cuenta corriente'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _tipoCuenta = v),
                      validator: (v) =>
                          v == null ? 'Seleccioná el tipo de cuenta' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cbuCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(22),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'CBU *',
                        hintText: '22 dígitos',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresá el CBU';
                        if (v.length != 22) return 'El CBU debe tener 22 dígitos';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _aliasCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Alias (opcional)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isSaving ? null : _configurarCuenta,
              child: isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.blanco),
                    )
                  : Text(_editandoCuenta ? 'Guardar cambios' : 'Configurar cuenta'),
            ),
            if (_editandoCuenta) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: isSaving
                    ? null
                    : () => setState(() {
                          _editandoCuenta = false;
                          _saldoExistente = null;
                        }),
                child: const Text('Cancelar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Con cuenta configurada ────────────────────────────────────────────────

  Widget _buildConCuenta(
    CuentaBancaria cuenta,
    bool esAdmin,
    CuentaBancariaProvider provider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SaldoCard(cuenta: cuenta),
          const SizedBox(height: 16),
          _InfoCuentaDatosCard(cuenta: cuenta),
          if (esAdmin) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar datos de la cuenta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.azulMedio,
                side: const BorderSide(color: AppTheme.azulMedio),
              ),
              onPressed: () {
                _prepararEdicion(cuenta);
                setState(() => _editandoCuenta = true);
              },
            ),
            const SizedBox(height: 8),
            _ActualizarSaldoCard(
              formKey: _saldoFormKey,
              saldoCtrl: _saldoCtrl,
              obsCtrl: _obsCtrl,
              periodoResumenCtrl: _periodoResumenCtrl,
              archivoNombre: _archivoNombre,
              isSaving: provider.isSaving,
              onActualizar: _actualizarSaldo,
              onPickFile: _pickFile,
              onClearFile: _clearFile,
            ),
          ],
          const SizedBox(height: 16),
          _HistorialCard(movimientos: provider.movimientos, esAdmin: esAdmin),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Saldo ─────────────────────────────────────────────────────────────────────

class _SaldoCard extends StatelessWidget {
  const _SaldoCard({required this.cuenta});

  final CuentaBancaria cuenta;

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  @override
  Widget build(BuildContext context) {
    final s = cuenta.saldoActual;
    final saldoStr =
        s == s.truncateToDouble() ? s.toInt().toString() : s.toStringAsFixed(2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Saldo actual',
                  style: TextStyle(
                    color: AppTheme.textoSecundario,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.copy, size: 14),
                  color: AppTheme.textoSecundario,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Copiar saldo',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: saldoStr));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Row(children: [
                          Icon(Icons.check_circle,
                              color: AppTheme.verdeIngreso, size: 18),
                          SizedBox(width: 8),
                          Text('Saldo copiado al portapapeles'),
                        ]),
                      ));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: saldoStr));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Row(children: [
                      Icon(Icons.check_circle,
                          color: AppTheme.verdeIngreso, size: 18),
                      SizedBox(width: 8),
                      Text('Saldo copiado al portapapeles'),
                    ]),
                  ));
                }
              },
              child: _buildSaldoWidget(s),
            ),
            const SizedBox(height: 4),
            Text(
              'Actualizado: ${_fmtFecha(cuenta.fechaActualizacion)}',
              style: const TextStyle(
                  color: AppTheme.textoSecundario, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info de cuenta ────────────────────────────────────────────────────────────

class _InfoCuentaDatosCard extends StatelessWidget {
  const _InfoCuentaDatosCard({required this.cuenta});

  final CuentaBancaria cuenta;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Datos de la cuenta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textoPrincipal,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.copy_all, size: 18),
                  color: AppTheme.azulMedio,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Copiar todos los datos',
                  onPressed: () async {
                    final buf = StringBuffer();
                    buf.writeln('Banco: ${cuenta.banco}');
                    if (cuenta.titular != null && cuenta.titular!.isNotEmpty) {
                      buf.writeln('Titular: ${cuenta.titular}');
                    }
                    buf.writeln('Tipo: ${cuenta.tipoCuenta}');
                    buf.writeln('CBU: ${cuenta.cbu}');
                    if (cuenta.alias != null && cuenta.alias!.isNotEmpty) {
                      buf.writeln('Alias: ${cuenta.alias}');
                    }
                    await Clipboard.setData(
                        ClipboardData(text: buf.toString().trimRight()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Row(children: [
                          Icon(Icons.check_circle,
                              color: AppTheme.verdeIngreso, size: 18),
                          SizedBox(width: 8),
                          Text('Datos de la cuenta copiados'),
                        ]),
                      ));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Banco', valor: cuenta.banco),
            if (cuenta.titular != null && cuenta.titular!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _InfoRow(label: 'Titular', valor: cuenta.titular!),
            ],
            const SizedBox(height: 6),
            _InfoRow(label: 'Tipo', valor: cuenta.tipoCuenta),
            const SizedBox(height: 6),
            _CopiableRow(
                label: 'CBU', valor: cuenta.cbu, snackMsg: 'CBU copiado'),
            if (cuenta.alias != null && cuenta.alias!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _CopiableRow(
                label: 'Alias',
                valor: cuenta.alias!,
                snackMsg: 'Alias copiado: ${cuenta.alias!}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ',
            style: const TextStyle(
                color: AppTheme.textoSecundario, fontSize: 13)),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(
              color: AppTheme.textoPrincipal,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Fila copiable (CBU, alias, titular) ──────────────────────────────────────

class _CopiableRow extends StatelessWidget {
  const _CopiableRow({
    required this.label,
    required this.valor,
    required this.snackMsg,
  });

  final String label;
  final String valor;
  final String snackMsg;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
              color: AppTheme.textoSecundario, fontSize: 13),
        ),
        Flexible(
          child: Text(
            valor,
            style: const TextStyle(
              color: AppTheme.textoPrincipal,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          color: AppTheme.azulMedio,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Copiar $label',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: valor));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppTheme.verdeIngreso, size: 18),
                      const SizedBox(width: 8),
                      Text(snackMsg),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

// ── Actualizar saldo ──────────────────────────────────────────────────────────

class _ActualizarSaldoCard extends StatelessWidget {
  const _ActualizarSaldoCard({
    required this.formKey,
    required this.saldoCtrl,
    required this.obsCtrl,
    required this.periodoResumenCtrl,
    required this.archivoNombre,
    required this.isSaving,
    required this.onActualizar,
    required this.onPickFile,
    required this.onClearFile,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController saldoCtrl;
  final TextEditingController obsCtrl;
  final TextEditingController periodoResumenCtrl;
  final String? archivoNombre;
  final bool isSaving;
  final VoidCallback onActualizar;
  final VoidCallback onPickFile;
  final VoidCallback onClearFile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Actualizar saldo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textoPrincipal,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: saldoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_MontoArgentinoFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Nuevo saldo *',
                  prefixText: '\$ ',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresá el saldo';
                  final parsed = double.tryParse(
                    v.replaceAll('.', '').replaceAll(',', '.'),
                  );
                  if (parsed == null) return 'Ingresá un valor válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: obsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observaciones (opcional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              if (archivoNombre == null)
                OutlinedButton.icon(
                  onPressed: onPickFile,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Adjuntar resumen PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.azulMedio,
                    side: const BorderSide(color: AppTheme.azulMedio),
                  ),
                )
              else ...[
                Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 18, color: AppTheme.azulMedio),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        archivoNombre!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textoPrincipal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onClearFile,
                      tooltip: 'Quitar archivo',
                      color: AppTheme.rojoGasto,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: periodoResumenCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    _PeriodoFormatter(),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Período del resumen *',
                    hintText: 'MM/AAAA',
                  ),
                  validator: (v) {
                    if (archivoNombre == null) return null;
                    if (v == null || v.isEmpty) return 'Ingresá el período';
                    if (!RegExp(r'^\d{2}/\d{4}$').hasMatch(v)) {
                      return 'Formato inválido (MM/AAAA)';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isSaving ? null : onActualizar,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.blanco),
                      )
                    : Text(archivoNombre != null
                        ? 'Actualizar saldo y subir resumen'
                        : 'Actualizar saldo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Historial ─────────────────────────────────────────────────────────────────

enum _ModoHistorial { defecto, resumenes, fecha }

const _mesesEs = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

class _HistorialCard extends StatefulWidget {
  const _HistorialCard({required this.movimientos, required this.esAdmin});

  final List<MovimientoBancario> movimientos;
  final bool esAdmin;

  @override
  State<_HistorialCard> createState() => _HistorialCardState();
}

class _HistorialCardState extends State<_HistorialCard> {
  _ModoHistorial _modo = _ModoHistorial.defecto;
  bool _ascendente = false;
  int _anioSeleccionado = DateTime.now().year;
  DateTime? _desde;
  DateTime? _hasta;
  int _pagina = 0;
  static const _porPagina = 10;

  List<MovimientoBancario> get _ordenados {
    final lista = [...widget.movimientos];
    if (_ascendente) {
      lista.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
    }
    return lista;
  }

  List<int> get _aniosDisponibles {
    final anios = widget.movimientos
        .map((m) => m.fechaCreacion.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final anioActual = DateTime.now().year;
    if (!anios.contains(anioActual)) anios.insert(0, anioActual);
    return anios;
  }

  List<MovimientoBancario> get _filtradoFecha {
    return _ordenados.where((m) {
      if (_desde != null && m.fechaCreacion.isBefore(_desde!)) return false;
      if (_hasta != null &&
          m.fechaCreacion.isAfter(_hasta!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildOrdenSelector() {
    return Row(
      children: [
        const Text(
          'Ordenar por',
          style: TextStyle(color: AppTheme.textoSecundario, fontSize: 13),
        ),
        TextButton(
          onPressed: () => setState(() {
            _ascendente = !_ascendente;
            _pagina = 0;
          }),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.azulMedio,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_ascendente ? 'Más antiguo' : 'Más reciente'),
              const Icon(Icons.keyboard_arrow_down, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Historial',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textoPrincipal,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Recientes'),
                  selected: _modo == _ModoHistorial.defecto,
                  onSelected: (_) =>
                      setState(() => _modo = _ModoHistorial.defecto),
                ),
                FilterChip(
                  label: const Text('Por año'),
                  selected: _modo == _ModoHistorial.resumenes,
                  onSelected: (_) =>
                      setState(() => _modo = _ModoHistorial.resumenes),
                ),
                FilterChip(
                  label: const Text('Por fecha'),
                  selected: _modo == _ModoHistorial.fecha,
                  onSelected: (_) => setState(() {
                    _modo = _ModoHistorial.fecha;
                    _pagina = 0;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_modo == _ModoHistorial.defecto)
              _buildDefecto()
            else if (_modo == _ModoHistorial.resumenes)
              _buildResumenes()
            else
              _buildFecha(),
          ],
        ),
      ),
    );
  }

  Widget _buildDefecto() {
    final ultimos = _ordenados.take(6).toList();
    if (ultimos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Sin movimientos registrados',
            style: TextStyle(color: AppTheme.textoSecundario, fontSize: 13),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOrdenSelector(),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ultimos.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _MovimientoTile(
              movimiento: ultimos[i], esAdmin: widget.esAdmin),
        ),
        if (widget.movimientos.length > 6) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _modo = _ModoHistorial.fecha;
              _pagina = 0;
            }),
            child: Text(
                'Ver todo el historial (${widget.movimientos.length})'),
          ),
        ],
      ],
    );
  }

  Widget _buildResumenes() {
    final anios = _aniosDisponibles;
    if (!anios.contains(_anioSeleccionado)) {
      _anioSeleccionado = anios.first;
    }

    final resumenesPorMes = <int, MovimientoBancario>{};
    for (final m
        in widget.movimientos.where((m) => m.tipo == 'resumen_mensual')) {
      final periodo = m.periodo;
      if (periodo != null && RegExp(r'^\d{2}/\d{4}$').hasMatch(periodo)) {
        final partes = periodo.split('/');
        final anio = int.tryParse(partes[1]);
        final mes = int.tryParse(partes[0]);
        if (anio == _anioSeleccionado && mes != null) {
          resumenesPorMes[mes] = m;
        }
      }
    }

    final ahora = DateTime.now();
    final mesLimite =
        _anioSeleccionado == ahora.year ? ahora.month : 12;

    final meses = _ascendente
        ? List.generate(mesLimite, (i) => i + 1)
        : List.generate(mesLimite, (i) => mesLimite - i);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                initialValue: _anioSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Año',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: anios
                    .map((a) => DropdownMenuItem(value: a, child: Text('$a')))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _anioSeleccionado = v ?? _anioSeleccionado),
              ),
            ),
          ],
        ),
        _buildOrdenSelector(),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: meses.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final mes = meses[i];
            final resumen = resumenesPorMes[mes];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                '${_mesesEs[mes - 1]} $_anioSeleccionado',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textoPrincipal,
                ),
              ),
              trailing: resumen != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf,
                            size: 18, color: AppTheme.azulMedio),
                        if (resumen.archivo != null &&
                            resumen.archivo!.startsWith('http')) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                launchUrl(Uri.parse(resumen.archivo!)),
                            child: const Icon(Icons.download,
                                size: 18, color: AppTheme.azulMedio),
                          ),
                        ],
                        if (widget.esAdmin) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () async {
                              final ok = await showDialog<bool>(
                                context: ctx,
                                builder: (_) => AlertDialog(
                                  title: const Text('Eliminar resumen'),
                                  content: Text(
                                      '¿Eliminar el resumen de ${_mesesEs[mes - 1]} $_anioSeleccionado?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Eliminar',
                                            style: TextStyle(
                                                color: AppTheme.rojoGasto))),
                                  ],
                                ),
                              );
                              if (ok == true && ctx.mounted) {
                                final uid = ctx
                                    .read<AuthProvider>()
                                    .currentUser
                                    ?.uid ??
                                    '';
                                await ctx
                                    .read<CuentaBancariaProvider>()
                                    .eliminarMovimiento(resumen.id, uid);
                              }
                            },
                            child: const Icon(Icons.delete_outline,
                                size: 18, color: AppTheme.rojoGasto),
                          ),
                        ],
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.textoSecundario.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Sin resumen',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textoSecundario,
                        ),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFecha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOrdenSelector(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DatePickerButton(
                label: 'Desde',
                fecha: _desde,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _desde ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() { _desde = d; _pagina = 0; });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DatePickerButton(
                label: 'Hasta',
                fecha: _hasta,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _hasta ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() { _hasta = d; _pagina = 0; });
                },
              ),
            ),
            if (_desde != null || _hasta != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () =>
                    setState(() { _desde = null; _hasta = null; _pagina = 0; }),
                tooltip: 'Limpiar filtros',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Builder(builder: (_) {
          final filtrados = _filtradoFecha;
          final total = filtrados.length;
          if (total == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Sin movimientos en el período seleccionado',
                  style: TextStyle(
                      color: AppTheme.textoSecundario, fontSize: 13),
                ),
              ),
            );
          }
          final totalPaginas = (total / _porPagina).ceil();
          final inicio = _pagina * _porPagina;
          final fin = (inicio + _porPagina).clamp(0, total);
          final pagina = filtrados.sublist(inicio, fin);

          return Column(
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pagina.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _MovimientoTile(
                    movimiento: pagina[i], esAdmin: widget.esAdmin),
              ),
              if (totalPaginas > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _pagina > 0
                          ? () => setState(() => _pagina--)
                          : null,
                    ),
                    Text('${_pagina + 1} / $totalPaginas',
                        style: const TextStyle(fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _pagina < totalPaginas - 1
                          ? () => setState(() => _pagina++)
                          : null,
                    ),
                  ],
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$total movimiento${total == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: AppTheme.textoSecundario, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

}

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = fecha != null
        ? '${fecha!.day.toString().padLeft(2, '0')}/'
            '${fecha!.month.toString().padLeft(2, '0')}/'
            '${fecha!.year}'
        : label;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today, size: 14),
      label: Text(texto, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        foregroundColor:
            fecha != null ? AppTheme.azulMedio : AppTheme.textoSecundario,
        side: BorderSide(
          color: fecha != null
              ? AppTheme.azulMedio
              : AppTheme.textoSecundario.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ── Caja Chica ────────────────────────────────────────────────────────────────

class _CajaChicaSection extends StatefulWidget {
  const _CajaChicaSection({required this.puedeActualizar});
  final bool puedeActualizar;

  @override
  State<_CajaChicaSection> createState() => _CajaChicaSectionState();
}

class _CajaChicaSectionState extends State<_CajaChicaSection> {
  final _formKey = GlobalKey<FormState>();
  final _saldoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  bool _saldoInicializado = false;

  @override
  void dispose() {
    _saldoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  void _mostrarDepositoBancario(double saldoCaja) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ModalDepositoBancario(saldoCajaChica: saldoCaja),
    );
  }

  Future<void> _actualizar() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<CuentaBancariaProvider>();
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    final nuevoSaldo = double.tryParse(
      _saldoCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    if (nuevoSaldo == null) return;
    final obs = _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim();
    await provider.actualizarCajaChica(nuevoSaldo, uid, observaciones: obs);
    if (!mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error!),
        backgroundColor: AppTheme.rojoGasto,
      ));
    } else {
      _obsCtrl.clear();
      setState(() => _saldoInicializado = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Caja chica actualizada correctamente'),
        backgroundColor: AppTheme.verdeIngreso,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CuentaBancariaProvider>();
    final cajaChica = provider.cajaChica;
    final saldo = (cajaChica?['saldoActual'] as num? ?? 0).toDouble();
    final fechaTs = cajaChica?['fechaActualizacion'];
    final fecha = fechaTs is Timestamp ? fechaTs.toDate() : null;

    if (!_saldoInicializado && !provider.isLoading) {
      _saldoCtrl.text = _doubleToArgentino(saldo);
      _saldoInicializado = true;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.wallet, size: 20, color: AppTheme.verdeTeal),
                const SizedBox(width: 8),
                const Text(
                  'Caja Chica',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textoPrincipal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(child: _buildSaldoWidget(saldo)),
            const SizedBox(height: 4),
            if (fecha != null)
              Center(
                child: Text(
                  'Actualizado: ${_fmtFecha(fecha)}',
                  style: const TextStyle(
                      color: AppTheme.textoSecundario, fontSize: 11),
                ),
              ),
            if (widget.puedeActualizar) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _mostrarDepositoBancario(saldo),
                icon: const Icon(Icons.account_balance, size: 18),
                label: const Text('Depositar al banco'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.azulMedio,
                  side: const BorderSide(color: AppTheme.azulMedio),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Actualizar caja chica',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _saldoCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_MontoArgentinoFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Nuevo saldo *',
                        prefixText: '\$ ',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Ingresá el saldo';
                        final parsed = double.tryParse(
                            v.replaceAll('.', '').replaceAll(',', '.'));
                        if (parsed == null) return 'Ingresá un valor válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _obsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones (opcional)',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: provider.isSaving ? null : _actualizar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.verdeTeal,
                        foregroundColor: AppTheme.blanco,
                      ),
                      child: provider.isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.blanco),
                            )
                          : const Text('Actualizar'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            if (provider.movimientosCajaChica.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    'Sin movimientos registrados',
                    style: TextStyle(
                        color: AppTheme.textoSecundario, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.movimientosCajaChica.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _MovimientoCajaChicaTile(
                    movimiento: provider.movimientosCajaChica[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _MovimientoCajaChicaTile extends StatefulWidget {
  const _MovimientoCajaChicaTile({required this.movimiento});
  final Map<String, dynamic> movimiento;

  @override
  State<_MovimientoCajaChicaTile> createState() =>
      _MovimientoCajaChicaTileState();
}

class _MovimientoCajaChicaTileState extends State<_MovimientoCajaChicaTile> {
  bool _expandido = false;

  String _fmt(dynamic v) {
    if (v == null) return '-';
    return '\$${_doubleToArgentino((v as num).toDouble())}';
  }

  String _fmtFecha(dynamic ts) {
    if (ts == null) return '-';
    final d = ts is Timestamp ? ts.toDate() : ts as DateTime;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final mov = widget.movimiento;
    final obs = mov['observaciones'] as String?;
    final tieneObs = obs != null && obs.isNotEmpty;
    final usuarioId = mov['usuarioId'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 12, top: 2),
                child: Icon(Icons.wallet_outlined,
                    size: 20, color: AppTheme.verdeTeal),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Actualización de caja chica',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textoPrincipal,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_fmt(mov['saldoAnterior']),
                                style: const TextStyle(
                                    color: AppTheme.textoSecundario,
                                    fontSize: 12)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.arrow_forward,
                                  size: 12, color: AppTheme.verdeTeal),
                            ),
                            Text(_fmt(mov['saldoNuevo']),
                                style: const TextStyle(
                                  color: AppTheme.textoPrincipal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      _fmtFecha(mov['fechaCreacion']),
                      style: const TextStyle(
                          color: AppTheme.textoSecundario, fontSize: 11),
                    ),
                    if (usuarioId.isNotEmpty)
                      NombreUsuarioWidget(
                        usuarioId: usuarioId,
                        prefijo: 'Por: ',
                        style: const TextStyle(
                            color: AppTheme.textoSecundario, fontSize: 11),
                      ),
                  ],
                ),
              ),
              if (tieneObs)
                GestureDetector(
                  onTap: () => setState(() => _expandido = !_expandido),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Icon(
                      _expandido ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppTheme.textoSecundario,
                    ),
                  ),
                ),
            ],
          ),
          if (tieneObs && _expandido)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.celesteFondo,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  obs,
                  style: const TextStyle(
                      color: AppTheme.textoSecundario, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MovimientoTile extends StatefulWidget {
  const _MovimientoTile(
      {required this.movimiento, required this.esAdmin});

  final MovimientoBancario movimiento;
  final bool esAdmin;

  @override
  State<_MovimientoTile> createState() => _MovimientoTileState();
}

class _MovimientoTileState extends State<_MovimientoTile> {
  bool _expandido = false;

  String _fmt(double? v) => v != null ? '\$${_doubleToArgentino(v)}' : '-';

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  Future<void> _confirmarEliminar(BuildContext context) async {
    final mov = widget.movimiento;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: Text(mov.tipo == 'resumen_mensual'
            ? '¿Eliminar el resumen ${mov.periodo ?? ''}?'
            : '¿Eliminar esta actualización de saldo?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: AppTheme.rojoGasto))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
      await context.read<CuentaBancariaProvider>().eliminarMovimiento(mov.id, uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mov = widget.movimiento;
    final esResumen = mov.tipo == 'resumen_mensual';
    final tieneDescarga =
        mov.archivo != null && mov.archivo!.startsWith('http');
    final tieneObs =
        mov.observaciones != null && mov.observaciones!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 2),
                child: Icon(
                  esResumen
                      ? Icons.description_outlined
                      : Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: AppTheme.azulMedio,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            esResumen
                                ? 'Resumen ${mov.periodo ?? ''}'
                                : 'Actualización de saldo',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textoPrincipal,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmt(mov.saldoAnterior),
                              style: const TextStyle(
                                  color: AppTheme.textoSecundario,
                                  fontSize: 12),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.arrow_forward,
                                  size: 12, color: AppTheme.azulMedio),
                            ),
                            Text(
                              _fmt(mov.saldoNuevo),
                              style: const TextStyle(
                                color: AppTheme.textoPrincipal,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      _fmtFecha(mov.fechaCreacion),
                      style: const TextStyle(
                          color: AppTheme.textoSecundario, fontSize: 11),
                    ),
                    if (mov.usuarioId.isNotEmpty)
                      NombreUsuarioWidget(
                        usuarioId: mov.usuarioId,
                        prefijo: 'Por: ',
                        style: const TextStyle(
                            color: AppTheme.textoSecundario, fontSize: 11),
                      ),
                  ],
                ),
              ),
              if (tieneDescarga)
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse(mov.archivo!)),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8, top: 2),
                    child: Icon(Icons.download,
                        size: 18, color: AppTheme.azulMedio),
                  ),
                ),
              if (tieneObs)
                GestureDetector(
                  onTap: () => setState(() => _expandido = !_expandido),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Icon(
                      _expandido ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppTheme.textoSecundario,
                    ),
                  ),
                ),
              if (widget.esAdmin)
                GestureDetector(
                  onTap: () => _confirmarEliminar(context),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4, top: 2),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: AppTheme.rojoGasto),
                  ),
                ),
            ],
          ),
          if (tieneObs && _expandido)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.celesteFondo,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  mov.observaciones!,
                  style: const TextStyle(
                    color: AppTheme.textoSecundario,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Modal: Depositar al banco ─────────────────────────────────────────────────

class _ModalDepositoBancario extends StatefulWidget {
  const _ModalDepositoBancario({required this.saldoCajaChica});
  final double saldoCajaChica;

  @override
  State<_ModalDepositoBancario> createState() => _ModalDepositoBancarioState();
}

class _ModalDepositoBancarioState extends State<_ModalDepositoBancario> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoCtrl;
  final _obsCtrl = TextEditingController();
  String? _archivoNombre;
  Uint8List? _archivoBytes;

  @override
  void initState() {
    super.initState();
    _montoCtrl = TextEditingController(
        text: _doubleToArgentino(widget.saldoCajaChica));
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) return;
    setState(() {
      _archivoNombre = file.name;
      _archivoBytes = file.bytes;
    });
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<CuentaBancariaProvider>();
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    final messenger = ScaffoldMessenger.of(context);
    final archivoBytes = _archivoBytes;
    final archivoNombre = _archivoNombre;

    final monto = double.tryParse(
      _montoCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    if (monto == null || monto <= 0) return;
    final obs = _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim();

    String? comprobanteUrl;
    if (archivoBytes != null && archivoNombre != null) {
      final now = DateTime.now();
      try {
        comprobanteUrl = await StorageService().subirComprobante(
          'depositos_banco/${now.year}/${now.month.toString().padLeft(2, '0')}',
          archivoBytes,
          archivoNombre,
        );
      } catch (_) {}
    }

    final obsFinal = comprobanteUrl != null
        ? '${obs ?? 'Depósito desde Caja Chica'} [comprobante adjunto]'
        : obs;

    await provider.depositarACuentaBancaria(monto, uid, observaciones: obsFinal);

    if (!mounted) return;
    if (provider.error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(provider.error!),
        backgroundColor: AppTheme.rojoGasto,
      ));
    } else {
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
        content: Text('Depósito realizado correctamente'),
        backgroundColor: AppTheme.verdeIngreso,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CuentaBancariaProvider>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 24, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: AppTheme.azulMedio),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Depositar al banco',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textoPrincipal,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _montoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_MontoArgentinoFormatter()],
              decoration: const InputDecoration(
                labelText: 'Monto a depositar *',
                prefixText: '\$ ',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresá el monto';
                final parsed = double.tryParse(
                    v.replaceAll('.', '').replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) {
                  return 'Ingresá un monto válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _obsCtrl,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
                hintText: 'ej: Depósito de recaudación de kermés',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            if (_archivoNombre != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.celesteFondo,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.celesteBorde),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined,
                        size: 18, color: AppTheme.azulMedio),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_archivoNombre!,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    GestureDetector(
                      onTap: () => setState(
                          () => _archivoNombre = _archivoBytes = null),
                      child: const Icon(Icons.close,
                          size: 18, color: AppTheme.textoSecundario),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('Adjuntar comprobante (opcional)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.azulMedio,
                side: const BorderSide(color: AppTheme.azulMedio),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.verdeTeal,
                foregroundColor: AppTheme.blanco,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: provider.isSaving ? null : _confirmar,
              child: provider.isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.blanco),
                    )
                  : const Text('Confirmar depósito',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

