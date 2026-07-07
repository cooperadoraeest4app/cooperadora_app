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
import '../../../admin/presentation/providers/metodo_pago_provider.dart';
import '../../../admin/presentation/providers/persona_provider.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../../shared/widgets/numero_cheque_widget.dart';
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
import '../../../../shared/widgets/app_drawer.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _colorTipo(String tipoSocio) => switch (tipoSocio) {
      'activo' => AppTheme.azulMedio,
      'honorario' => const Color(0xFF8E44AD),
      'adherente' => const Color(0xFFE67E22),
      _ => AppTheme.textoSecundario,
    };

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
                'Socios',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [AccionAuthWidget()],
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
    final personaProvider = context.watch<PersonaProvider>();

    final socios = _query.isEmpty
        ? provider.todos
        : provider.todos.where((s) {
            final nombre =
                personaProvider.nombreCompleto(s.personaId).toLowerCase();
            return nombre.contains(_query) ||
                s.numeroSocio.toString().contains(_query);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o número de socio…',
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
                        tipoNombre: provider.nombreTipo(socios[i].tipoSocio),
                        nombrePersona: personaProvider
                            .nombreCompleto(socios[i].personaId),
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
    required this.nombrePersona,
    required this.puedeGestionar,
  });

  final Socio socio;
  final String tipoNombre;
  final String nombrePersona;
  final bool puedeGestionar;

  @override
  State<_SocioCard> createState() => _SocioCardState();
}

class _SocioCardState extends State<_SocioCard> {
  late Future<bool> _alDiaFuture;

  @override
  void initState() {
    super.initState();
    _alDiaFuture = CuotaRepository().estaAlDia(widget.socio.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.socio;
    final color = _colorTipo(s.tipoSocio);

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
                          widget.nombrePersona,
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
                          builder: (_) => _ModalPagoRapido(
                            socio: widget.socio,
                            nombre: widget.nombrePersona,
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
    final personaProv = context.watch<PersonaProvider>();
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
      final tipo = socioProv.tipoById(s.tipoSocio);
      return s.activo && tipo?.requiereCuota == true;
    }).toList()
      ..sort((a, b) => personaProv
          .nombreCompleto(a.personaId)
          .compareTo(personaProv.nombreCompleto(b.personaId)));

    return Column(
      children: [
        // ── Filtros ──────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: AppTheme.azulOscuro,
                  onPressed: _prevMes,
                ),
                Text(
                  '${_meses[_mes.month - 1]} ${_mes.year}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textoPrincipal,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: AppTheme.azulOscuro,
                  onPressed: _nextMes,
                ),
                if (cuotaProv.tiposCuota.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.celesteFondo,
                      borderRadius:
                          const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: DropdownButton<String>(
                      value: _tipoCuotaId,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(
                        color: AppTheme.textoPrincipal,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      items: cuotaProv.tiposCuota
                          .map((t) => DropdownMenuItem(
                              value: t.id, child: Text(t.nombre)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _tipoCuotaId = v),
                    ),
                  ),
                ],
              ],
            ),
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
                          nombre: personaProv.nombreCompleto(s.personaId),
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
    required this.nombre,
    required this.alDia,
    required this.puedeGestionar,
    this.tipoCuotaId,
  });
  final Socio socio;
  final String nombre;
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
                nombre,
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
                    builder: (_) =>
                        _ModalPagoRapido(socio: socio, nombre: nombre),
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
        nroCheque: _nroChequeCtrl.text.trim().isEmpty
            ? null
            : _nroChequeCtrl.text.trim(),
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
    final metodoPagoNombre = _metodoPagoId != null
        ? metodos.firstWhere(
            (m) => m['id'] == _metodoPagoId,
            orElse: () => <String, dynamic>{})['nombre'] as String?
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
// Alta de socio en un solo paso: buscar Persona existente o crear una nueva,
// y dar de alta el Socio vinculado con numeroSocio automático.

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
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _guardar() async {
    if (_personaSeleccionada == null && !_personaNueva) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná o creá una persona')),
      );
      return;
    }
    if (!_form.currentState!.validate()) return;

    // Validación extra: acceso sin email
    if (_personaNueva && _crearAcceso && _emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Se requiere un email para crear acceso a la app')),
      );
      return;
    }

    setState(() => _saving = true);
    // Capturar refs antes de gaps asíncronos
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
          activo: true,
          fechaCreacion: DateTime.now(),
        );
        personaId = await personaProvider.agregar(nuevaPersona);

        if (_crearAcceso && emailPersona != null) {
          final cred = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !_personaNueva
                            ? AppTheme.celesteFondo
                            : null,
                      ),
                      onPressed: () => setState(() {
                        _personaNueva = false;
                      }),
                      child: const Text('Buscar persona'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _personaNueva
                            ? AppTheme.celesteFondo
                            : null,
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
                                leading:
                                    const Icon(Icons.person_outline, size: 18),
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
                    decoration: const InputDecoration(labelText: 'Nombre *'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (_personaNueva &&
                            (v == null || v.trim().isEmpty))
                        ? 'Requerido'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _apellidoCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Apellido *'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (_personaNueva &&
                            (v == null || v.trim().isEmpty))
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
                        initialDate: _fechaNacimiento ?? DateTime(2000),
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
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _direccionCtrl,
                    decoration: const InputDecoration(labelText: 'Dirección'),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _razonSocialCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Razón social *'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (_personaNueva &&
                            (v == null || v.trim().isEmpty))
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
                    optionsBuilder: (val) => personaProvider
                        .buscar(val.text, soloTipo: 'fisica'),
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
                                leading:
                                    const Icon(Icons.person_outline, size: 18),
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
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              if (_esFiscal)
                const InputDecorator(
                  decoration: InputDecoration(labelText: 'Tipo de socio'),
                  child: Text('Honorario'),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _tipoSocio,
                  decoration:
                      const InputDecoration(labelText: 'Tipo de socio *'),
                  items: const [
                    DropdownMenuItem(value: 'activo', child: Text('Activo')),
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
                          style: TextStyle(color: AppTheme.textoSecundario),
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
                        onChanged: (v) =>
                            setState(() => _subtipoId = v),
                      ),
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
              // Acceso a la app (solo al crear persona nueva)
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
                    value: _rolSeleccionado,
                    decoration: const InputDecoration(labelText: 'Rol'),
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
                        fontSize: 12, color: AppTheme.textoSecundario),
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
