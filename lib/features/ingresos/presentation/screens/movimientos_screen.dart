import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/categorias_data.dart';
import '../../../../shared/utils/metodo_pago_icon.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/nombre_usuario_widget.dart';
import '../../../admin/presentation/providers/categoria_provider.dart';
import '../../../admin/presentation/providers/metodo_pago_provider.dart';
import '../../../admin/presentation/providers/usuarios_provider.dart';
import '../../../gastos/domain/models/gasto.dart';
import '../../../ingresos/domain/models/ingreso.dart';
import '../providers/frecuencia_provider.dart';
import '../providers/movimientos_provider.dart';
import '../../../proyectos/presentation/providers/proyecto_provider.dart';
import '../../../proyectos/presentation/screens/proyecto_detalle_screen.dart';
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
  final bool recurrente;
  final String? frecuenciaId;
  final DateTime? proximaFecha;
  final String? proyectoId;
  final String? ultimaModificacionPor;
  final DateTime? ultimaModificacionFecha;
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
    this.recurrente = false,
    this.frecuenciaId,
    this.proximaFecha,
    this.proyectoId,
    this.ultimaModificacionPor,
    this.ultimaModificacionFecha,
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
        recurrente: i.recurrente,
        frecuenciaId: i.frecuenciaId,
        proximaFecha: i.proximaFecha,
        proyectoId: i.proyectoId,
        ultimaModificacionPor: i.ultimaModificacionPor,
        ultimaModificacionFecha: i.ultimaModificacionFecha,
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
        recurrente: g.recurrente,
        frecuenciaId: g.frecuenciaId,
        proximaFecha: g.proximaFecha,
        proyectoId: g.proyectoId,
        ultimaModificacionPor: g.ultimaModificacionPor,
        ultimaModificacionFecha: g.ultimaModificacionFecha,
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
  String? _frecuenciaFiltro;

  bool _mostrarFiltros = false;
  String _filtroTipo = 'ambos';
  DateTime? _filtroDesde;
  DateTime? _filtroHasta;
  String? _filtroCategoria;
  String? _filtroMetodoPago;
  String? _filtroUsuario;
  bool _buscarEnCreado = true;
  bool _buscarEnModificado = false;

  int get _filtrosActivos {
    int c = 0;
    if (_filtroTipo != 'ambos') c++;
    if (_filtroDesde != null) c++;
    if (_filtroHasta != null) c++;
    if (_filtroCategoria != null) c++;
    if (_filtroMetodoPago != null) c++;
    if (_filtroUsuario != null) c++;
    return c;
  }

  List<_MovimientoUnificado> _aplicarFiltros(List<_MovimientoUnificado> lista) {
    return lista.where((m) {
      if (_filtroTipo == 'ingreso' && !m.esIngreso) return false;
      if (_filtroTipo == 'gasto' && m.esIngreso) return false;
      if (_filtroDesde != null && m.fecha.isBefore(_filtroDesde!)) return false;
      if (_filtroHasta != null &&
          m.fecha.isAfter(_filtroHasta!.add(const Duration(days: 1)))) {
        return false;
      }
      if (_filtroCategoria != null && m.categoriaId != _filtroCategoria) {
        return false;
      }
      if (_filtroMetodoPago != null && m.metodoPagoId != _filtroMetodoPago) {
        return false;
      }
      if (_filtroUsuario != null) {
        final enCreado = _buscarEnCreado && m.usuarioId == _filtroUsuario;
        final enModificado =
            _buscarEnModificado && m.ultimaModificacionPor == _filtroUsuario;
        if (!enCreado && !enModificado) return false;
      }
      return true;
    }).toList();
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroTipo = 'ambos';
      _filtroDesde = null;
      _filtroHasta = null;
      _filtroCategoria = null;
      _filtroMetodoPago = null;
      _filtroUsuario = null;
      _buscarEnCreado = true;
      _buscarEnModificado = false;
      _mostrarFiltros = false;
    });
  }

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
        actions: const [AccionAuthWidget()],
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
                if (_frecuenciaFiltro != null) {
                  movimientos = movimientos
                      .where((m) => m.frecuenciaId == _frecuenciaFiltro)
                      .toList();
                }
              }

              if (auth.isLoggedIn) {
                movimientos = _aplicarFiltros(movimientos);
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
                      children: [
                        const Flexible(
                          child: Text(
                            'Solo Gastos e Ingresos recurrentes',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textoPrincipal,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: _soloRecurrentes,
                          onChanged: (v) => setState(() {
                            _soloRecurrentes = v;
                            if (!v) _frecuenciaFiltro = null;
                          }),
                          activeThumbColor: AppTheme.verdeTeal,
                          inactiveThumbColor: AppTheme.blanco,
                          inactiveTrackColor:
                              AppTheme.azulOscuro.withValues(alpha: 0.3),
                        ),
                        if (_soloRecurrentes) ...[
                          const SizedBox(width: 12),
                          const Text(
                            'Frecuencia:',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textoSecundario),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 140,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _frecuenciaFiltro,
                                  isDense: true,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(
                                        value: null, child: Text('Todas')),
                                    ...context
                                        .watch<FrecuenciaProvider>()
                                        .frecuencias
                                        .map((f) => DropdownMenuItem(
                                              value: f.id,
                                              child: Text(f.nombre),
                                            )),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _frecuenciaFiltro = v),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (auth.isLoggedIn) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(
                              () => _mostrarFiltros = !_mostrarFiltros),
                          icon: const Icon(Icons.tune, size: 16),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Filtros'),
                              if (_filtrosActivos > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.azulMedio,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_filtrosActivos',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.azulMedio,
                            backgroundColor: AppTheme.celesteAccento
                                .withValues(alpha: 0.2),
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: _mostrarFiltros
                            ? _PanelFiltros(
                                filtroTipo: _filtroTipo,
                                filtroDesde: _filtroDesde,
                                filtroHasta: _filtroHasta,
                                filtroCategoria: _filtroCategoria,
                                filtroMetodoPago: _filtroMetodoPago,
                                filtroUsuario: _filtroUsuario,
                                buscarEnCreado: _buscarEnCreado,
                                buscarEnModificado: _buscarEnModificado,
                                onAplicar: (tipo, desde, hasta, categoria,
                                    metodoPago, usuario, creado, modificado) {
                                  setState(() {
                                    _filtroTipo = tipo;
                                    _filtroDesde = desde;
                                    _filtroHasta = hasta;
                                    _filtroCategoria = categoria;
                                    _filtroMetodoPago = metodoPago;
                                    _filtroUsuario = usuario;
                                    _buscarEnCreado = creado;
                                    _buscarEnModificado = modificado;
                                    _mostrarFiltros = false;
                                  });
                                },
                                onLimpiar: _limpiarFiltros,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : movimientos.isEmpty
                            ? (auth.isLoggedIn && _filtrosActivos > 0
                                ? _EmptyStateFiltros(
                                    onLimpiar: _limpiarFiltros)
                                : _EmptyState(
                                    mensaje: _soloRecurrentes
                                        ? 'No hay movimientos recurrentes registrados'
                                        : null,
                                  ))
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
          if (item.proyectoId?.isNotEmpty == true)
            _buildProyectoRow(context, item.proyectoId!),
          if (auth.isLoggedIn)
            _DetalleRow(
              icono: Icons.badge,
              iconoColor: AppTheme.textoSecundario,
              child: NombreUsuarioWidget(
                usuarioId: item.usuarioId,
                prefijo: 'Cargado por: ',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textoPrincipal),
              ),
            ),
          _DetalleRow(
            icono: Icons.schedule,
            iconoColor: AppTheme.textoSecundario,
            texto: _formatFechaHora(item.fechaCreacion),
          ),
          if (auth.isLoggedIn && item.ultimaModificacionPor != null) ...[
            Builder(builder: (_) {
              debugPrint(
                  '[movimientos] ultimaModificacionPor=${item.ultimaModificacionPor} '
                  'fecha=${item.ultimaModificacionFecha}');
              return const SizedBox.shrink();
            }),
            _DetalleRow(
              icono: Icons.edit_outlined,
              iconoColor: AppTheme.textoSecundario,
              child: Row(
                children: [
                  NombreUsuarioWidget(
                    usuarioId: item.ultimaModificacionPor!,
                    prefijo: 'Modificado por: ',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textoPrincipal),
                  ),
                  if (item.ultimaModificacionFecha != null)
                    Text(
                      ' · ${_formatFechaHora(item.ultimaModificacionFecha!)}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textoSecundario),
                    ),
                ],
              ),
            ),
          ],
          if (item.recurrente) _buildRecurrencia(context, item),
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

  Widget _buildProyectoRow(BuildContext context, String proyectoId) {
    final prov = context.watch<ProyectoProvider>();
    if (prov.isLoading) return const SizedBox.shrink();
    final proyecto = prov.obtenerPorId(proyectoId);
    if (proyecto == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProyectoDetalleScreen(proyecto: proyecto),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined,
                size: 14, color: AppTheme.azulMedio),
            const SizedBox(width: 6),
            Text(
              'Proyecto: ${proyecto.nombre}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.azulMedio,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.azulMedio,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrencia(BuildContext context, _MovimientoUnificado item) {
    final frecuencias = context.watch<FrecuenciaProvider>().frecuencias;
    final fid = item.frecuenciaId;
    final nombreFrecuencia = frecuencias.isEmpty || fid == null
        ? ''
        : frecuencias
            .firstWhere((f) => f.id == fid,
                orElse: () =>
                    FrecuenciaRecurrencia(id: '', nombre: '', diasIntervalo: 0))
            .nombre;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nombreFrecuencia.isNotEmpty)
          _DetalleRow(
            icono: Icons.repeat,
            iconoColor: AppTheme.azulMedio,
            texto: 'Recurrente · $nombreFrecuencia',
          ),
        if (item.proximaFecha != null)
          _DetalleRow(
            icono: Icons.event,
            iconoColor: AppTheme.azulMedio,
            texto: 'Próxima fecha: ${_formatFecha(item.proximaFecha!)}',
          ),
      ],
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
    this.texto,
    this.child,
  });

  final IconData icono;
  final Color iconoColor;
  final String? texto;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icono, size: 14, color: iconoColor),
          const SizedBox(width: 6),
          Expanded(
            child: child ??
                Text(
                  texto ?? '',
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

class _EmptyStateFiltros extends StatelessWidget {
  const _EmptyStateFiltros({required this.onLimpiar});

  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppTheme.textoSecundario.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay movimientos que coincidan\ncon los filtros aplicados',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textoSecundario,
                ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onLimpiar,
            icon: const Icon(Icons.filter_alt_off, size: 16),
            label: const Text('Limpiar filtros'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.azulMedio,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelFiltros extends StatefulWidget {
  const _PanelFiltros({
    required this.filtroTipo,
    required this.filtroDesde,
    required this.filtroHasta,
    required this.filtroCategoria,
    required this.filtroMetodoPago,
    required this.filtroUsuario,
    required this.buscarEnCreado,
    required this.buscarEnModificado,
    required this.onAplicar,
    required this.onLimpiar,
  });

  final String filtroTipo;
  final DateTime? filtroDesde;
  final DateTime? filtroHasta;
  final String? filtroCategoria;
  final String? filtroMetodoPago;
  final String? filtroUsuario;
  final bool buscarEnCreado;
  final bool buscarEnModificado;
  final void Function(
    String tipo,
    DateTime? desde,
    DateTime? hasta,
    String? categoria,
    String? metodoPago,
    String? usuario,
    bool buscarEnCreado,
    bool buscarEnModificado,
  ) onAplicar;
  final VoidCallback onLimpiar;

  @override
  State<_PanelFiltros> createState() => _PanelFiltrosState();
}

class _PanelFiltrosState extends State<_PanelFiltros> {
  late String _tipo;
  late DateTime? _desde;
  late DateTime? _hasta;
  late String? _categoria;
  late String? _metodoPago;
  late String? _usuario;
  late bool _buscarEnCreado;
  late bool _buscarEnModificado;

  @override
  void initState() {
    super.initState();
    _tipo = widget.filtroTipo;
    _desde = widget.filtroDesde;
    _hasta = widget.filtroHasta;
    _categoria = widget.filtroCategoria;
    _metodoPago = widget.filtroMetodoPago;
    _usuario = widget.filtroUsuario;
    _buscarEnCreado = widget.buscarEnCreado;
    _buscarEnModificado = widget.buscarEnModificado;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UsuariosProvider>().iniciarSiNecesario();
    });
  }

  Future<void> _seleccionarFecha(bool esDesde) async {
    final inicial = esDesde ? (_desde ?? DateTime.now()) : (_hasta ?? DateTime.now());
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (fecha != null && mounted) {
      setState(() => esDesde ? _desde = fecha : _hasta = fecha);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catProvider = context.watch<CategoriaProvider>();
    final metodoProvider = context.watch<MetodoPagoProvider>();
    final usuariosProvider = context.watch<UsuariosProvider>();

    final cats = [
      ...catProvider.obtenerActivas('ingreso'),
      ...catProvider.obtenerActivas('gasto'),
    ];
    final metodos = metodoProvider.obtenerActivos();
    final usuarios = usuariosProvider.usuarios;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.celesteBorde),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTipoSelector(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildFechaField('Desde', _desde, true)),
                const SizedBox(width: 12),
                Expanded(child: _buildFechaField('Hasta', _hasta, false)),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdown<String?>(
              label: 'Categoría',
              value: _categoria,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ...cats.map((c) => DropdownMenuItem<String>(
                      value: c['id'] as String,
                      child: Text(c['nombre'] as String),
                    )),
              ],
              onChanged: (v) => setState(() => _categoria = v),
            ),
            const SizedBox(height: 12),
            _buildDropdown<String?>(
              label: 'Forma de pago',
              value: _metodoPago,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ...metodos.map((m) => DropdownMenuItem<String>(
                      value: m['nombre'] as String,
                      child: Text(m['nombre'] as String),
                    )),
                const DropdownMenuItem(
                    value: 'Caja Chica', child: Text('Caja Chica')),
              ],
              onChanged: (v) => setState(() => _metodoPago = v),
            ),
            const SizedBox(height: 12),
            _buildDropdown<String?>(
              label: 'Usuario',
              value: _usuario,
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ...usuarios.map((u) => DropdownMenuItem<String>(
                      value: u['id'] as String,
                      child: Text(u['nombreCompleto'] as String? ??
                          u['email'] as String? ?? ''),
                    )),
              ],
              onChanged: (v) => setState(() => _usuario = v),
            ),
            if (_usuario != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Creado por',
                          style: TextStyle(fontSize: 13)),
                      value: _buscarEnCreado,
                      onChanged: (v) =>
                          setState(() => _buscarEnCreado = v ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppTheme.azulMedio,
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Modificado por',
                          style: TextStyle(fontSize: 13)),
                      value: _buscarEnModificado,
                      onChanged: (v) =>
                          setState(() => _buscarEnModificado = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppTheme.azulMedio,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: widget.onLimpiar,
                  child: const Text('Limpiar'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.verdeTeal,
                      foregroundColor: AppTheme.blanco,
                    ),
                    onPressed: () => widget.onAplicar(
                      _tipo,
                      _desde,
                      _hasta,
                      _categoria,
                      _metodoPago,
                      _usuario,
                      _buscarEnCreado,
                      _buscarEnModificado,
                    ),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTipoSelector() {
    return Row(
      children: [
        for (final entry in [
          ('ingreso', 'Ingresos', AppTheme.verdeIngreso),
          ('gasto', 'Gastos', AppTheme.rojoGasto),
          ('ambos', 'Ambos', AppTheme.azulMedio),
        ])
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tipo = entry.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: EdgeInsets.only(right: entry.$1 != 'ambos' ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _tipo == entry.$1 ? entry.$3 : AppTheme.celesteFondo,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _tipo == entry.$1
                        ? Colors.white
                        : AppTheme.textoSecundario,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFechaField(String label, DateTime? valor, bool esDesde) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textoSecundario),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _seleccionarFecha(esDesde),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.celesteBorde),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    valor != null
                        ? '${valor.day.toString().padLeft(2, '0')}/'
                            '${valor.month.toString().padLeft(2, '0')}/'
                            '${valor.year}'
                        : 'Cualquiera',
                    style: TextStyle(
                      fontSize: 13,
                      color: valor != null
                          ? AppTheme.textoPrincipal
                          : AppTheme.textoSecundario,
                    ),
                  ),
                ),
                if (valor != null)
                  GestureDetector(
                    onTap: () => setState(
                        () => esDesde ? _desde = null : _hasta = null),
                    child: const Icon(Icons.clear,
                        size: 14, color: AppTheme.textoSecundario),
                  )
                else
                  const Icon(Icons.calendar_today,
                      size: 14, color: AppTheme.textoSecundario),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
