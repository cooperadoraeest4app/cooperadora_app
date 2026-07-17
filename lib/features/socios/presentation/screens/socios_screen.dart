import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import '../../../home/presentation/screens/home_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/domain/models/persona.dart';
import '../../../admin/presentation/providers/curso_provider.dart';
import '../../../admin/presentation/providers/metodo_pago_provider.dart';
import '../../../admin/presentation/providers/persona_provider.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../../shared/widgets/numero_cheque_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/socio.dart';
import '../../domain/models/subtipo_socio.dart';
import '../../domain/models/cuota.dart';
import '../../domain/models/tarifa_cuota.dart';
import '../providers/cuota_provider.dart';
import '../providers/socio_provider.dart';
import 'socio_detalle_screen.dart';
import 'tarifas_screen.dart';
import '../../../../shared/utils/metodo_pago_icon.dart';
import '../../../../shared/widgets/app_drawer.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatMonto(dynamic monto) {
  final n = (monto as num? ?? 0).toDouble();
  final fmt = n == n.truncateToDouble()
      ? NumberFormat('#,##0', 'es_AR')
      : NumberFormat('#,##0.##', 'es_AR');
  return '\$${fmt.format(n)}';
}

Color _colorTipo(String tipoSocio) => switch (tipoSocio) {
      'activo' => AppTheme.azulMedio,
      'honorario' => const Color(0xFF8E44AD),
      'adherente' => const Color(0xFFE67E22),
      _ => AppTheme.textoSecundario,
    };

// ── _ResumenData ──────────────────────────────────────────────────────────────

class _ResumenData {
  final Map<String, double> deudas;
  final double deudaTotal;
  final int alDia;
  final int enDeuda;

  const _ResumenData({
    required this.deudas,
    required this.deudaTotal,
    required this.alDia,
    required this.enDeuda,
  });
}

// ── SociosScreen ──────────────────────────────────────────────────────────────

class SociosScreen extends StatefulWidget {
  const SociosScreen({super.key});

  @override
  State<SociosScreen> createState() => _SociosScreenState();
}

