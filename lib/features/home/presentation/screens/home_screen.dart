import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/categorias_data.dart';
import '../../../admin/presentation/providers/categoria_provider.dart';
import '../../../admin/presentation/providers/configuracion_provider.dart';
import '../../../inventario/domain/models/bien_inventario.dart';
import '../../../inventario/presentation/providers/inventario_provider.dart';
import '../../../inventario/presentation/screens/inventario_screen.dart';
import '../../../cuenta_bancaria/presentation/providers/cuenta_bancaria_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../cuenta_bancaria/presentation/screens/cuenta_bancaria_screen.dart';
import '../../../gastos/domain/models/gasto.dart';
import '../../../ingresos/domain/models/ingreso.dart';
import '../../../ingresos/presentation/providers/frecuencia_provider.dart';
import '../../../ingresos/presentation/providers/movimientos_provider.dart';
import '../../../ingresos/presentation/screens/agregar_movimiento_screen.dart';
import '../../../ingresos/presentation/screens/movimientos_screen.dart';
import '../../../proyectos/domain/models/proyecto.dart';
import '../../../proyectos/presentation/providers/proyecto_provider.dart';
import '../../../proyectos/presentation/screens/proyectos_screen.dart';
import '../../../proyectos/presentation/screens/proyecto_detalle_screen.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatMonto(double monto) {
  final format = monto == monto.truncateToDouble()
      ? NumberFormat('#,##0', 'es_AR')
      : NumberFormat('#,##0.##', 'es_AR');
  return '\$${format.format(monto)}';
}

Widget _buildSaldoWidget(double? saldo) {
  const mainStyle = TextStyle(
    color: AppTheme.textoPrincipal,
    fontSize: 44,
    fontWeight: FontWeight.bold,
    height: 1,
  );

  if (saldo == null) {
    return const Text('\$0', style: mainStyle);
  }

  final cents = (saldo.abs() * 100).round() % 100;
  final intFormatted =
      '\$${NumberFormat('#,##0', 'es_AR').format(saldo.truncate())}';

  if (cents == 0) {
    return Text(intFormatted, style: mainStyle);
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(intFormatted, style: mainStyle),
      Padding(
        padding: EdgeInsets.zero,
        child: Text(
          cents.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textoPrincipal,
          ),
        ),
      ),
    ],
  );
}

