import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/categorias_data.dart';
import '../../../admin/presentation/providers/configuracion_provider.dart';
import '../../../admin/presentation/screens/admin_panel_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../gastos/domain/models/gasto.dart';
import '../../../ingresos/domain/models/ingreso.dart';
import '../../../ingresos/presentation/providers/movimientos_provider.dart';
import '../../../ingresos/presentation/screens/agregar_movimiento_screen.dart';
import '../../../ingresos/presentation/screens/movimientos_screen.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatMonto(double monto) {
  final format = monto == monto.truncateToDouble()
      ? NumberFormat('#,##0', 'es_AR')
      : NumberFormat('#,##0.##', 'es_AR');
  return '\$${format.format(monto)}';
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

  const _Movimiento({
    required this.esIngreso,
    required this.monto,
    required this.fecha,
    this.descripcion,
    required this.categoriaId,
  });

  factory _Movimiento.fromIngreso(Ingreso i) => _Movimiento(
      esIngreso: true,
      monto: i.monto,
      fecha: i.fecha,
      descripcion: i.descripcion,
      categoriaId: i.categoriaId);

  factory _Movimiento.fromGasto(Gasto g) => _Movimiento(
      esIngreso: false,
      monto: g.monto,
      fecha: g.fecha,
      descripcion: g.descripcion,
      categoriaId: g.categoriaId);
}

// ── Proyectos de prueba ───────────────────────────────────────────────────────

class _Proyecto {
  final String nombre;
  final String tipo;
  final double presupuesto;
  final double gastado;
  final String estado;
  final int votos;
  final DateTime? fechaCierre;

  _Proyecto({
    required this.nombre,
    required this.tipo,
    required this.presupuesto,
    required this.gastado,
    required this.estado,
    this.votos = 0,
    this.fechaCierre,
  });
}

