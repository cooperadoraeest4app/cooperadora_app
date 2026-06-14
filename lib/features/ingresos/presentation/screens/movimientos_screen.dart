import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/categorias_data.dart';
import '../../../../shared/utils/metodo_pago_icon.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../admin/presentation/providers/categoria_provider.dart';
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

String _formatFechaHora(DateTime dt) =>
    '${_formatFecha(dt)} '
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

class _MovimientoUnificado {
  final String id;
  final bool esIngreso;
  final double monto;
  final DateTime fecha;
  final String? descripcion;
  final String categoriaId;
  final String metodoPagoId;
  final String? donante;
  final String usuarioId;
  final DateTime fechaCreacion;
  final String? comprobante;
  final Ingreso? ingreso;
  final Gasto? gasto;

  const _MovimientoUnificado({
    required this.id,
    required this.esIngreso,
    required this.monto,
    required this.fecha,
    this.descripcion,
    required this.categoriaId,
    required this.metodoPagoId,
    this.donante,
    required this.usuarioId,
    required this.fechaCreacion,
    this.comprobante,
    this.ingreso,
    this.gasto,
  });

  factory _MovimientoUnificado.fromIngreso(Ingreso i) =>
      _MovimientoUnificado(
        id: i.id,
        esIngreso: true,
        monto: i.monto,
        fecha: i.fecha,
        descripcion: i.descripcion,
        categoriaId: i.categoriaId,
        metodoPagoId: i.metodoPagoId,
        donante: i.donante,
        usuarioId: i.usuarioId,
        fechaCreacion: i.fechaCreacion,
        comprobante: i.comprobante,
        ingreso: i,
      );

  factory _MovimientoUnificado.fromGasto(Gasto g) => _MovimientoUnificado(
        id: g.id,
        esIngreso: false,
        monto: g.monto,
        fecha: g.fecha,
        descripcion: g.descripcion,
        categoriaId: g.categoriaId,
        metodoPagoId: g.metodoPagoId,
        donante: null,
        usuarioId: g.usuarioId,
        fechaCreacion: g.fechaCreacion,
        comprobante: g.comprobante,
        gasto: g,
      );
}

class MovimientosScreen extends StatefulWidget {
  const MovimientosScreen({super.key, this.proyectoId});