String _formatFecha(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/'
    '${fecha.month.toString().padLeft(2, '0')}/'
    '${fecha.year}';

// ── Movimiento unificado local ────────────────────────────────────────────────

class _Movimiento {
  final bool esIngreso;
  final double monto;
  final DateTime fecha;
  final String? descripcion;
  final String categoriaId;
  final String? comprobante;
  final bool recurrente;
  final String? frecuenciaId;

  const _Movimiento({
    required this.esIngreso,
    required this.monto,
    required this.fecha,
    this.descripcion,
    required this.categoriaId,
    this.comprobante,
    this.recurrente = false,
    this.frecuenciaId,
  });

  factory _Movimiento.fromIngreso(Ingreso i) => _Movimiento(
      esIngreso: true,
      monto: i.monto,
      fecha: i.fecha,
      descripcion: i.descripcion,
      categoriaId: i.categoriaId,
      comprobante: i.comprobante,
      recurrente: i.recurrente,
      frecuenciaId: i.frecuenciaId);

  factory _Movimiento.fromGasto(Gasto g) => _Movimiento(
      esIngreso: false,
      monto: g.monto,
      fecha: g.fecha,
      descripcion: g.descripcion,
      categoriaId: g.categoriaId,
      comprobante: g.comprobante,
      recurrente: g.recurrente,
      frecuenciaId: g.frecuenciaId);
}

// ── HomeScreen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ConfiguracionProvider>().cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovimientosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: null,
        actions: const [AccionAuthWidget()],
      ),
      body: StreamBuilder<List<Ingreso>>(
        stream: provider.ingresos,
        builder: (context, ingresoSnap) {
          return StreamBuilder<List<Gasto>>(
            stream: provider.gastos,
            builder: (context, gastoSnap) {
              final ingresos = ingresoSnap.data ?? [];
              final gastos = gastoSnap.data ?? [];

              final now = DateTime.now();
              final totalIngresosMes = ingresos
                  .where((i) =>
                      i.fecha.month == now.month && i.fecha.year == now.year)
                  .fold(0.0, (s, i) => s + i.monto);
              final totalGastosMes = gastos
                  .where((g) =>
                      g.fecha.month == now.month && g.fecha.year == now.year)
                  .fold(0.0, (s, g) => s + g.monto);

              final ultimos10 = ([
                ...ingresos.map(_Movimiento.fromIngreso),
                ...gastos.map(_Movimiento.fromGasto),
              ]..sort((a, b) => b.fecha.compareTo(a.fecha)))
                  .take(10)
                  .toList();

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _HeaderCooperadora(),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SaldoCard(
                        totalIngresosMes: totalIngresosMes,
                        totalGastosMes: totalGastosMes,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SeccionProyectos(),
                    const SizedBox(height: 24),
                    _SeccionTabsMovimientosInventario(movimientos: ultimos10),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HeaderCooperadora extends StatelessWidget {
  const _HeaderCooperadora();

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfiguracionProvider>();
    final nombre = config.nombreCooperadora.isNotEmpty
        ? config.nombreCooperadora
        : 'Cooperadora Escolar';
    final escuela = config.nombreEscuela.isNotEmpty
        ? config.nombreEscuela
        : '';

    return Container(
      width: double.infinity,
      color: AppTheme.azulOscuro,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school, size: 38, color: AppTheme.blanco),
          ),
          const SizedBox(height: 12),
          Text(
            nombre,
            style: const TextStyle(
              color: AppTheme.blanco,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (escuela.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              escuela,
              style: const TextStyle(
                color: AppTheme.celesteAccento,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Saldo ─────────────────────────────────────────────────────────────────────

class _SaldoCard extends StatelessWidget {
  const _SaldoCard({
    required this.totalIngresosMes,
    required this.totalGastosMes,
  });

  final double totalIngresosMes;
  final double totalGastosMes;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final puedeAgregar = auth.esEditor || auth.esAdmin;
    final cuentaProvider = context.watch<CuentaBancariaProvider>();
    final cuenta = cuentaProvider.cuenta;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          children: [
            const Text(
              'Saldo actual',
              style: TextStyle(
                color: AppTheme.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            _buildSaldoWidget(cuenta?.saldoActual),
            const SizedBox(height: 2),
            if (cuenta == null)
              const Text(
                'Cuenta bancaria pendiente de configuración',
                style: TextStyle(color: AppTheme.textoSecundario, fontSize: 11),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CuentaBancariaScreen()),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.azulMedio,
                backgroundColor:
                    AppTheme.celesteAccento.withValues(alpha: 0.25),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              child: const Text('Ver detalle'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ChipBalance(
                    label: 'Ingresos del mes',
                    monto: totalIngresosMes,
                    color: AppTheme.verdeIngreso,
                    icono: Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChipBalance(
                    label: 'Gastos del mes',
                    monto: totalGastosMes,
                    color: AppTheme.rojoGasto,
                    icono: Icons.arrow_downward,
                  ),
                ),
              ],
            ),
            if (puedeAgregar) ...[
              const SizedBox(height: 14),
              const _BotonesAccionRapida(),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChipBalance extends StatelessWidget {
  const _ChipBalance({
    required this.label,
    required this.monto,
    required this.color,
    required this.icono,
  });

  final String label;
  final double monto;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatMonto(monto),
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Proyectos ─────────────────────────────────────────────────────────────────

class _SeccionProyectos extends StatelessWidget {
  const _SeccionProyectos();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProyectoProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Proyectos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textoPrincipal,
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.azulMedio,
                  backgroundColor:
                      AppTheme.celesteAccento.withValues(alpha: 0.25),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProyectosScreen(),
                  ),
                ),
                child: const Text('Ver todos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SubseccionProyectos(
          titulo: 'En curso',
          tabIndex: 0,
          proyectos: provider.enCurso.take(3).toList(),
        ),
        const SizedBox(height: 20),
        _SubseccionProyectos(
          titulo: 'Planificados',
          tabIndex: 1,
          proyectos: provider.planificados.take(3).toList(),
        ),
        const SizedBox(height: 20),
        _SubseccionProyectos(
          titulo: 'Finalizados',
          tabIndex: 2,
          proyectos: provider.finalizados.take(2).toList(),
        ),
      ],
    );
  }
}

class _SubseccionProyectos extends StatelessWidget {
  const _SubseccionProyectos({
    required this.titulo,
    required this.tabIndex,
    required this.proyectos,
  });

  final String titulo;
  final int tabIndex;
  final List<Proyecto> proyectos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textoPrincipal,
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.azulMedio,
                  backgroundColor:
                      AppTheme.celesteAccento.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProyectosScreen(initialTab: tabIndex),
                  ),
                ),
                child: const Text('Ver todos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: proyectos.isEmpty
              ? const Center(
                  child: Text(
                    'Sin proyectos',
                    style: TextStyle(color: AppTheme.textoSecundario),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: proyectos.length,
                  itemBuilder: (ctx, i) =>
                      _ProyectoCard(proyecto: proyectos[i]),
                ),
        ),
      ],
    );
  }
}

class _ProyectoCard extends StatelessWidget {
  const _ProyectoCard({required this.proyecto});

  final Proyecto proyecto;

  @override
  Widget build(BuildContext context) {
    final tipoNombre =
        context.read<ProyectoProvider>().nombreTipo(proyecto.tipoProyectoId);

    final (chipColor, chipLabel) = switch (proyecto.estado) {
      'en_curso' => (AppTheme.verdeIngreso, 'En curso'),
      'planificado' => (AppTheme.amarilloAlerta, 'Planificado'),
      'cancelado' => (AppTheme.textoSecundario, 'Cancelado'),
      _ => (AppTheme.textoSecundario, 'Finalizado'),
    };

    return SizedBox(
      width: 210,
      child: Card(
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProyectoDetalleScreen(proyecto: proyecto),
            ),
          ),
          child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chipColor.withAlpha(30),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  chipLabel,
                  style: TextStyle(
                    color: chipColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                proyecto.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textoPrincipal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                tipoNombre,
                style: const TextStyle(
                  color: AppTheme.textoSecundario,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (proyecto.presupuestoActual > 0)
                Text(
                  _formatMonto(proyecto.presupuestoActual),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textoPrincipal,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

// ── Sección combinada: Movimientos + Inventario ───────────────────────────────

class _SeccionTabsMovimientosInventario extends StatefulWidget {
  const _SeccionTabsMovimientosInventario({required this.movimientos});
  final List<_Movimiento> movimientos;

  @override
  State<_SeccionTabsMovimientosInventario> createState() =>
      _SeccionTabsMovimientosInventarioState();
}

class _SeccionTabsMovimientosInventarioState
    extends State<_SeccionTabsMovimientosInventario>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _soloRecurrentes = false;
  String? _frecuenciaFiltro;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  static ButtonStyle get _verTodosStyle => TextButton.styleFrom(
        foregroundColor: AppTheme.azulMedio,
        backgroundColor: AppTheme.celesteAccento.withValues(alpha: 0.25),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final puedeAgregar = auth.esEditor || auth.esAdmin;
    final frecuencias = context.watch<FrecuenciaProvider>().frecuencias;
    final config = context.watch<ConfiguracionProvider>();
    final inventarioProv = context.watch<InventarioProvider>();

    var movimientos = _soloRecurrentes
        ? widget.movimientos.where((m) => m.recurrente).toList()
        : widget.movimientos;
    if (_soloRecurrentes && _frecuenciaFiltro != null) {
      movimientos = movimientos
          .where((m) => m.frecuenciaId == _frecuenciaFiltro)
          .toList();
    }

    final inventarioVisible = config.seccionesPublicas['inventario'] ?? true;
    final ultimos5 = inventarioProv.todos.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabCtrl,
              tabs: const [
                Tab(icon: Icon(Icons.swap_vert), text: 'Movimientos'),
                Tab(icon: Icon(Icons.inventory_2), text: 'Inventario'),
              ],
              labelColor: AppTheme.azulMedio,
              unselectedLabelColor: AppTheme.textoSecundario,
              indicatorColor: AppTheme.azulMedio,
            ),
            SizedBox(
              height: 400,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Tab Movimientos ──────────────────────────────────────
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // HEADER FIJO
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Últimos movimientos',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textoPrincipal,
                                  ),
                                ),
                                TextButton(
                                  style: _verTodosStyle,
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const MovimientosScreen()),
                                  ),
                                  child: const Text('Ver todos'),
                                ),
                              ],
                            ),
                            if (puedeAgregar) ...[
                              const SizedBox(height: 4),
                              const _BotonesAccionRapida(),
                            ],
                            Row(
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Solo recurrentes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textoPrincipal,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Switch(
                                  value: _soloRecurrentes,
                                  onChanged: (v) => setState(() {
                                    _soloRecurrentes = v;
                                    if (!v) _frecuenciaFiltro = null;
                                  }),
                                  activeThumbColor: AppTheme.verdeTeal,
                                  inactiveThumbColor: AppTheme.blanco,
                                  inactiveTrackColor: AppTheme.azulOscuro
                                      .withValues(alpha: 0.3),
                                ),
                                if (_soloRecurrentes) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String?>(
                                          value: _frecuenciaFiltro,
                                          isDense: true,
                                          isExpanded: true,
                                          items: [
                                            const DropdownMenuItem(
                                                value: null,
                                                child: Text('Todas',
                                                    style: TextStyle(
                                                        fontSize: 13))),
                                            ...frecuencias.map((f) =>
                                                DropdownMenuItem(
                                                  value: f.id,
                                                  child: Text(f.nombre,
                                                      style: const TextStyle(
                                                          fontSize: 13)),
                                                )),
                                          ],
                                          onChanged: (v) => setState(
                                              () => _frecuenciaFiltro = v),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // LISTADO SCROLLEABLE
                      Expanded(
                        child: movimientos.isEmpty
                            ? Center(
                                child: Text(
                                  _soloRecurrentes
                                      ? 'Sin movimientos recurrentes'
                                      : 'Sin movimientos registrados',
                                  style: const TextStyle(
                                      color: AppTheme.textoSecundario),
                                ),
                              )
                            : ListView.separated(
                                itemCount: movimientos.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1, indent: 72),
                                itemBuilder: (ctx, i) =>
                                    _MovimientoTile(item: movimientos[i]),
                              ),
                      ),
                    ],
                  ),
                  // ── Tab Inventario ───────────────────────────────────────
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Row(
                            children: [
                              const Text(
                                'Últimos bienes',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textoPrincipal,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                style: _verTodosStyle,
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const InventarioScreen()),
                                ),
                                child: const Text('Ver todos'),
                              ),
                            ],
                          ),
                        ),
                        if (!inventarioVisible)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'Inventario no habilitado públicamente',
                                style: TextStyle(
                                    color: AppTheme.textoSecundario),
                              ),
                            ),
                          )
                        else if (inventarioProv.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child:
                                Center(child: CircularProgressIndicator()),
                          )
                        else if (ultimos5.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'Sin bienes registrados',
                                style: TextStyle(
                                    color: AppTheme.textoSecundario),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: ultimos5.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 56),
                            itemBuilder: (ctx, i) =>
                                _BienTile(bien: ultimos5[i]),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({required this.item});

  final _Movimiento item;

  @override
  Widget build(BuildContext context) {
    final catProvider = context.watch<CategoriaProvider>();
    final categorias =
        catProvider.obtenerActivas(item.esIngreso ? 'ingreso' : 'gasto');
    final catMap = categorias.firstWhere(
      (c) => c['id'] == item.categoriaId || c['nombre'] == item.categoriaId,
      orElse: () => {
        'nombre': item.categoriaId,
        'icono': 'category',
        'color': '#6B7A99',
      },
    );
    final color = item.esIngreso ? AppTheme.verdeIngreso : AppTheme.rojoGasto;
    final iconoColor = colorFromHex(catMap['color'] as String? ?? '#6B7A99');
    final icono = iconFromNombre(catMap['icono'] as String? ?? 'category');
    final titulo = item.descripcion?.isNotEmpty == true
        ? item.descripcion!
        : (catMap['nombre'] as String? ?? item.categoriaId);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconoColor.withAlpha(38),
        child: Icon(icono, color: iconoColor, size: 20),
      ),
      title: Text(titulo, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(
        _formatFecha(item.fecha),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${item.esIngreso ? '+' : '-'}${_formatMonto(item.monto)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (item.comprobante?.isNotEmpty == true)
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(item.comprobante!)),
              child: const Icon(Icons.receipt,
                  size: 16, color: AppTheme.azulMedio),
            ),
        ],
      ),
    );
  }
}

// ── Botones acción rápida ─────────────────────────────────────────────────────

class _BotonesAccionRapida extends StatelessWidget {
  const _BotonesAccionRapida();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.verdeIngreso,
              foregroundColor: AppTheme.blanco,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const AgregarMovimientoScreen(tipoInicial: 'ingreso'),
              ),
            ),
            icon: const Icon(Icons.arrow_downward, size: 16),
            label: const Text('+ Ingreso',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.rojoGasto,
              foregroundColor: AppTheme.blanco,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const AgregarMovimientoScreen(tipoInicial: 'gasto'),
              ),
            ),
            icon: const Icon(Icons.arrow_upward, size: 16),
            label: const Text('+ Gasto',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _BienTile extends StatelessWidget {
  const _BienTile({required this.bien});
  final BienInventario bien;

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

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado(bien.estado);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(38),
        child: Icon(Icons.inventory_2_outlined, color: color, size: 20),
      ),
      title: Text(
        bien.descripcion,
        style: Theme.of(context).textTheme.bodyLarge,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        bien.codigo,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: AppTheme.textoSecundario,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Text(
          _labelEstado(bien.estado),
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
