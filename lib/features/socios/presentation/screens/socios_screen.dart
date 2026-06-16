import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/presentation/providers/metodo_pago_provider.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/cuota_repository.dart';
import '../../domain/models/cuota.dart';
import '../../domain/models/socio.dart';
import '../../domain/models/subtipo_socio.dart';
import '../providers/cuota_provider.dart';
import '../providers/socio_provider.dart';
import 'socio_detalle_screen.dart';
import 'tarifas_screen.dart';
import '../../../../shared/utils/metodo_pago_icon.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _colorTipo(String tipoId) => switch (tipoId) {
      'activo' => AppTheme.azulMedio,
      'honorario' => const Color(0xFF8E44AD),
      'adherente' => const Color(0xFFE67E22),
      _ => AppTheme.textoSecundario,
    };

Future<int> _contarIntegrantes(String socioId) async {
  final snap = await FirebaseFirestore.instance
      .collection('integrantes')
      .where('socioId', isEqualTo: socioId)
      .get();
  return snap.docs.length;
}

// ── SociosScreen ──────────────────────────────────────────────────────────────

class SociosScreen extends StatefulWidget {
  const SociosScreen({super.key});

  @override
  State<SociosScreen> createState() => _SociosScreenState();
}

class _SociosScreenState extends State<SociosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
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
    final puedeGestionar = auth.esAdmin || auth.esEditor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
        title: const Text('Socios'),
        actions: const [AccionAuthWidget()],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Socios'),
            Tab(text: 'Cuotas'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (auth.esAdmin) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TarifasScreen()),
              ),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.price_change,
                        color: AppTheme.verdeTeal, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'Tarifas de cuota',
                      style: TextStyle(
                        color: AppTheme.textoPrincipal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.textoSecundario),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _SociosTab(puedeGestionar: puedeGestionar),
                const _CuotasTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabCtrl.index == 0 && puedeGestionar
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

// ── _SociosTab ────────────────────────────────────────────────────────────────

class _SociosTab extends StatefulWidget {
  const _SociosTab({required this.puedeGestionar});
  final bool puedeGestionar;

  @override
  State<_SociosTab> createState() => _SociosTabState();
}

class _SociosTabState extends State<_SociosTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SocioProvider>();
    final socios = _query.isEmpty
        ? provider.todos
        : provider.todos
            .where((s) => s.nombreDisplay.toLowerCase().contains(_query))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por apellido o razón social…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : socios.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _query.isNotEmpty
                              ? 'Sin resultados para "$_query"'
                              : 'No hay socios registrados.\nPresioná + para agregar el primero.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textoSecundario),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: socios.length,
                      itemBuilder: (_, i) => _SocioCard(
                        socio: socios[i],
                        tipoNombre: provider
                            .nombreTipo(socios[i].tipoSocioId),
                        puedeGestionar: widget.puedeGestionar,
                      ),
                    ),
        ),
      ],
    );
  }
}

// ── _SocioCard ────────────────────────────────────────────────────────────────

class _SocioCard extends StatefulWidget {
  const _SocioCard({
    required this.socio,
    required this.tipoNombre,
    required this.puedeGestionar,
  });

  final Socio socio;
  final String tipoNombre;
  final bool puedeGestionar;

  @override
  State<_SocioCard> createState() => _SocioCardState();
}

class _SocioCardState extends State<_SocioCard> {
  late Future<bool> _alDiaFuture;
  late Future<int> _integrantesFuture;