  final String? proyectoId;

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  bool _soloRecurrentes = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovimientosProvider>();
    final auth = context.watch<AuthProvider>();
    final puedeAgregar = auth.esEditor;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.proyectoId != null
            ? 'Movimientos del proyecto'
            : 'Movimientos'),
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
                  ingresos.fold<double>(0.0, (acc, i) => acc + i.monto);
              final totalGastos =
                  gastos.fold<double>(0.0, (acc, g) => acc + g.monto);

              var movimientos = [
                ...ingresos.map(_MovimientoUnificado.fromIngreso),
                ...gastos.map(_MovimientoUnificado.fromGasto),
              ]..sort((a, b) => b.fecha.compareTo(a.fecha));

              if (widget.proyectoId != null) {
                movimientos = movimientos
                    .where((m) =>
                        m.ingreso?.proyectoId == widget.proyectoId ||
                        m.gasto?.proyectoId == widget.proyectoId)
                    .toList();
              }

              if (_soloRecurrentes) {
                movimientos = movimientos
                    .where((m) =>
                        m.ingreso?.recurrente == true ||
                        m.gasto?.recurrente == true)
                    .toList();
              }

              return Column(
                children: [
                  _ResumenRow(
                    totalIngresos: totalIngresos,
                    totalGastos: totalGastos,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Text(
                          'Solo Gastos e Ingresos recurrentes',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textoPrincipal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: _soloRecurrentes,
                          onChanged: (v) =>
                              setState(() => _soloRecurrentes = v),
                          activeThumbColor: AppTheme.verdeTeal,
                          inactiveThumbColor: AppTheme.blanco,
                          inactiveTrackColor:
                              AppTheme.azulOscuro.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : movimientos.isEmpty
                            ? _EmptyState(
                                mensaje: _soloRecurrentes
                                    ? 'No hay movimientos recurrentes registrados'
                                    : null,
                              )
                            : Card(
                                margin:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 16),
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

class _MovimientoTile extends StatefulWidget {
  const _MovimientoTile({required this.item});
  final _MovimientoUnificado item;

  @override
  State<_MovimientoTile> createState() => _MovimientoTileState();
}

class _MovimientoTileState extends State<_MovimientoTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final auth = context.watch<AuthProvider>();
    final catProvider = context.watch<CategoriaProvider>();
    final categorias =
        catProvider.obtenerActivas(item.esIngreso ? 'ingreso' : 'gasto');
    final catMap = categorias.firstWhere(
      (c) =>
          c['id'] == item.categoriaId || c['nombre'] == item.categoriaId,
      orElse: () => {
        'nombre': item.categoriaId,
        'icono': 'category',
        'color': '#6B7A99',
      },
    );
    final color = item.esIngreso ? AppTheme.verdeIngreso : AppTheme.rojoGasto;
    final categoriaColor =
        colorFromHex(catMap['color'] as String? ?? '#6B7A99');
    final categoriaIcono =
        iconFromNombre(catMap['icono'] as String? ?? 'category');
    final categoriaNombre = catMap['nombre'] as String? ?? item.categoriaId;
    final titulo = item.descripcion?.isNotEmpty == true
        ? item.descripcion!
        : categoriaNombre;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: categoriaColor.withAlpha(38),
            child: Icon(categoriaIcono, color: categoriaColor, size: 20),
          ),
          title: Text(titulo, style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text(_formatFecha(item.fecha),
              style: Theme.of(context).textTheme.bodySmall),
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
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.textoSecundario,
                size: 18,
              ),
            ],
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          _buildDetalle(
              context, item, auth, categoriaColor, categoriaIcono,
              categoriaNombre, color),
      ],
    );
  }

  Widget _buildDetalle(
    BuildContext context,
    _MovimientoUnificado item,
    AuthProvider auth,
    Color categoriaColor,
    IconData categoriaIcono,
    String categoriaNombre,
    Color color,
  ) {
    return Container(
      color: AppTheme.celesteFondo,
      padding: const EdgeInsets.fromLTRB(72, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetalleRow(
            icono: categoriaIcono,
            iconoColor: categoriaColor,
            texto: categoriaNombre,
          ),
          _DetalleRow(
            icono: MetodoPagoIcon.iconOf(item.metodoPagoId),
            iconoColor: AppTheme.azulMedio,
            texto: item.metodoPagoId,
          ),
          if (item.descripcion?.isNotEmpty == true)
            _DetalleRow(
              icono: Icons.notes,
              iconoColor: AppTheme.textoSecundario,
              texto: item.descripcion!,
            ),
          if (item.esIngreso && item.donante?.isNotEmpty == true)
            _DetalleRow(
              icono: Icons.person,
              iconoColor: AppTheme.textoSecundario,
              texto: item.donante!,
            ),
          _DetalleRow(
            icono: Icons.badge,
            iconoColor: AppTheme.textoSecundario,
            texto: 'Cargado por: ${item.usuarioId}',
          ),
          _DetalleRow(
            icono: Icons.schedule,
            iconoColor: AppTheme.textoSecundario,
            texto: _formatFechaHora(item.fechaCreacion),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (item.comprobante?.isNotEmpty == true)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.receipt, size: 16),
                  label: const Text('Ver comprobante',
                      style: TextStyle(fontSize: 13)),
                  onPressed: () => launchUrl(Uri.parse(item.comprobante!)),
                ),
              const Spacer(),
              if (auth.esEditor)
                IconButton(
                  icon: const Icon(Icons.edit,
                      size: 20, color: AppTheme.azulMedio),
                  tooltip: 'Editar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => item.esIngreso
                            ? AgregarMovimientoScreen(
                                ingresoEditar: item.ingreso)
                            : AgregarMovimientoScreen(
                                gastoEditar: item.gasto),
                      ),
                    );
                  },
                ),
              if (auth.esAdmin) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete,
                      size: 20, color: AppTheme.rojoGasto),
                  tooltip: 'Eliminar',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmarEliminar(item),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminar(_MovimientoUnificado item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar movimiento',
            style: TextStyle(color: AppTheme.textoPrincipal)),
        content: Text(
          '¿Seguro que querés eliminar este '
          '${item.esIngreso ? 'ingreso' : 'gasto'} '
          'de ${_formatMonto(item.monto)}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.rojoGasto),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      final provider = context.read<MovimientosProvider>();
      if (item.esIngreso) {
        await provider.eliminarIngreso(item.id);
      } else {
        await provider.eliminarGasto(item.id);
      }
      if (mounted) setState(() => _expanded = false);
    }
  }
}

class _DetalleRow extends StatelessWidget {
  const _DetalleRow({
    required this.icono,
    required this.iconoColor,
    required this.texto,
  });

  final IconData icono;
  final Color iconoColor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icono, size: 14, color: iconoColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textoPrincipal),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.mensaje});

  final String? mensaje;

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
            mensaje ?? 'Sin movimientos registrados',
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
        if (auth.esAdmin || auth.esAuditor) ...[
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
