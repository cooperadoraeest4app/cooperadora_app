import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/nombre_usuario_widget.dart';
import '../../domain/models/tarifa_cuota.dart';
import '../../domain/models/tipo_cuota.dart';
import '../providers/cuota_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtMonto(double m) =>
    NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2)
        .format(m);

String _fmtFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ── TarifasScreen ─────────────────────────────────────────────────────────────

class TarifasScreen extends StatelessWidget {
  const TarifasScreen({super.key});

  void _abrirModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ModalTarifa(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuotaProv = context.watch<CuotaProvider>();
    final tipos = cuotaProv.tiposCuota;
    final tarifas = cuotaProv.tarifas;

    final Map<String, List<TarifaCuota>> grupos = {};
    for (final t in tarifas) {
      grupos.putIfAbsent(t.tipoCuotaId, () => []).add(t);
    }

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
        title: const Text('Tarifas'),
      ),
      body: tipos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: tipos
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TarifaTipoCard(
                          tipo: t,
                          tarifas: grupos[t.id] ?? [],
                        ),
                      ))
                  .toList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirModal(context),
        backgroundColor: AppTheme.verdeTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Actualizar tarifa'),
      ),
    );
  }
}

// ── _TarifaTipoCard ───────────────────────────────────────────────────────────

class _TarifaTipoCard extends StatefulWidget {
  const _TarifaTipoCard({required this.tipo, required this.tarifas});
  final TipoCuota tipo;
  final List<TarifaCuota> tarifas;

  @override
  State<_TarifaTipoCard> createState() => _TarifaTipoCardState();
}

class _TarifaTipoCardState extends State<_TarifaTipoCard> {
  bool _historialExpandido = false;

  @override
  Widget build(BuildContext context) {
    final vigente = widget.tarifas.isNotEmpty ? widget.tarifas.first : null;
    final historial =
        widget.tarifas.length > 1 ? widget.tarifas.sublist(1) : <TarifaCuota>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.tipo.nombre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textoPrincipal,
              ),
            ),
            const SizedBox(height: 12),
            vigente == null
                ? const Text(
                    'Sin tarifa registrada',
                    style: TextStyle(color: AppTheme.textoSecundario),
                  )
                : _TarifaRow(tarifa: vigente, esVigente: true),
            if (historial.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () =>
                    setState(() => _historialExpandido = !_historialExpandido),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Text(
                        'Historial',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textoSecundario,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _historialExpandido
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16,
                        color: AppTheme.textoSecundario,
                      ),
                    ],
                  ),
                ),
              ),
              if (_historialExpandido) ...[
                const SizedBox(height: 4),
                ...historial.map((t) => _TarifaHistorialItem(tarifa: t)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TarifaRow extends StatelessWidget {
  const _TarifaRow({required this.tarifa, required this.esVigente});
  final TarifaCuota tarifa;
  final bool esVigente;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _fmtMonto(tarifa.monto),
              style: TextStyle(
                fontSize: esVigente ? 20 : 14,
                fontWeight:
                    esVigente ? FontWeight.w700 : FontWeight.w400,
                color: esVigente
                    ? AppTheme.verdeIngreso
                    : AppTheme.textoSecundario,
              ),
            ),
          ),
          Text(
            'Desde ${_fmtFecha(tarifa.vigenciaDesde)}',
            style: TextStyle(
              fontSize: 12,
              color: esVigente
                  ? AppTheme.textoPrincipal
                  : AppTheme.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _TarifaHistorialItem ──────────────────────────────────────────────────────

class _TarifaHistorialItem extends StatelessWidget {
  const _TarifaHistorialItem({required this.tarifa});
  final TarifaCuota tarifa;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _fmtMonto(tarifa.monto),
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textoSecundario,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Desde ${_fmtFecha(tarifa.vigenciaDesde)}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario),
              ),
              NombreUsuarioWidget(
                usuarioId: tarifa.usuarioId,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _ModalTarifa ──────────────────────────────────────────────────────────────

class _ModalTarifa extends StatefulWidget {
  const _ModalTarifa();

  @override
  State<_ModalTarifa> createState() => _ModalTarifaState();
}

class _ModalTarifaState extends State<_ModalTarifa> {
  final _form = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  String? _tipoCuotaId;
  DateTime _vigenciaDesde = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final monto = double.tryParse(
        _montoCtrl.text.replaceAll('.', '').replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un monto válido')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final uid =
          context.read<AuthProvider>().currentUser?.uid ?? '';
      final tarifa = TarifaCuota(
        id: '',
        tipoCuotaId: _tipoCuotaId!,
        moneda: 'ARS',
        usuarioId: uid,
        monto: monto,
        vigenciaDesde: _vigenciaDesde,
      );
      await context.read<CuotaProvider>().actualizarTarifa(tarifa);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipos = context.watch<CuotaProvider>().tiposCuota;

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
              const Text(
                'Actualizar tarifa',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _tipoCuotaId,
                decoration:
                    const InputDecoration(labelText: 'Tipo de cuota *'),
                items: tipos
                    .map((t) => DropdownMenuItem(
                        value: t.id, child: Text(t.nombre)))
                    .toList(),
                onChanged: (v) => setState(() => _tipoCuotaId = v),
                validator: (v) => v == null ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _montoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Monto *',
                  prefixText: '\$ ',
                  helperText: 'Ingresá el monto mensual (ej: 5000)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _vigenciaDesde,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _vigenciaDesde = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Válido desde'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmtFecha(_vigenciaDesde)),
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppTheme.azulMedio),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.verdeTeal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _saving ? null : _guardar,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Guardar tarifa'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
