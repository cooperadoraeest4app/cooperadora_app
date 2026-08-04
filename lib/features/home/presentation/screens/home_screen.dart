import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/campana_notificaciones_widget.dart';
import '../../../../shared/widgets/logo_cooperadora_widget.dart';
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
import '../../../votaciones/presentation/screens/votaciones_screen.dart';

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
  final String? nroComprobante;
  final bool recurrente;
  final String? frecuenciaId;

  const _Movimiento({
    required this.esIngreso,
    required this.monto,
    required this.fecha,
    this.descripcion,
    required this.categoriaId,
    this.comprobante,
    this.nroComprobante,
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
      nroComprobante: i.nroComprobante,
      recurrente: i.recurrente,
      frecuenciaId: i.frecuenciaId);

  factory _Movimiento.fromGasto(Gasto g) => _Movimiento(
      esIngreso: false,
      monto: g.monto,
      fecha: g.fecha,
      descripcion: g.descripcion,
      categoriaId: g.categoriaId,
      comprobante: g.comprobante,
      nroComprobante: g.nroComprobante,
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: null,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: const [CampanaNotificacionesWidget(), AccionAuthWidget()],
      ),
      drawer: const AppDrawer(esInicio: true),
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
                    const SizedBox(height: 8),
                    _SaldoCard(
                      totalIngresosMes: totalIngresosMes,
                      totalGastosMes: totalGastosMes,
                    ),
                    const _SeccionProyectosYVotaciones(),
                    _SeccionTabsMovimientosInventario(movimientos: ultimos10),
                    const SizedBox(height: 20),
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
          const LogoCooperadoraWidget(size: 80, borderRadius: 16),
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
          const SizedBox(height: 8),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('configuracion')
                .doc('config')
                .snapshots(),
            builder: (context, snap) {
              final data =
                  snap.data?.data() as Map<String, dynamic>? ?? {};
              final telefono =
                  data['telefonoContacto'] as String?;
              final email = data['emailContacto'] as String?;

              if (telefono == null && email == null) {
                return const SizedBox.shrink();
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (telefono != null)
                    IconButton(
                      tooltip: 'Contactar por WhatsApp',
                      icon: Image.asset(
                          'assets/icons/icons8-whatsapp-96.png',
                          width: 28,
                          height: 28),
                      onPressed: () async {
                        final numero = telefono.replaceAll(
                            RegExp(r'[\s\-\(\)\+]'), '');
                        final numeroCompleto = numero.startsWith('54')
                            ? numero
                            : '54$numero';
                        final url = Uri.parse(
                            'https://wa.me/$numeroCompleto?text=Hola%20Coope!');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  if (email != null)
                    IconButton(
                      tooltip: 'Copiar email de contacto',
                      icon: Image.asset(
                          'assets/icons/icons8-mail-96.png',
                          width: 28,
                          height: 28),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: email));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Email copiado: $email'),
                                ],
                              ),
                              backgroundColor: AppTheme.verdeTeal,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                ],
              );
            },
          ),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.celesteBorde),
      ),
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

// ── Proyectos + Votaciones (tabs principales) ─────────────────────────────────

class _SeccionProyectosYVotaciones extends StatefulWidget {
  const _SeccionProyectosYVotaciones();

  @override
  State<_SeccionProyectosYVotaciones> createState() =>
      _SeccionProyectosYVotacionesState();
}

