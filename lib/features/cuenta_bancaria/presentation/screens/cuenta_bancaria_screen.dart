import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/cuenta_bancaria.dart';
import '../providers/cuenta_bancaria_provider.dart';

String _doubleToArgentino(double v) {
  final format = v == v.truncateToDouble()
      ? NumberFormat('#,##0', 'es_AR')
      : NumberFormat('#,##0.##', 'es_AR');
  return format.format(v);
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

class _CuentaBancariaScreenState extends State<CuentaBancariaScreen> {
  // Formulario de configuración
  final _setupFormKey = GlobalKey<FormState>();
  final _bancoCtrl = TextEditingController();
  String? _tipoCuenta;
  final _cbuCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();

  // Formulario de actualizar saldo
  final _saldoFormKey = GlobalKey<FormState>();
  final _saldoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  bool _saldoInicializado = false;

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
    _bancoCtrl.dispose();
    _cbuCtrl.dispose();
    _aliasCtrl.dispose();
    _saldoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _configurarCuenta() async {
    if (!_setupFormKey.currentState!.validate()) return;
    final provider = context.read<CuentaBancariaProvider>();
    final cuenta = CuentaBancaria(
      id: 'cuenta_principal',
      banco: _bancoCtrl.text.trim(),
      tipoCuenta: _tipoCuenta!,
      cbu: _cbuCtrl.text.trim(),
      alias: _aliasCtrl.text.trim().isEmpty ? null : _aliasCtrl.text.trim(),
      saldoActual: 0,
      activa: true,
      fechaActualizacion: DateTime.now(),
    );
    await provider.crearCuenta(cuenta);
    if (!mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error!),
        backgroundColor: AppTheme.rojoGasto,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cuenta configurada correctamente'),
        backgroundColor: AppTheme.verdeIngreso,
      ));
      setState(() => _saldoInicializado = false);
    }
  }

  Future<void> _actualizarSaldo() async {
    if (!_saldoFormKey.currentState!.validate()) return;
    final provider = context.read<CuentaBancariaProvider>();
    final auth = context.read<AuthProvider>();
    final nuevoSaldo = double.tryParse(
      _saldoCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    if (nuevoSaldo == null) return;
    await provider.actualizarSaldo(
      nuevoSaldo,
      auth.currentUser?.uid ?? '',
      observaciones: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
    );
    if (!mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error!),
        backgroundColor: AppTheme.rojoGasto,
      ));
    } else {
      _obsCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Saldo actualizado correctamente'),
        backgroundColor: AppTheme.verdeIngreso,
      ));
    }
  }

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
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : cuenta == null
              ? _buildSinCuenta(esAdmin, provider.isSaving)
              : _buildConCuenta(cuenta, esAdmin, provider),
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
            const Text(
              'Configurar cuenta bancaria',
              style: TextStyle(
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
                  : const Text('Configurar cuenta'),
            ),
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
    final resumenes = provider.movimientos
        .where((m) => m.tipo == 'resumen_mensual')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoCuentaCard(cuenta: cuenta),
          const SizedBox(height: 16),
          if (esAdmin) ...[
            _ActualizarSaldoCard(
              formKey: _saldoFormKey,
              saldoCtrl: _saldoCtrl,
              obsCtrl: _obsCtrl,
              isSaving: provider.isSaving,
              onActualizar: _actualizarSaldo,
            ),
            const SizedBox(height: 16),
          ],
          _ResumenesBancariosCard(
            resumenes: resumenes,
            esAdmin: esAdmin,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Tarjeta info de cuenta ────────────────────────────────────────────────────

class _InfoCuentaCard extends StatelessWidget {
  const _InfoCuentaCard({required this.cuenta});

  final CuentaBancaria cuenta;

  @override
  Widget build(BuildContext context) {
    final saldo = cuenta.saldoActual;
    final saldoFormat = saldo == saldo.truncateToDouble()
        ? NumberFormat('#,##0', 'es_AR')
        : NumberFormat('#,##0.##', 'es_AR');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.account_balance,
                size: 36, color: AppTheme.azulMedio),
            const SizedBox(height: 12),
            Text(
              cuenta.banco,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textoPrincipal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              cuenta.tipoCuenta,
              style: const TextStyle(
                  color: AppTheme.textoSecundario, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _InfoRow(label: 'CBU', valor: cuenta.cbu),
            if (cuenta.alias != null && cuenta.alias!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _InfoRow(label: 'Alias', valor: cuenta.alias!),
            ],
            const SizedBox(height: 20),
            const Text(
              'Saldo actual',
              style: TextStyle(
                color: AppTheme.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${saldoFormat.format(saldo)}',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: saldo >= 0 ? AppTheme.verdeIngreso : AppTheme.rojoGasto,
              ),
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

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
              color: AppTheme.textoSecundario, fontSize: 13),
        ),
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

// ── Actualizar saldo ──────────────────────────────────────────────────────────

class _ActualizarSaldoCard extends StatelessWidget {
  const _ActualizarSaldoCard({
    required this.formKey,
    required this.saldoCtrl,
    required this.obsCtrl,
    required this.isSaving,
    required this.onActualizar,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController saldoCtrl;
  final TextEditingController obsCtrl;
  final bool isSaving;
  final VoidCallback onActualizar;

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
              ElevatedButton(
                onPressed: isSaving ? null : onActualizar,
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.blanco),
                      )
                    : const Text('Actualizar saldo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Resúmenes bancarios ───────────────────────────────────────────────────────

class _ResumenesBancariosCard extends StatelessWidget {
  const _ResumenesBancariosCard({
    required this.resumenes,
    required this.esAdmin,
  });

  final List resumenes;
  final bool esAdmin;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Resúmenes bancarios',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textoPrincipal,
                  ),
                ),
                const Spacer(),
                if (esAdmin)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.azulMedio),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Próximamente disponible cuando se configure Firebase Storage',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Subir'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (resumenes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No hay resúmenes cargados',
                    style:
                        TextStyle(color: AppTheme.textoSecundario, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: resumenes.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final mov = resumenes[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined,
                        color: AppTheme.azulMedio),
                    title: Text(
                      mov.periodo ?? 'Sin período',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: mov.observaciones != null
                        ? Text(mov.observaciones!,
                            style: const TextStyle(fontSize: 12))
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.download_outlined,
                          color: AppTheme.azulMedio),
                      tooltip: 'Descargar',
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Próximamente disponible cuando se configure Firebase Storage',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