class _SociosScreenState extends State<SociosScreen> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';
  String _filtroTipo = 'todos';
  String _filtroEstado = 'todos';
  _ResumenData? _resumen;
  bool _cargandoResumen = false;
  bool _resumenSolicitado = false;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarResumen(List<Socio> socios) async {
    if (_cargandoResumen || socios.isEmpty) return;
    setState(() => _cargandoResumen = true);
    try {
      final db = FirebaseFirestore.instance;

      final tiposSnap = await db.collection('tipos_cuota').get();
      final tiposAnuales = tiposSnap.docs
          .where((d) => (d.data()['nombre'] as String? ?? '')
              .toLowerCase()
              .contains('anual'))
          .map((d) => d.id)
          .toSet();

      final tarifasSnap = await db.collection('tarifas_cuota').get();
      final tarifasMensuales = tarifasSnap.docs
          .where((d) => !tiposAnuales
              .contains(d.data()['tipoCuotaId'] as String? ?? ''))
          .map((d) => TarifaCuota.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) => a.vigenciaDesde.compareTo(b.vigenciaDesde));

      final socioIds = socios.map((s) => s.id).toList();
      final Map<String, List<Map<String, dynamic>>> cuotasPorSocio = {};
      for (var i = 0; i < socioIds.length; i += 30) {
        final chunk =
            socioIds.sublist(i, (i + 30).clamp(0, socioIds.length));
        final snap = await db
            .collection('cuotas')
            .where('socioId', whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final sid = data['socioId'] as String? ?? '';
          cuotasPorSocio.putIfAbsent(sid, () => []).add(data);
        }
      }

      final ahora = DateTime.now();
      final mesActual = DateTime(ahora.year, ahora.month);
      final Map<String, double> deudas = {};

      for (final socio in socios) {
        final mesIngreso =
            DateTime(socio.fechaIngreso.year, socio.fechaIngreso.month);
        if (!mesIngreso.isBefore(mesActual) || tarifasMensuales.isEmpty) {
          deudas[socio.id] = 0.0;
          continue;
        }

        final cuotas = cuotasPorSocio[socio.id] ?? [];
        final periodosPagados = <String>{};

        for (final data in cuotas) {
          final tipoCuotaId = data['tipoCuotaId'] as String? ?? '';
          final tipoCuotaStr = data['tipoCuota'] as String?;
          final esAnual = tiposAnuales.contains(tipoCuotaId) ||
              tipoCuotaStr == 'anual';
          final periodo = data['periodo'] as String?;
          final fechaPagoRaw = data['fechaPago'];

          if (esAnual) {
            if (fechaPagoRaw != null) {
              final fechaPago = (fechaPagoRaw as Timestamp).toDate();
              for (var j = 0; j < 12; j++) {
                final m = DateTime(fechaPago.year, fechaPago.month + j);
                periodosPagados.add(
                    '${m.month.toString().padLeft(2, '0')}/${m.year}');
              }
            }
          } else if (periodo != null) {
            periodosPagados.add(periodo);
          }
        }

        double deuda = 0.0;
        var mes =
            DateTime(socio.fechaIngreso.year, socio.fechaIngreso.month);
        while (!mes.isAfter(mesActual)) {
          final periodoStr =
              '${mes.month.toString().padLeft(2, '0')}/${mes.year}';
          if (!periodosPagados.contains(periodoStr)) {
            final tarifa = _tarifaParaMes(tarifasMensuales, mes);
            if (tarifa != null) deuda += tarifa.monto;
          }
          mes = DateTime(mes.year, mes.month + 1);
        }
        deudas[socio.id] = deuda;
      }

      final alDia = deudas.values.where((d) => d <= 0).length;
      final enDeuda = deudas.values.where((d) => d > 0).length;
      final deudaTotal =
          deudas.values.fold(0.0, (acc, d) => acc + (d > 0 ? d : 0));

      if (mounted) {
        setState(() {
          _resumen = _ResumenData(
            deudas: deudas,
            deudaTotal: deudaTotal,
            alDia: alDia,
            enDeuda: enDeuda,
          );
          _cargandoResumen = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoResumen = false);
    }
  }

  TarifaCuota? _tarifaParaMes(List<TarifaCuota> tarifas, DateTime mes) {
    TarifaCuota? resultado;
    for (final t in tarifas) {
      final vigencia =
          DateTime(t.vigenciaDesde.year, t.vigenciaDesde.month);
      if (!vigencia.isAfter(mes)) resultado = t;
    }
    return resultado;
  }

  void _abrirModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ModalSocio(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<SocioProvider>();
    final personaProvider = context.watch<PersonaProvider>();
    final puedeGestionar = auth.esAdmin || auth.esEditor;

    if (!provider.isLoading &&
        !_resumenSolicitado &&
        provider.todos.isNotEmpty) {
      _resumenSolicitado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargarResumen(provider.todos);
      });
    }

    var socios = provider.todos;
    if (_filtroTipo != 'todos') {
      socios = socios.where((s) => s.tipoSocio == _filtroTipo).toList();
    }
    if (_filtroEstado != 'todos' && _resumen != null) {
      socios = socios.where((s) {
        final d = _resumen!.deudas[s.id] ?? 0.0;
        return _filtroEstado == 'al_dia' ? d <= 0 : d > 0;
      }).toList();
    }
    if (_busqueda.isNotEmpty) {
      socios = socios.where((s) {
        final persona = personaProvider.todas
            .where((p) => p.id == s.personaId)
            .firstOrNull;
        final texto =
            '${s.numeroSocio} ${persona?.nombreCompleto ?? ''} ${persona?.dni ?? ''}'
                .toLowerCase();
        return texto.contains(_busqueda);
      }).toList();
    }

    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    return Scaffold(
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
            Container(
                width: 1,
                height: 20,
                color: Colors.white.withValues(alpha: 0.3)),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: Icon(Icons.home,
                    color: Colors.white.withValues(alpha: 0.8), size: 20),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                ),
              ),
            ),
            Container(
                width: 1,
                height: 20,
                color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Socios',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [AccionAuthWidget()],
      ),
      body: Column(
        children: [
          if (auth.esAdmin) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TarifasScreen())),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.price_change,
                        color: AppTheme.verdeTeal, size: 20),
                    const SizedBox(width: 12),
                    const Text('Tarifas de cuota',
                        style: TextStyle(
                            color: AppTheme.textoPrincipal,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.textoSecundario),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
          ],
          // Tarifas vigentes
          const _SeccionTarifas(),
          // Header chips
          Container(
            color: AppTheme.celesteFondo,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _ResumenChip(
                    titulo: 'Total',
                    valor: '${provider.todos.length}',
                    color: AppTheme.azulMedio,
                    loading: false,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ResumenChip(
                    titulo: 'Al día',
                    valor: '${_resumen?.alDia ?? 0}',
                    color: AppTheme.verdeIngreso,
                    loading: _cargandoResumen && _resumen == null,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ResumenChip(
                    titulo: 'En deuda',
                    valor: '${_resumen?.enDeuda ?? 0}',
                    color: AppTheme.amarilloAlerta,
                    loading: _cargandoResumen && _resumen == null,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ResumenChip(
                    titulo: 'Deuda total',
                    valor: _resumen != null
                        ? fmt.format(_resumen!.deudaTotal)
                        : '\$0',
                    color: AppTheme.rojoGasto,
                    loading: _cargandoResumen && _resumen == null,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Filters: tipo + estado cuota
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filtroTipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: ['todos', 'activo', 'adherente', 'honorario']
                        .map((tipo) => DropdownMenuItem(
                              value: tipo,
                              child: Text(tipo == 'todos'
                                  ? 'Todos los tipos'
                                  : tipo[0].toUpperCase() + tipo.substring(1)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _filtroTipo = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filtroEstado,
                    decoration: const InputDecoration(
                      labelText: 'Estado cuota',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(value: 'al_dia', child: Text('Al día')),
                      DropdownMenuItem(
                          value: 'en_deuda', child: Text('En deuda')),
                    ],
                    onChanged: (v) => setState(() => _filtroEstado = v!),
                  ),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _busquedaController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, N° de socio o DNI…',
                prefixIcon: const Icon(Icons.search,
                    color: AppTheme.textoSecundario),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _busquedaController.clear();
                          setState(() => _busqueda = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                filled: true,
                fillColor: Colors.white,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null && provider.todos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Error al cargar socios:\n${provider.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppTheme.rojoGasto),
                          ),
                        ),
                      )
                    : socios.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                _busqueda.isNotEmpty
                                    ? 'Sin resultados para "$_busqueda"'
                                    : 'No hay socios que coincidan con los filtros.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppTheme.textoSecundario),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              setState(() {
                                _resumen = null;
                                _resumenSolicitado = false;
                              });
                              _resumenSolicitado = true;
                              await _cargarResumen(provider.todos);
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 80),
                              itemCount: socios.length,
                              itemBuilder: (_, i) => _SocioCard(
                                socio: socios[i],
                                tipoNombre: provider
                                    .nombreTipo(socios[i].tipoSocio),
                                nombrePersona: personaProvider
                                    .nombreCompleto(
                                        socios[i].personaId),
                                puedeGestionar: puedeGestionar,
                                deuda:
                                    _resumen?.deudas[socios[i].id],
                              ),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: puedeGestionar
          ? FloatingActionButton(
              onPressed: _abrirModal,
              backgroundColor: AppTheme.verdeTeal,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ── _ResumenChip ──────────────────────────────────────────────────────────────

class _ResumenChip extends StatelessWidget {
  const _ResumenChip({
    required this.titulo,
    required this.valor,
    required this.color,
    required this.loading,
  });
  final String titulo;
  final String valor;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          loading
              ? SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color))
              : Text(valor,
                  style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── _SocioCard ────────────────────────────────────────────────────────────────

class _SocioCard extends StatelessWidget {
  const _SocioCard({
    required this.socio,
    required this.tipoNombre,
    required this.nombrePersona,
    required this.puedeGestionar,
    this.deuda,
  });

  final Socio socio;
  final String tipoNombre;
  final String nombrePersona;
  final bool puedeGestionar;
  final double? deuda; // null = loading, 0 = al día, >0 = en deuda

  @override
  Widget build(BuildContext context) {
    final s = socio;
    final color = _colorTipo(s.tipoSocio);
    final enDeuda = deuda != null && deuda! > 0;
    final alDia = deuda != null && deuda! <= 0;
    final fmt = NumberFormat.currency(
        locale: 'es_AR', symbol: '\$', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SocioDetalleScreen(socio: s)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'N° ${s.numeroSocio}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textoSecundario,
                          ),
                        ),
                        Text(
                          nombrePersona,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.textoPrincipal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Chip(
                    label: s.activo ? 'Habilitado' : 'Inhabilitado',
                    color: s.activo
                        ? AppTheme.verdeIngreso
                        : AppTheme.textoSecundario,
                  ),
                  if (puedeGestionar) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit, size: 18),
                        color: AppTheme.azulMedio,
                        tooltip: 'Ver / editar',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SocioDetalleScreen(socio: s),
                          ),
                        ),
                      ),
                    ),
                    if (enDeuda)
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.payment, size: 18),
                          color: AppTheme.verdeTeal,
                          tooltip: 'Registrar pago',
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            builder: (_) => _ModalPagoRapido(
                              socio: s,
                              nombre: nombrePersona,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Chip(label: tipoNombre, color: color),
                  if (deuda == null)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (alDia)
                    const _Chip(
                        label: 'Al día', color: AppTheme.verdeIngreso)
                  else
                    _Chip(
                      label: 'Debe ${fmt.format(deuda)}',
                      color: AppTheme.amarilloAlerta,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── _ModalPagoRapido ──────────────────────────────────────────────────────────

class _ModalPagoRapido extends StatefulWidget {
  const _ModalPagoRapido({required this.socio, required this.nombre});
  final Socio socio;
  final String nombre;

  @override
  State<_ModalPagoRapido> createState() => _ModalPagoRapidoState();
}

class _ModalPagoRapidoState extends State<_ModalPagoRapido> {
  final _form = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _periodoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _nroChequeCtrl = TextEditingController();

  String? _tipoCuotaId;
  String? _metodoPagoId;
  bool _saving = false;
  bool _cargandoTarifa = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodoCtrl.text =
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _periodoCtrl.dispose();
    _observacionesCtrl.dispose();
    _nroChequeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTipoCuotaChanged(String? tipoCuotaId) async {
    setState(() {
      _tipoCuotaId = tipoCuotaId;
      _cargandoTarifa = true;
    });
    if (tipoCuotaId == null) {
      setState(() => _cargandoTarifa = false);
      return;
    }
    try {
      final tarifa = await context
          .read<CuotaProvider>()
          .obtenerTarifaVigente(tipoCuotaId);
      if (mounted) {
        _montoCtrl.text = tarifa != null
            ? NumberFormat('#,##0.##', 'es_AR').format(tarifa.monto)
            : '';
      }
    } finally {
      if (mounted) setState(() => _cargandoTarifa = false);
    }
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
      final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
      await context.read<CuotaProvider>().registrarPago(Cuota(
        id: '',
        socioId: widget.socio.id,
        tipoCuotaId: _tipoCuotaId!,
        periodo: _periodoCtrl.text.trim(),
        moneda: 'ARS',
        metodoPagoId: _metodoPagoId!,
        usuarioId: uid,
        observaciones: _observacionesCtrl.text.trim().isEmpty
            ? null
            : _observacionesCtrl.text.trim(),
        comprobante: null,
        nroCheque: _nroChequeCtrl.text.trim().isEmpty
            ? null
            : _nroChequeCtrl.text.trim(),
        monto: monto,
        fechaPago: DateTime.now(),
        fechaCreacion: DateTime.now(),
      ));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiposCuota = context.watch<CuotaProvider>().tiposCuota;
    final metodos = context.watch<MetodoPagoProvider>().obtenerActivos();
    final metodoPagoNombre = _metodoPagoId != null
        ? metodos
                .firstWhere((m) => m['id'] == _metodoPagoId,
                    orElse: () => <String, dynamic>{})['nombre']
            as String?
        : null;

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
                widget.nombre,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Text(
                'Registrar pago',
                style: TextStyle(color: AppTheme.textoSecundario),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _tipoCuotaId,
                decoration:
                    const InputDecoration(labelText: 'Tipo de cuota *'),
                items: tiposCuota
                    .map((t) => DropdownMenuItem(
                        value: t.id, child: Text(t.nombre)))
                    .toList(),
                onChanged: _onTipoCuotaChanged,
                validator: (v) => v == null ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _periodoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Período *',
                  helperText: 'Formato: MM/AAAA',
                  hintText: '06/2026',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  final parts = v.split('/');
                  if (parts.length != 2) return 'Formato: MM/AAAA';
                  final mes = int.tryParse(parts[0]);
                  final anio = int.tryParse(parts[1]);
                  if (mes == null || mes < 1 || mes > 12) {
                    return 'Mes inválido (01-12)';
                  }
                  if (anio == null || anio < 2000) return 'Año inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _montoCtrl,
                decoration: InputDecoration(
                  labelText: 'Monto *',
                  prefixText: '\$ ',
                  suffixIcon: _cargandoTarifa
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _metodoPagoId,
                decoration: const InputDecoration(
                    labelText: 'Método de pago *'),
                items: metodos
                    .map((m) => DropdownMenuItem(
                          value: m['id'] as String,
                          child:
                              MetodoPagoRow(nombre: m['nombre'] as String),
                        ))
                    .toList(),
                selectedItemBuilder: (context) => metodos
                    .map((m) => Text(m['nombre'] as String,
                        overflow: TextOverflow.ellipsis))
                    .toList(),
                onChanged: (v) => setState(() => _metodoPagoId = v),
                validator: (v) => v == null ? 'Requerido' : null,
              ),
              NumeroChequeWidget(
                metodoPago: metodoPagoNombre,
                controller: _nroChequeCtrl,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _observacionesCtrl,
                decoration:
                    const InputDecoration(labelText: 'Observaciones'),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
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
                      : const Text('Registrar pago'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _ModalSocio ───────────────────────────────────────────────────────────────

class _ModalSocio extends StatefulWidget {
  const _ModalSocio();

  @override
  State<_ModalSocio> createState() => _ModalSocioState();
}

class _ModalSocioState extends State<_ModalSocio> {
  final _form = GlobalKey<FormState>();

  bool _personaNueva = false;
  Persona? _personaSeleccionada;
  final _buscarPersonaCtrl = TextEditingController();

  String _tipoPersonaNueva = 'fisica';
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  DateTime? _fechaNacimiento;
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _razonSocialCtrl = TextEditingController();
  final _cuitCtrl = TextEditingController();
  Persona? _personaContacto;

  String _tipoSocio = 'activo';
  String? _subtipoId;
  String? _cursoId;
  List<SubtipoSocio> _subtipos = [];
  StreamSubscription<List<SubtipoSocio>>? _subtiposSub;

  DateTime _fechaIngreso = DateTime.now();
  final _observacionesCtrl = TextEditingController();

  bool _crearAcceso = false;
  String _rolSeleccionado = 'consultante';

  bool _saving = false;

  String get _tipoPersonaEfectivo =>
      _personaSeleccionada?.tipoPersona ?? _tipoPersonaNueva;
  bool get _esFiscal => _tipoPersonaEfectivo == 'fiscal';
  String get _tipoSocioEfectivo => _esFiscal ? 'honorario' : _tipoSocio;

  @override
  void initState() {
    super.initState();
    _cargarSubtipos(_tipoSocio);
  }

  void _cargarSubtipos(String tipoSocio) {
    _subtiposSub?.cancel();
    final repo = context.read<SocioProvider>().repo;
    _subtiposSub = repo.obtenerSubtipos(tipoSocio).listen((list) {
      if (!mounted) return;
      setState(() {
        _subtipos = list;
        if (_subtipoId != null && !list.any((s) => s.id == _subtipoId)) {
          _subtipoId = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _subtiposSub?.cancel();
    _buscarPersonaCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _dniCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _razonSocialCtrl.dispose();
    _cuitCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  List<Map<String, String>> _rolesDisponibles() {
    final esAdmin = context.read<AuthProvider>().esAdmin;
    final roles = [
      {'value': 'consultante', 'label': 'Consultante'},
      {'value': 'solo_lectura', 'label': 'Solo lectura'},
    ];
    if (esAdmin) {
      roles.addAll([
        {'value': 'auditor', 'label': 'Auditor'},
        {'value': 'editor', 'label': 'Editor'},
      ]);
    }
    return roles;
  }

  IconData _iconoRol(String rol) => switch (rol) {
        'consultante' => Icons.visibility,
        'solo_lectura' => Icons.lock_outline,
        'auditor' => Icons.manage_search,
        'editor' => Icons.edit,
        _ => Icons.person_outline,
      };

  Color _colorRol(String rol) => switch (rol) {
        'consultante' => AppTheme.azulMedio,
        'solo_lectura' => AppTheme.textoSecundario,
        'auditor' => const Color(0xFF8E44AD),
        'editor' => AppTheme.verdeIngreso,
        _ => AppTheme.textoSecundario,
      };

  String _generarPasswordProvisoria() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
        10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _guardar() async {
    if (_personaSeleccionada == null && !_personaNueva) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná o creá una persona')),
      );
      return;
    }
    if (!_form.currentState!.validate()) return;

    if (_personaNueva && _crearAcceso && _emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Se requiere un email para crear acceso a la app')),
      );
      return;
    }

    setState(() => _saving = true);
    final personaProvider = context.read<PersonaProvider>();
    final socioProvider = context.read<SocioProvider>();
    final uid = context.read<AuthProvider>().currentUser?.uid;
    final messenger = ScaffoldMessenger.of(context);

    try {
      String personaId;
      String? emailPersona;

      if (_personaSeleccionada != null) {
        personaId = _personaSeleccionada!.id;
        emailPersona = _personaSeleccionada!.email;
      } else {
        final esFisica = _tipoPersonaNueva == 'fisica';
        emailPersona = _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim();

        final nuevaPersona = Persona(
          id: '',
          tipoPersona: _tipoPersonaNueva,
          nombre: esFisica ? _nombreCtrl.text.trim() : '',
          apellido: esFisica ? _apellidoCtrl.text.trim() : '',
          dni: esFisica && _dniCtrl.text.trim().isNotEmpty
              ? _dniCtrl.text.trim()
              : null,
          fechaNacimiento: esFisica ? _fechaNacimiento : null,
          telefono: _telefonoCtrl.text.trim().isEmpty
              ? null
              : _telefonoCtrl.text.trim(),
          email: emailPersona,
          direccion: esFisica && _direccionCtrl.text.trim().isNotEmpty
              ? _direccionCtrl.text.trim()
              : null,
          razonSocial: esFisica ? null : _razonSocialCtrl.text.trim(),
          cuit: !esFisica && _cuitCtrl.text.trim().isNotEmpty
              ? _cuitCtrl.text.trim()
              : null,
          personaContactoId: !esFisica ? _personaContacto?.id : null,
          subtipo: esFisica ? _subtipoId : null,
          cursoId: esFisica ? _cursoId : null,
          activo: true,
          fechaCreacion: DateTime.now(),
        );
        personaId = await personaProvider.agregar(nuevaPersona);

        if (_crearAcceso && emailPersona != null) {
          final cred =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: emailPersona,
            password: _generarPasswordProvisoria(),
          );
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(cred.user!.uid)
              .set({
            'authUid': cred.user!.uid,
            'personaId': personaId,
            'rol': _rolSeleccionado,
            'activo': true,
            'fechaCreacion': FieldValue.serverTimestamp(),
          });
          await FirebaseAuth.instance
              .sendPasswordResetEmail(email: emailPersona);
          messenger.showSnackBar(SnackBar(
            content: Text(
                'Persona creada. Se envió un email a $emailPersona para establecer la contraseña.'),
            backgroundColor: AppTheme.verdeTeal,
          ));
        }
      }

      final socio = Socio(
        id: '',
        numeroSocio: 0,
        personaId: personaId,
        tipoSocio: _tipoSocioEfectivo,
        activo: true,
        fechaIngreso: _fechaIngreso,
        observaciones: _observacionesCtrl.text.trim().isEmpty
            ? null
            : _observacionesCtrl.text.trim(),
        usuarioId: uid,
      );
      await socioProvider.agregar(socio);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppTheme.rojoGasto,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final personaProvider = context.watch<PersonaProvider>();

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
                'Agregar socio',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            !_personaNueva ? AppTheme.celesteFondo : null,
                      ),
                      onPressed: () =>
                          setState(() => _personaNueva = false),
                      child: const Text('Buscar persona'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            _personaNueva ? AppTheme.celesteFondo : null,
                      ),
                      onPressed: () => setState(() {
                        _personaNueva = true;
                        _personaSeleccionada = null;
                      }),
                      child: const Text('Crear persona nueva'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_personaNueva) ...[
                if (_personaSeleccionada != null)
                  Card(
                    color: AppTheme.celesteFondo,
                    child: ListTile(
                      leading: const Icon(Icons.person,
                          color: AppTheme.azulMedio),
                      title: Text(_personaSeleccionada!.nombreCompleto),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _personaSeleccionada = null),
                      ),
                    ),
                  )
                else
                  Autocomplete<Persona>(
                    displayStringForOption: (p) => p.nombreCompleto,
                    optionsBuilder: (val) =>
                        personaProvider.buscar(val.text),
                    onSelected: (p) =>
                        setState(() => _personaSeleccionada = p),
                    fieldViewBuilder: (context, ctrl, focusNode, _) {
                      return TextFormField(
                        controller: ctrl,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Buscar persona',
                          hintText: 'Por nombre, apellido o DNI',
                          suffixIcon: Icon(Icons.search),
                        ),
                        validator: (_) => (!_personaNueva &&
                                _personaSeleccionada == null)
                            ? 'Seleccioná una persona'
                            : null,
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) =>
                        Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (_, i) {
                              final p = options.elementAt(i);
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                    Icons.person_outline,
                                    size: 18),
                                title: Text(p.nombreCompleto),
                                onTap: () => onSelected(p),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _tipoPersonaNueva == 'fisica'
                              ? AppTheme.celesteFondo
                              : null,
                        ),
                        onPressed: () =>
                            setState(() => _tipoPersonaNueva = 'fisica'),
                        child: const Text('Física'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _tipoPersonaNueva == 'fiscal'
                              ? AppTheme.celesteFondo
                              : null,
                        ),
                        onPressed: () =>
                            setState(() => _tipoPersonaNueva = 'fiscal'),
                        child: const Text('Fiscal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_tipoPersonaNueva == 'fisica') ...[
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nombre *'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (_personaNueva && (v == null || v.trim().isEmpty))
                            ? 'Requerido'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _apellidoCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Apellido *'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (_personaNueva && (v == null || v.trim().isEmpty))
                            ? 'Requerido'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dniCtrl,
                    decoration: const InputDecoration(labelText: 'DNI'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate:
                            _fechaNacimiento ?? DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _fechaNacimiento = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Fecha de nacimiento'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fechaNacimiento == null
                              ? '—'
                              : '${_fechaNacimiento!.day.toString().padLeft(2, '0')}/${_fechaNacimiento!.month.toString().padLeft(2, '0')}/${_fechaNacimiento!.year}'),
                          const Icon(Icons.calendar_today_outlined,
                              size: 18, color: AppTheme.azulMedio),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telefonoCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _direccionCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Dirección'),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _razonSocialCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Razón social *'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (_personaNueva && (v == null || v.trim().isEmpty))
                            ? 'Requerido'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cuitCtrl,
                    decoration: const InputDecoration(labelText: 'CUIT'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Autocomplete<Persona>(
                    displayStringForOption: (p) => p.nombreCompleto,
                    optionsBuilder: (val) => personaProvider.buscar(
                        val.text,
                        soloTipo: 'fisica'),
                    onSelected: (p) =>
                        setState(() => _personaContacto = p),
                    fieldViewBuilder: (context, ctrl, focusNode, _) {
                      ctrl.text = _personaContacto?.nombreCompleto ?? '';
                      return TextFormField(
                        controller: ctrl,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Persona de contacto',
                          suffixIcon: Icon(Icons.search),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) =>
                        Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (_, i) {
                              final p = options.elementAt(i);
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                    Icons.person_outline,
                                    size: 18),
                                title: Text(p.nombreCompleto),
                                onTap: () => onSelected(p),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telefonoCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              if (_esFiscal)
                const InputDecorator(
                  decoration:
                      InputDecoration(labelText: 'Tipo de socio'),
                  child: Text('Honorario'),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _tipoSocio,
                  decoration: const InputDecoration(
                      labelText: 'Tipo de socio *'),
                  items: const [
                    DropdownMenuItem(
                        value: 'activo', child: Text('Activo')),
                    DropdownMenuItem(
                        value: 'adherente', child: Text('Adherente')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _tipoSocio = v;
                      _subtipoId = null;
                    });
                    _cargarSubtipos(v);
                  },
                ),
              if (_personaNueva &&
                  _tipoPersonaNueva == 'fisica' &&
                  !_esFiscal) ...[
                const SizedBox(height: 12),
                _subtipos.isEmpty
                    ? const InputDecorator(
                        decoration: InputDecoration(labelText: 'Subtipo'),
                        child: Text(
                          'Cargando…',
                          style:
                              TextStyle(color: AppTheme.textoSecundario),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: _subtipoId,
                        decoration:
                            const InputDecoration(labelText: 'Subtipo'),
                        items: _subtipos
                            .map((s) => DropdownMenuItem(
                                value: s.id, child: Text(s.nombre)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _subtipoId = v;
                          _cursoId = null;
                        }),
                      ),
              if (_personaNueva &&
                  _tipoPersonaNueva == 'fisica' &&
                  !_esFiscal &&
                  _subtipos
                      .where((s) => s.id == _subtipoId)
                      .firstOrNull
                      ?.nombre
                      .toLowerCase() ==
                      'alumno') ...[
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final cursos =
                      context.watch<CursoProvider>().activos;
                  return DropdownButtonFormField<String>(
                    initialValue: _cursoId,
                    decoration:
                        const InputDecoration(labelText: 'Curso'),
                    items: cursos
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nombre),
                            ))
                        .toList(),
                    selectedItemBuilder: (context) =>
                        cursos.map((c) => Text(c.nombre)).toList(),
                    onChanged: (v) => setState(() => _cursoId = v),
                  );
                }),
              ],
              ],
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fechaIngreso,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _fechaIngreso = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Fecha de ingreso'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_fechaIngreso.day.toString().padLeft(2, '0')}/${_fechaIngreso.month.toString().padLeft(2, '0')}/${_fechaIngreso.year}',
                      ),
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppTheme.azulMedio),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _observacionesCtrl,
                decoration:
                    const InputDecoration(labelText: 'Observaciones'),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              if (_personaNueva) ...[
                const SizedBox(height: 8),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Crear acceso a la app'),
                  secondary: Icon(
                    Icons.lock_open_outlined,
                    color: _crearAcceso
                        ? AppTheme.azulMedio
                        : AppTheme.textoSecundario,
                  ),
                  value: _crearAcceso,
                  onChanged: (v) => setState(() => _crearAcceso = v),
                ),
                if (_crearAcceso) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _rolSeleccionado,
                    decoration:
                        const InputDecoration(labelText: 'Rol'),
                    items: _rolesDisponibles()
                        .map((r) => DropdownMenuItem(
                              value: r['value'],
                              child: Row(
                                children: [
                                  Icon(_iconoRol(r['value']!),
                                      size: 18,
                                      color: _colorRol(r['value']!)),
                                  const SizedBox(width: 8),
                                  Text(r['label']!),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _rolSeleccionado = v!),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Se enviará un email para que el usuario establezca su contraseña.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textoSecundario),
                  ),
                ],
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
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Agregar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _SeccionTarifas ───────────────────────────────────────────────────────────

class _SeccionTarifas extends StatefulWidget {
  const _SeccionTarifas();

  @override
  State<_SeccionTarifas> createState() => _SeccionTarifasState();
}

class _SeccionTarifasState extends State<_SeccionTarifas> {
  Map<String, Map<String, dynamic>> _tarifasVigentes = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarTarifas();
  }

  Future<void> _cargarTarifas() async {
    if (!mounted) return;
    try {
      final tiposSnap = await FirebaseFirestore.instance
          .collection('tipos_cuota')
          .get();
      // ignore: avoid_print
      print('[Tarifas] tipos_cuota: ${tiposSnap.docs.length}');
      for (final d in tiposSnap.docs) {
        // ignore: avoid_print
        print('[Tarifas] tipo: ${d.id} → ${d.data()}');
      }

      final tarifas = <String, Map<String, dynamic>>{};
      for (final tipo in tiposSnap.docs) {
        final tarifaSnap = await FirebaseFirestore.instance
            .collection('tarifas_cuota')
            .where('tipoCuotaId', isEqualTo: tipo.id)
            .orderBy('vigenciaDesde', descending: true)
            .limit(1)
            .get();
        // ignore: avoid_print
        print('[Tarifas] tarifas para ${tipo.id}: ${tarifaSnap.docs.length}');

        if (tarifaSnap.docs.isNotEmpty) {
          tarifas[tipo.id] = {
            ...tarifaSnap.docs.first.data(),
            'id': tarifaSnap.docs.first.id,
            'tipoNombre': tipo.data()['nombre'] ?? tipo.id,
          };
        }
      }

      if (mounted) {
        setState(() {
          _tarifasVigentes = tarifas;
          _cargando = false;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Tarifas] ERROR: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final puedeEditar = auth.esAdmin || auth.esEditor;
    // ignore: avoid_print
    print('[Tarifas] build: ${_tarifasVigentes.keys.toList()}');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.celesteBorde),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Valor de la cuota social',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _verHistorial,
                child: const Row(
                  children: [
                    Text('Ver historial',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.azulMedio)),
                    SizedBox(width: 4),
                    Icon(Icons.history,
                        color: AppTheme.azulMedio, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_cargando)
            const LinearProgressIndicator(color: AppTheme.celesteAccento)
          else
            ..._tarifasVigentes.entries.map((entry) {
              final tarifa = entry.value;
              final vigenciaDesde =
                  (tarifa['vigenciaDesde'] as Timestamp).toDate();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tarifa['tipoNombre'] as String,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textoSecundario),
                          ),
                          Text(
                            'Vigente desde ${DateFormat('dd/MM/yyyy').format(vigenciaDesde)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textoSecundario),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatMonto(tarifa['monto']),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    if (puedeEditar)
                      GestureDetector(
                        onTap: () => _editarTarifa(tarifa),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.celesteFondo,
                          ),
                          child: const Icon(Icons.edit,
                              color: AppTheme.azulMedio, size: 14),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _editarTarifa(Map<String, dynamic> tarifa) async {
    final controller = TextEditingController(
        text: (tarifa['monto'] as num).toStringAsFixed(0));
    DateTime vigenciaDesde = DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actualizar tarifa: ${tarifa['tipoNombre']}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nuevo monto',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vigente desde'),
                  subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(vigenciaDesde)),
                  trailing: const Icon(Icons.calendar_today,
                      color: AppTheme.azulMedio),
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: ctx,
                      initialDate: vigenciaDesde,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (fecha != null) {
                      setStateModal(() => vigenciaDesde = fecha);
                    }
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.verdeTeal),
                    onPressed: () async {
                      final monto =
                          double.tryParse(controller.text.trim()) ?? 0;
                      if (monto <= 0) return;
                      await FirebaseFirestore.instance
                          .collection('tarifas_cuota')
                          .add({
                        'tipoCuotaId': tarifa['tipoCuotaId'],
                        'monto': monto,
                        'moneda': 'ARS',
                        'vigenciaDesde':
                            Timestamp.fromDate(vigenciaDesde),
                        'usuarioId': context
                            .read<AuthProvider>()
                            .currentUser
                            ?.uid,
                      });
                      if (mounted) {
                        Navigator.pop(context);
                        await _cargarTarifas();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tarifa actualizada'),
                              backgroundColor: AppTheme.verdeIngreso,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Guardar nueva tarifa',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _verHistorial() async {
    final historialSnap = await FirebaseFirestore.instance
        .collection('tarifas_cuota')
        .orderBy('vigenciaDesde', descending: true)
        .get();

    final tiposSnap =
        await FirebaseFirestore.instance.collection('tipos_cuota').get();

    final tiposMap = {
      for (final d in tiposSnap.docs)
        d.id: d.data()['nombre'] as String?
    };

    // Primera aparición de cada tipo en la lista descendente = la vigente
    final vigentePorTipo = <String, String>{};
    for (final doc in historialSnap.docs) {
      final tid = doc.data()['tipoCuotaId'] as String? ?? '';
      vigentePorTipo.putIfAbsent(tid, () => doc.id);
    }

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.celesteBorde,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Historial de tarifas',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                itemCount: historialSnap.docs.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1),
                itemBuilder: (_, i) {
                  final data = historialSnap.docs[i].data();
                  final vigenciaDesde =
                      (data['vigenciaDesde'] as Timestamp).toDate();
                  final tid =
                      data['tipoCuotaId'] as String? ?? '';
                  final tipoNombre =
                      tiposMap[tid] ?? 'Sin tipo';
                  final esVigente =
                      vigentePorTipo[tid] == historialSnap.docs[i].id;

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 4),
                    title: Text(
                      '$tipoNombre — ${_formatMonto(data['monto'])}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Desde ${DateFormat('dd/MM/yyyy').format(vigenciaDesde)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: esVigente
                            ? AppTheme.verdeIngreso
                                .withValues(alpha: 0.1)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: esVigente
                              ? AppTheme.verdeIngreso
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                      child: Text(
                        esVigente ? 'Vigente' : 'Anterior',
                        style: TextStyle(
                          fontSize: 10,
                          color: esVigente
                              ? AppTheme.verdeIngreso
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