class _SeccionProyectosYVotacionesState
    extends State<_SeccionProyectosYVotaciones> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.celesteBorde),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Tab bar superior con colores por tab activo
            TabBar(
              onTap: (i) => setState(() => _tabIndex = i),
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(
                  color: _tabIndex == 0
                      ? AppTheme.azulOscuro
                      : AppTheme.verdeTeal,
                  width: 3,
                ),
              ),
              dividerColor: AppTheme.celesteBorde,
              labelPadding: EdgeInsets.zero,
              tabs: [
                Tab(
                  height: 46,
                  child: Container(
                    width: double.infinity,
                    color: _tabIndex == 0
                        ? AppTheme.celesteFondo
                        : const Color(0xFFF2F2F2),
                    alignment: Alignment.center,
                    child: Text(
                      'Proyectos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _tabIndex == 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: _tabIndex == 0
                            ? AppTheme.azulOscuro
                            : AppTheme.textoSecundario,
                      ),
                    ),
                  ),
                ),
                Tab(
                  height: 46,
                  child: Container(
                    width: double.infinity,
                    color: _tabIndex == 1
                        ? const Color(0xFFE8F8F1)
                        : const Color(0xFFF2F2F2),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Votaciones activas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _tabIndex == 1
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _tabIndex == 1
                                ? AppTheme.verdeTeal
                                : AppTheme.textoSecundario,
                          ),
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('votaciones')
                              .where('estado', isEqualTo: 'en_curso')
                              .snapshots(),
                          builder: (context, snap) {
                            final count = snap.data?.docs.length ?? 0;
                            if (count == 0) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.rojoGasto,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Contenido
            const SizedBox(
              height: 280,
              child: TabBarView(
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _TabProyectos(),
                  SeccionVotacionesHome(mostrarVerTodas: false),
                ],
              ),
            ),
            // Footer
            Container(
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppTheme.celesteBorde)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      foregroundColor: AppTheme.azulMedio,
                    ),
                    onPressed: () {
                      if (_tabIndex == 0) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProyectosScreen()),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const VotacionesScreen()),
                        );
                      }
                    },
                    child: const Text('Ver todos →',
                        style: TextStyle(fontSize: 12)),
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

class _TabProyectos extends StatelessWidget {
  const _TabProyectos();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProyectoProvider>();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: AppTheme.azulMedio,
            unselectedLabelColor: AppTheme.textoSecundario,
            indicatorColor: AppTheme.azulMedio,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'En curso (${provider.enCurso.length})'),
              Tab(text: 'Planificados (${provider.planificados.length})'),
              Tab(text: 'Finalizados (${provider.finalizados.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ListaProyectosHome(
                    proyectos: provider.enCurso.take(5).toList()),
                _ListaProyectosHome(
                    proyectos: provider.planificados.take(5).toList()),
                _ListaProyectosHome(
                    proyectos: provider.finalizados.take(5).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListaProyectosHome extends StatelessWidget {
  const _ListaProyectosHome({required this.proyectos});

  final List<Proyecto> proyectos;

  @override
  Widget build(BuildContext context) {
    if (proyectos.isEmpty) {
      return const Center(
        child: Text(
          'Sin proyectos',
          style: TextStyle(color: AppTheme.textoSecundario),
        ),
      );
    }
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: proyectos.length,
      itemBuilder: (_, i) => _ProyectoCard(proyecto: proyectos[i]),
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
              builder: (_) => ProyectoDetalleScreen(
                proyecto: proyecto,
                onTabSelected: (index) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProyectosScreen(initialTab: index),
                  ),
                ),
              ),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.celesteBorde),
      ),
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

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: iconoColor.withAlpha(38),
                child: Icon(icono, color: iconoColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(titulo,
                        style: Theme.of(context).textTheme.bodyLarge),
                    Text(
                      _formatFecha(item.fecha),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
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
                  if (item.nroComprobante != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tag,
                            size: 14, color: AppTheme.textoSecundario),
                        const SizedBox(width: 2),
                        Text(
                          item.nroComprobante!,
                          style: const TextStyle(
                              color: AppTheme.textoSecundario, fontSize: 11),
                        ),
                      ],
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
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(38),
                child: Icon(Icons.inventory_2_outlined, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bien.descripcion,
                      style: Theme.of(context).textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      bien.codigo,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
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
            ],
          ),
        ),
      ),
    );
  }
}