final _kProyectos = [
  _Proyecto(
    nombre: 'Pintura de aulas',
    tipo: 'Infraestructura',
    presupuesto: 150000,
    gastado: 90000,
    estado: 'en_curso',
    votos: 45,
  ),
  _Proyecto(
    nombre: 'Kiosco saludable',
    tipo: 'Comercio',
    presupuesto: 120000,
    gastado: 60000,
    estado: 'en_curso',
    votos: 30,
  ),
  _Proyecto(
    nombre: 'Sala de computación',
    tipo: 'Tecnología',
    presupuesto: 400000,
    gastado: 180000,
    estado: 'en_curso',
    votos: 58,
  ),
  _Proyecto(
    nombre: 'Biblioteca nueva',
    tipo: 'Equipamiento',
    presupuesto: 200000,
    gastado: 0,
    estado: 'planificado',
    votos: 78,
  ),
  _Proyecto(
    nombre: 'Patio cubierto',
    tipo: 'Infraestructura',
    presupuesto: 500000,
    gastado: 0,
    estado: 'planificado',
    votos: 62,
  ),
  _Proyecto(
    nombre: 'Murales artísticos',
    tipo: 'Arte y cultura',
    presupuesto: 60000,
    gastado: 0,
    estado: 'planificado',
    votos: 41,
  ),
  _Proyecto(
    nombre: 'Acto aniversario',
    tipo: 'Evento',
    presupuesto: 80000,
    gastado: 80000,
    estado: 'finalizado',
    fechaCierre: DateTime(2024, 9, 5),
  ),
  _Proyecto(
    nombre: 'Jornada deportiva',
    tipo: 'Evento',
    presupuesto: 50000,
    gastado: 47000,
    estado: 'finalizado',
    fechaCierre: DateTime(2024, 10, 18),
  ),
];

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
        actions: const [_AccionAuth()],
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
                    _SeccionMovimientos(movimientos: ultimos10),
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
            const Text(
              '\$0',
              style: TextStyle(
                color: AppTheme.textoPrincipal,
                fontSize: 38,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Cuenta bancaria pendiente de configuración',
              style: TextStyle(color: AppTheme.textoSecundario, fontSize: 11),
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

enum _EstadoProyecto { enCurso, planificado, finalizado }

class _SeccionProyectos extends StatelessWidget {
  const _SeccionProyectos();

  @override
  Widget build(BuildContext context) {
    final enCurso =
        _kProyectos.where((p) => p.estado == 'en_curso').take(3).toList();

    final planificados = _kProyectos
        .where((p) => p.estado == 'planificado')
        .toList()
      ..sort((a, b) => b.votos.compareTo(a.votos));

    final finalizados = _kProyectos
        .where((p) => p.estado == 'finalizado')
        .toList()
      ..sort((a, b) =>
          (b.fechaCierre ?? DateTime(0)).compareTo(a.fechaCierre ?? DateTime(0)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubseccionProyectos(
          titulo: 'En curso',
          estado: _EstadoProyecto.enCurso,
          proyectos: enCurso,
        ),
        const SizedBox(height: 20),
        _SubseccionProyectos(
          titulo: 'Planificados',
          estado: _EstadoProyecto.planificado,
          proyectos: planificados.take(3).toList(),
        ),
        const SizedBox(height: 20),
        _SubseccionProyectos(
          titulo: 'Finalizados',
          estado: _EstadoProyecto.finalizado,
          proyectos: finalizados.take(2).toList(),
        ),
      ],
    );
  }
}

class _SubseccionProyectos extends StatelessWidget {
  const _SubseccionProyectos({
    required this.titulo,
    required this.estado,
    required this.proyectos,
  });

  final String titulo;
  final _EstadoProyecto estado;
  final List<_Proyecto> proyectos;

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
                onPressed: () {},
                child: const Text('Ver todos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 158,
          child: proyectos.isEmpty
              ? Center(
                  child: Text(
                    'Sin proyectos',
                    style: const TextStyle(color: AppTheme.textoSecundario),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: proyectos.length,
                  itemBuilder: (ctx, i) => _ProyectoCard(
                    proyecto: proyectos[i],
                    estado: estado,
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProyectoCard extends StatelessWidget {
  const _ProyectoCard({required this.proyecto, required this.estado});

  final _Proyecto proyecto;
  final _EstadoProyecto estado;

  @override
  Widget build(BuildContext context) {
    final chipLabel = switch (estado) {
      _EstadoProyecto.enCurso => 'En curso',
      _EstadoProyecto.planificado => 'Planificado',
      _EstadoProyecto.finalizado => 'Finalizado',
    };
    final chipColor = switch (estado) {
      _EstadoProyecto.enCurso => AppTheme.verdeIngreso,
      _EstadoProyecto.planificado => AppTheme.amarilloAlerta,
      _EstadoProyecto.finalizado => AppTheme.textoSecundario,
    };
    final progreso = proyecto.presupuesto > 0
        ? (proyecto.gastado / proyecto.presupuesto).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      width: 210,
      child: Card(
        margin: const EdgeInsets.only(right: 12, bottom: 4),
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
                proyecto.tipo,
                style: const TextStyle(
                  color: AppTheme.textoSecundario,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (estado == _EstadoProyecto.planificado)
                Row(
                  children: [
                    const Icon(Icons.thumb_up_outlined,
                        size: 12, color: AppTheme.textoSecundario),
                    const SizedBox(width: 4),
                    Text(
                      '${proyecto.votos} votos',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textoSecundario),
                    ),
                  ],
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatMonto(proyecto.gastado),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textoPrincipal,
                      ),
                    ),
                    Text(
                      _formatMonto(proyecto.presupuesto),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textoSecundario),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progreso,
                  backgroundColor: AppTheme.celesteBorde,
                  valueColor: AlwaysStoppedAnimation<Color>(chipColor),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Últimos movimientos ───────────────────────────────────────────────────────

class _SeccionMovimientos extends StatelessWidget {
  const _SeccionMovimientos({required this.movimientos});

  final List<_Movimiento> movimientos;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final puedeAgregar = auth.esEditor || auth.esAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Últimos movimientos',
                style: TextStyle(
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
                      builder: (_) => const MovimientosScreen()),
                ),
                child: const Text('Ver todos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (puedeAgregar) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _BotonesAccionRapida(),
          ),
          const SizedBox(height: 8),
        ],
        if (movimientos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Sin movimientos registrados',
                style: TextStyle(color: AppTheme.textoSecundario),
              ),
            ),
          )
        else
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: movimientos.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) =>
                  _MovimientoTile(item: movimientos[i]),
            ),
          ),
      ],
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({required this.item});

  final _Movimiento item;

  @override
  Widget build(BuildContext context) {
    final categoria =
        findCategoria(item.categoriaId, esIngreso: item.esIngreso);
    final color = item.esIngreso ? AppTheme.verdeIngreso : AppTheme.rojoGasto;
    final iconoColor = categoria?.color ?? color;
    final icono = categoria?.icono ??
        (item.esIngreso ? Icons.arrow_upward : Icons.arrow_downward);
    final titulo = item.descripcion?.isNotEmpty == true
        ? item.descripcion!
        : item.categoriaId;

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
      trailing: Text(
        '${item.esIngreso ? '+' : '-'}${_formatMonto(item.monto)}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
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

// ── Auth actions ──────────────────────────────────────────────────────────────

class _AccionAuth extends StatelessWidget {
  const _AccionAuth();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return Padding(
        padding: const EdgeInsets.only(right: 16),
        child: OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white, width: 1),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          child: const Text('Ingresar'),
        ),
      );
    }

    final email = auth.currentUser?.email ?? '';
    final inicial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: CircleAvatar(
          backgroundColor: AppTheme.celesteAccento,
          radius: 17,
          child: Text(
            inicial,
            style: const TextStyle(
              color: AppTheme.azulOscuro,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            email,
            style: const TextStyle(
              color: AppTheme.textoSecundario,
              fontSize: 12,
            ),
          ),
        ),
        if (auth.esAdmin) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'admin',
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings,
                    size: 18, color: AppTheme.azulMedio),
                SizedBox(width: 8),
                Text('Panel de administración'),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: AppTheme.rojoGasto),
              SizedBox(width: 8),
              Text('Cerrar sesión'),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'admin') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
          );
        } else if (value == 'logout') {
          context.read<AuthProvider>().logout();
        }
      },
    );
  }
}