  @override
  void initState() {
    super.initState();
    _alDiaFuture = CuotaRepository().estaAlDia(widget.socio.id);
    _integrantesFuture = _contarIntegrantes(widget.socio.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.socio;
    final color = _colorTipo(s.tipoSocioId);

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
                    child: Text(
                      s.nombreDisplay,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textoPrincipal,
                      ),
                    ),
                  ),
                  _Chip(
                    label: s.activo ? 'Habilitado' : 'Inhabilitado',
                    color: s.activo
                        ? AppTheme.verdeIngreso
                        : AppTheme.textoSecundario,
                  ),
                  if (widget.puedeGestionar) ...[
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
                                SocioDetalleScreen(socio: widget.socio),
                          ),
                        ),
                      ),
                    ),
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
                          builder: (_) =>
                              _ModalPagoRapido(socio: widget.socio),
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
                  _Chip(label: widget.tipoNombre, color: color),
                  FutureBuilder<bool>(
                    future: _alDiaFuture,
                    builder: (_, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      return _Chip(
                        label: snap.data! ? 'Al día' : 'En deuda',
                        color: snap.data!
                            ? AppTheme.verdeIngreso
                            : AppTheme.amarilloAlerta,
                      );
                    },
                  ),
                  FutureBuilder<int>(
                    future: _integrantesFuture,
                    builder: (_, snap) {
                      if (!snap.hasData || snap.data == 0) {
                        return const SizedBox.shrink();
                      }
                      return _Chip(
                        label:
                            '${snap.data} integrante${snap.data == 1 ? '' : 's'}',
                        color: AppTheme.textoSecundario,
                      );
                    },
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

// ── _CuotasTab ────────────────────────────────────────────────────────────────

class _CuotasTab extends StatefulWidget {
  const _CuotasTab();

  @override
  State<_CuotasTab> createState() => _CuotasTabState();
}

class _CuotasTabState extends State<_CuotasTab> {
  final _repo = CuotaRepository();
  late DateTime _mes;
  String? _tipoCuotaId;
  late Stream<List<Cuota>> _stream;

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  String get _periodo =>
      '${_mes.month.toString().padLeft(2, '0')}/${_mes.year}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _mes = DateTime(now.year, now.month);
    _stream = _repo.obtenerPorPeriodo(_periodo);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tipoCuotaId == null) {
      final tipos = context.read<CuotaProvider>().tiposCuota;
      if (tipos.isNotEmpty) {
        setState(() => _tipoCuotaId = tipos.first.id);
      }
    }
  }

  void _prevMes() => setState(() {
        _mes = DateTime(_mes.year, _mes.month - 1);
        _stream = _repo.obtenerPorPeriodo(_periodo);
      });

  void _nextMes() => setState(() {
        _mes = DateTime(_mes.year, _mes.month + 1);
        _stream = _repo.obtenerPorPeriodo(_periodo);
      });

  @override
  Widget build(BuildContext context) {
    final cuotaProv = context.watch<CuotaProvider>();
    final socioProv = context.watch<SocioProvider>();
    final auth = context.watch<AuthProvider>();
    final puedeGestionar = auth.esAdmin || auth.esEditor;

    // Lazy-init default tipoCuotaId once tipos load
    if (_tipoCuotaId == null && cuotaProv.tiposCuota.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tipoCuotaId == null) {
          setState(() => _tipoCuotaId = cuotaProv.tiposCuota.first.id);
        }
      });
    }

    final sociosConCuota = socioProv.todos.where((s) {
      final tipo = socioProv.tipoById(s.tipoSocioId);
      return s.activo && tipo?.requiereCuota == true;
    }).toList()
      ..sort((a, b) => a.nombreDisplay.compareTo(b.nombreDisplay));

    return Column(
      children: [
        // ── Filtros ──────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: AppTheme.azulOscuro,
                onPressed: _prevMes,
              ),
              Expanded(
                child: Text(
                  '${_meses[_mes.month - 1]} ${_mes.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textoPrincipal,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: AppTheme.azulOscuro,
                onPressed: _nextMes,
              ),
              const SizedBox(width: 4),
              if (cuotaProv.tiposCuota.isNotEmpty)
                DropdownButton<String>(
                  value: _tipoCuotaId,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(
                    color: AppTheme.textoPrincipal,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  items: cuotaProv.tiposCuota
                      .map((t) => DropdownMenuItem(
                          value: t.id, child: Text(t.nombre)))
                      .toList(),
                  onChanged: (v) => setState(() => _tipoCuotaId = v),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Contenido ────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<Cuota>>(
            stream: _stream,
            builder: (_, snap) {
              final cuotas = snap.data ?? [];
              final cuotasTipo = _tipoCuotaId == null
                  ? cuotas
                  : cuotas
                      .where((c) => c.tipoCuotaId == _tipoCuotaId)
                      .toList();
              final deudaIds = sociosConCuota
                  .where((s) =>
                      !cuotasTipo.any((c) => c.socioId == s.id))
                  .map((s) => s.id)
                  .toSet();
              final alDiaCount =
                  sociosConCuota.length - deudaIds.length;
              final totalRecaudado = cuotasTipo.fold(
                  0.0, (acc, c) => acc + c.monto);

              return ListView(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 80),
                children: [
                  _ResumenCard(
                    alDia: alDiaCount,
                    total: sociosConCuota.length,
                    recaudado: totalRecaudado,
                  ),
                  const SizedBox(height: 8),
                  if (snap.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (sociosConCuota.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No hay socios activos que requieran cuota.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textoSecundario),
                        ),
                      ),
                    )
                  else
                    ...sociosConCuota.map((s) => _SocioCuotaTile(
                          socio: s,
                          alDia: !deudaIds.contains(s.id),
                          puedeGestionar: puedeGestionar,
                          tipoCuotaId: _tipoCuotaId,
                        )),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── _ResumenCard ──────────────────────────────────────────────────────────────

class _ResumenCard extends StatelessWidget {
  const _ResumenCard({
    required this.alDia,
    required this.total,
    required this.recaudado,
  });
  final int alDia;
  final int total;
  final double recaudado;

  @override
  Widget build(BuildContext context) {
    final progreso = total == 0 ? 0.0 : alDia / total;
    final montoFmt = NumberFormat.currency(
            locale: 'es_AR', symbol: '\$', decimalDigits: 2)
        .format(recaudado);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$alDia de $total socios al día',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Text(
                  montoFmt,
                  style: const TextStyle(
                    color: AppTheme.verdeIngreso,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 8,
                backgroundColor: AppTheme.celesteFondo,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.verdeIngreso),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SocioCuotaTile ───────────────────────────────────────────────────────────

class _SocioCuotaTile extends StatelessWidget {
  const _SocioCuotaTile({
    required this.socio,
    required this.alDia,
    required this.puedeGestionar,
    this.tipoCuotaId,
  });
  final Socio socio;
  final bool alDia;
  final bool puedeGestionar;
  final String? tipoCuotaId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                socio.nombreDisplay,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            _Chip(
              label: alDia ? 'Al día' : 'En deuda',
              color: alDia
                  ? AppTheme.verdeIngreso
                  : AppTheme.amarilloAlerta,
            ),
            const SizedBox(width: 8),
            if (alDia)
              const Icon(Icons.check_circle,
                  color: AppTheme.verdeIngreso, size: 22)
            else if (puedeGestionar)
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.payment, size: 22),
                  color: AppTheme.verdeTeal,
                  tooltip: 'Registrar pago',
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => _ModalPagoRapido(socio: socio),
                  ),
                ),
              )
            else
              const SizedBox(width: 32),
          ],
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
  const _ModalPagoRapido({required this.socio});
  final Socio socio;

  @override
  State<_ModalPagoRapido> createState() => _ModalPagoRapidoState();
}

class _ModalPagoRapidoState extends State<_ModalPagoRapido> {
  final _form = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _periodoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

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
        _montoCtrl.text =
            tarifa != null ? tarifa.monto.toStringAsFixed(2) : '';
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
      final uid =
          context.read<AuthProvider>().currentUser?.uid ?? '';
      final cuota = Cuota(
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
        monto: monto,
        fechaPago: DateTime.now(),
        fechaCreacion: DateTime.now(),
      );
      await context.read<CuotaProvider>().registrarPago(cuota);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiposCuota = context.watch<CuotaProvider>().tiposCuota;
    final metodos =
        context.watch<MetodoPagoProvider>().obtenerActivos();

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
                widget.socio.nombreDisplay,
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
                decoration: const InputDecoration(
                    labelText: 'Tipo de cuota *'),
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
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
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
                          child: MetodoPagoRow(
                              nombre: m['nombre'] as String),
                        ))
                    .toList(),
                selectedItemBuilder: (context) => metodos
                    .map((m) =>
                        MetodoPagoRow(nombre: m['nombre'] as String))
                    .toList(),
                onChanged: (v) => setState(() => _metodoPagoId = v),
                validator: (v) => v == null ? 'Requerido' : null,
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
  final _apellidoCtrl = TextEditingController();
  final _razonSocialCtrl = TextEditingController();
  final _cuitCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  String? _tipoId;
  String? _subtipoId;
  DateTime _fechaIngreso = DateTime.now();
  bool _saving = false;

  List<SubtipoSocio> _subtipos = [];
  StreamSubscription<List<SubtipoSocio>>? _subtiposSub;

  bool get _esHonorario => _tipoId == 'honorario';

  @override
  void initState() {
    super.initState();
  }

  void _cargarSubtipos(String tipoId) {
    _subtiposSub?.cancel();
    final repo = context.read<SocioProvider>().repo;
    _subtiposSub = repo.obtenerSubtipos(tipoId).listen((list) {
      if (!mounted) return;
      setState(() {
        _subtipos = list;
        if (_subtipoId != null &&
            !list.any((s) => s.id == _subtipoId)) {
          _subtipoId = list.isNotEmpty ? list.first.id : null;
        }
      });
    });
  }

  @override
  void dispose() {
    _subtiposSub?.cancel();
    _apellidoCtrl.dispose();
    _razonSocialCtrl.dispose();
    _cuitCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final provider = context.read<SocioProvider>();
      final socio = Socio(
        id: '',
        tipoSocioId: _tipoId!,
        subtipoSocioId: _subtipoId ?? '',
        apellidoFamilia: _esHonorario
            ? null
            : _apellidoCtrl.text.trim().toUpperCase(),
        razonSocial:
            _esHonorario ? _razonSocialCtrl.text.trim() : null,
        cuit: _esHonorario && _cuitCtrl.text.trim().isNotEmpty
            ? _cuitCtrl.text.trim()
            : null,
        activo: true,
        fechaIngreso: _fechaIngreso,
        observaciones: _observacionesCtrl.text.trim().isEmpty
            ? null
            : _observacionesCtrl.text.trim(),
        fechaCreacion: DateTime.now(),
      );
      await provider.agregar(socio);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tipos = context.watch<SocioProvider>().tipos;

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
                'Agregar socio',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              tipos.isEmpty
                  ? const InputDecorator(
                      decoration:
                          InputDecoration(labelText: 'Tipo de socio *'),
                      child: Text(
                        'Cargando tipos…',
                        style:
                            TextStyle(color: AppTheme.textoSecundario),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _tipoId,
                      decoration: const InputDecoration(
                          labelText: 'Tipo de socio *'),
                      items: tipos
                          .map((t) => DropdownMenuItem(
                              value: t.id, child: Text(t.nombre)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _tipoId = v;
                          _subtipoId = null;
                          _subtipos = [];
                        });
                        if (v != null) _cargarSubtipos(v);
                      },
                      validator: (v) =>
                          v == null ? 'Requerido' : null,
                    ),
              const SizedBox(height: 12),
              if (_tipoId != null)
                _subtipos.isEmpty
                    ? const InputDecorator(
                        decoration:
                            InputDecoration(labelText: 'Subtipo *'),
                        child: Text(
                          'Cargando subtipos…',
                          style: TextStyle(
                              color: AppTheme.textoSecundario),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: _subtipoId,
                        decoration:
                            const InputDecoration(labelText: 'Subtipo *'),
                        items: _subtipos
                            .map((s) => DropdownMenuItem(
                                value: s.id, child: Text(s.nombre)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _subtipoId = v),
                        validator: (v) =>
                            v == null ? 'Requerido' : null,
                      ),
              if (_tipoId != null) ...[
                const SizedBox(height: 12),
                if (_esHonorario) ...[
                  TextFormField(
                    controller: _razonSocialCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Razón social *'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Requerido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cuitCtrl,
                    decoration:
                        const InputDecoration(labelText: 'CUIT'),
                    keyboardType: TextInputType.number,
                  ),
                ] else ...[
                  TextFormField(
                    controller: _apellidoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Apellido de familia *',
                      helperText: 'Se guardará en mayúsculas',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Requerido'
                        : null,
                  ),
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
