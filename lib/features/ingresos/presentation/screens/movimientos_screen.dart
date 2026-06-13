import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/categorias_data.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../admin/presentation/screens/admin_panel_screen.dart';
import '../../../gastos/domain/models/gasto.dart';
import '../../../ingresos/domain/models/ingreso.dart';
import '../providers/movimientos_provider.dart';
import 'agregar_movimiento_screen.dart';

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

class _MovimientoUnificado {
  final bool esIngreso;
  final double monto;
  final DateTime fecha;
  final String? descripcion;
  final String categoriaId;
  final String? comprobante;

  const _MovimientoUnificado({
    required this.esIngreso,
    required this.monto,
    required this.fecha,
    this.descripcion,
    required this.categoriaId,
    this.comprobante,
  });

  factory _MovimientoUnificado.fromIngreso(Ingreso i) =>
      _MovimientoUnificado(
        esIngreso: true,
        monto: i.monto,
        fecha: i.fecha,
        descripcion: i.descripcion,
        categoriaId: i.categoriaId,
        comprobante: i.comprobante,
      );

  factory _MovimientoUnificado.fromGasto(Gasto g) =>
      _MovimientoUnificado(
        esIngreso: false,
        monto: g.monto,
        fecha: g.fecha,
        descripcion: g.descripcion,
        categoriaId: g.categoriaId,
        comprobante: g.comprobante,
      );
}

class MovimientosScreen extends StatelessWidget {
  const MovimientosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovimientosProvider>();
    final auth = context.watch<AuthProvider>();
    // TODO(roles): verificar también rol 'editor' o 'admin' además del login
    final puedeAgregar = auth.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: [_AccionAuth()],
      ),
      body: StreamBuilder<List<Ingreso>>(
        stream: provider.ingresos,
        builder: (context, ingresoSnap) {
          return StreamBuilder<List<Gasto>>(
            stream: provider.gastos,
            builder: (context, gastoSnap) {
              final loading =
                  ingresoSnap.connectionState == ConnectionState.waiting ||
                      gastoSnap.connectionState == ConnectionState.waiting;

              final ingresos = ingresoSnap.data ?? [];
              final gastos = gastoSnap.data ?? [];

              final totalIngresos =
                  ingresos.fold(0.0, (sum, i) => sum + i.monto);
              final totalGastos =
                  gastos.fold(0.0, (sum, g) => sum + g.monto);

              final movimientos = [
                ...ingresos.map(_MovimientoUnificado.fromIngreso),
                ...gastos.map(_MovimientoUnificado.fromGasto),
              ]..sort((a, b) => b.fecha.compareTo(a.fecha));

              return Column(
                children: [
                  _ResumenRow(
                    totalIngresos: totalIngresos,
                    totalGastos: totalGastos,
                  ),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : movimientos.isEmpty
                            ? const _EmptyState()
                            : Card(
                                margin: const EdgeInsets.fromLTRB(
                                    16, 0, 16, 16),
                                child: ListView.separated(
                                  itemCount: movimientos.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1, indent: 72),
                                  itemBuilder: (context, index) =>
                                      _MovimientoTile(
                                          item: movimientos[index]),
                                ),
                              ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: puedeAgregar
          ? Padding(
              padding: const EdgeInsets.only(bottom: 16, right: 16),
              child: FloatingActionButton(
                backgroundColor: AppTheme.verdeTeal,
                foregroundColor: AppTheme.blanco,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AgregarMovimientoScreen()),
                ),
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }
}

class _ResumenRow extends StatelessWidget {
  const _ResumenRow({
    required this.totalIngresos,
    required this.totalGastos,
  });

  final double totalIngresos;
  final double totalGastos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _TarjetaResumen(
              label: 'Total ingresos',
              monto: totalIngresos,
              color: AppTheme.verdeIngreso,
              icono: Icons.arrow_upward,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TarjetaResumen(
              label: 'Total gastos',
              monto: totalGastos,
              color: AppTheme.rojoGasto,
              icono: Icons.arrow_downward,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatMonto(monto),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                    overflow: TextOverflow.ellipsis,
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

  final _MovimientoUnificado item;

  @override
  Widget build(BuildContext context) {
    final categoria = findCategoria(
      item.categoriaId,
      esIngreso: item.esIngreso,
    );
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
      title: Text(
        titulo,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
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
          if (item.comprobante != null && item.comprobante!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.receipt,
                  size: 18, color: AppTheme.azulMedio),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () =>
                  launchUrl(Uri.parse(item.comprobante!)),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: AppTheme.textoSecundario.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin movimientos registrados',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textoSecundario,
                ),
          ),
        ],
      ),
    );
  }
}

class _AccionAuth extends StatelessWidget {
  const _AccionAuth();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return IconButton(
        icon: const Icon(Icons.login),
        tooltip: 'Ingresar',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
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
