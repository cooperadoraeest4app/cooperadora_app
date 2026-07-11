import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../admin/presentation/providers/categoria_provider.dart';
import '../../../admin/presentation/providers/rubro_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../domain/models/balance_resultado.dart';
import '../../domain/models/balance_snapshot.dart';
import '../providers/informes_provider.dart';
import '../../services/excel_service.dart';
import '../../services/pdf_service.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';

final _fmt = NumberFormat('#,##0.00', 'es_AR');
final _fmtFecha = DateFormat('dd/MM/yyyy');
final _fmtCorto = DateFormat('dd/MM');
final _fmtMes = DateFormat('MMM yy', 'es');

String _ars(double v) => '\$${_fmt.format(v)}';

String _nombreMes(int mes) {
  const meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  return meses[mes - 1];
}

// ── Screen ────────────────────────────────────────────────────────────────────

class InformesScreen extends StatefulWidget {
  const InformesScreen({super.key});

  @override
  State<InformesScreen> createState() => _InformesScreenState();
}

class _InformesScreenState extends State<InformesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Filtro compartido entre todos los tabs
  String _periodo = 'mes'; // 'mes' | 'trimestre' | 'anio' | 'libre'
  DateTime? _desde;
  DateTime? _hasta;
  bool _calculando = false;
  bool _exportando = false;
  bool _vistaDetallada = true;
  int _mesCierreEjercicio = 4; // Abril por defecto

  DateTimeRange get _rango {
    final ahora = DateTime.now();
    switch (_periodo) {
      case 'trimestre':
        final mesInicio = ((ahora.month - 1) ~/ 3) * 3 + 1;
        return DateTimeRange(
          start: DateTime(ahora.year, mesInicio, 1),
          end: DateTime(ahora.year, mesInicio + 3, 0),
        );
      case 'anio':
        final DateTime finEjercicio;
        if (ahora.month < _mesCierreEjercicio ||
            (ahora.month == _mesCierreEjercicio && ahora.day <= 30)) {
          finEjercicio = DateTime(ahora.year, _mesCierreEjercicio, 30);
        } else {
          finEjercicio = DateTime(ahora.year + 1, _mesCierreEjercicio, 30);
        }
        final inicioEjercicio =
            DateTime(finEjercicio.year - 1, _mesCierreEjercicio + 1, 1);
        return DateTimeRange(
          start: inicioEjercicio,
          end: finEjercicio.isAfter(ahora) ? ahora : finEjercicio,
        );
      case 'libre':
        return DateTimeRange(
          start: _desde ?? DateTime(ahora.year, ahora.month, 1),
          end: _hasta ?? ahora,
        );
      default: // 'mes'
        return DateTimeRange(
          start: DateTime(ahora.year, ahora.month, 1),
          end: DateTime(ahora.year, ahora.month + 1, 0),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser?.uid;
      context.read<InformesProvider>().verificarPermiso(uid);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _calcular() async {
    setState(() => _calculando = true);

    // Espera a que el stream de rubros haya entregado datos al menos una vez
    if (!context.read<RubroProvider>().cargado) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return mounted && !context.read<RubroProvider>().cargado;
      });
    }
    if (!mounted) return;

    final cats = context.read<CategoriaProvider>().categorias;
    final rubros = context.read<RubroProvider>().rubros;
    await context.read<InformesProvider>().calcular(
      _rango.start, _rango.end,
      categorias: cats,
      rubros: rubros,
    );
    if (mounted) setState(() => _calculando = false);
  }

  void _onPeriodoChanged(String p) {
    setState(() {
      _periodo = p;
      _vistaDetallada = p == 'mes' ||
          (p == 'libre' && _rango.duration.inDays <= 45);
    });
    context.read<InformesProvider>().limpiarResultado();
  }

  String _tituloBalance() {
    final fmt = DateFormat('MMMM yyyy', 'es');
    switch (_periodo) {
      case 'mes':
        return fmt.format(_rango.start).toUpperCase();
      case 'trimestre':
        return 'TRIMESTRE ${DateFormat('MM/yyyy').format(_rango.start)}';
      case 'anio':
        return '${_rango.start.year} / ${_rango.end.year}';
      default:
        return '${_fmtFecha.format(_rango.start)} - ${_fmtFecha.format(_rango.end)}';
    }
  }

  Future<void> _exportarPdf() async {
    final resultado = context.read<InformesProvider>().resultado;
    if (resultado == null) return;
    try {
      await PdfService.generarYMostrar(
        resultado: resultado,
        nombreCooperadora: 'Cooperadora',
        vistaDetallada: _vistaDetallada,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: AppTheme.rojoGasto),
      );
    }
  }

  Future<void> _exportarExcel() async {
    final resultado = context.read<InformesProvider>().resultado;
    if (resultado == null) return;
    setState(() => _exportando = true);
    try {
      final bytes = await ExcelService().generarBalance(
        resultado: resultado,
        vistaDetallada: _vistaDetallada,
        titulo: _tituloBalance(),
      );
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'balance_${DateFormat('yyyy_MM').format(DateTime.now())}.xlsx',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al generar Excel: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rango = _rango;
    final resultado = context.watch<InformesProvider>().resultado;
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.3)),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: Icon(Icons.home, color: Colors.white.withValues(alpha: 0.8), size: 20),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                ),
              ),
            ),
            Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Informes',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [AccionAuthWidget()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel de filtros fijo — no scrollea
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.celesteBorde)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PeriodoSelector(
                  periodo: _periodo,
                  desde: _desde,
                  hasta: _hasta,
                  mesCierreEjercicio: _mesCierreEjercicio,
                  onPeriodoChanged: _onPeriodoChanged,
                  onDesdeChanged: (d) => setState(() => _desde = d),
                  onHastaChanged: (h) => setState(() => _hasta = h),
                  onMesCierreChanged: (m) => setState(() => _mesCierreEjercicio = m),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Row(
                    children: [
                      _BotonVista(
                        icono: Icons.format_list_bulleted,
                        label: 'Detallado',
                        activo: _vistaDetallada,
                        onTap: () => setState(() => _vistaDetallada = true),
                      ),
                      const SizedBox(width: 8),
                      _BotonVista(
                        icono: Icons.summarize,
                        label: 'Agrupado',
                        activo: !_vistaDetallada,
                        onTap: () => setState(() => _vistaDetallada = false),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _calculando ? null : _calcular,
                        icon: _calculando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.calculate),
                        label: Text(_calculando ? 'Calculando...' : 'Calcular'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.verdeTeal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: resultado != null ? _exportarPdf : null,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.rojoGasto,
                            side: const BorderSide(color: AppTheme.rojoGasto),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: resultado != null && !_exportando
                              ? _exportarExcel
                              : null,
                          icon: _exportando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.table_chart),
                          label: Text(_exportando ? 'Generando...' : 'Excel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.verdeTeal,
                            side: const BorderSide(color: AppTheme.verdeTeal),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // TabBar fijo
          Container(
            color: AppTheme.azulOscuro,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white,
              indicatorColor: const Color(0xFF00BCD4),
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.table_chart, size: 18), text: 'Balance'),
                Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Gráficos'),
              ],
            ),
          ),
          // Contenido de tabs — scrollea dentro de cada uno
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _BalanceTab(rango: rango, periodo: _periodo, vistaDetallada: _vistaDetallada),
                _GraficosTab(rango: rango),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selector de período compartido ───────────────────────────────────────────

class _PeriodoSelector extends StatelessWidget {
  const _PeriodoSelector({
    required this.periodo,
    required this.desde,
    required this.hasta,
    required this.mesCierreEjercicio,
    required this.onPeriodoChanged,
    required this.onDesdeChanged,
    required this.onHastaChanged,
    required this.onMesCierreChanged,
  });

  final String periodo;
  final DateTime? desde;
  final DateTime? hasta;
  final int mesCierreEjercicio;
  final void Function(String) onPeriodoChanged;
  final void Function(DateTime) onDesdeChanged;
  final void Function(DateTime) onHastaChanged;
  final void Function(int) onMesCierreChanged;

  static const _opciones = {'mes': 'Mes', 'trimestre': 'Trimestre', 'anio': 'Año', 'libre': 'Libre'};

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: _opciones.entries.map((e) {
              final activo = periodo == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onPeriodoChanged(e.key),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: activo ? AppTheme.azulMedio : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activo ? AppTheme.azulMedio : const Color(0xFFb0dff0),
                      ),
                    ),
                    child: Text(
                      e.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: activo ? Colors.white : AppTheme.textoSecundario,
                        fontSize: 13,
                        fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (periodo == 'libre') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _DateButton(label: 'Desde', fecha: desde, onPicked: onDesdeChanged)),
                const SizedBox(width: 8),
                Expanded(child: _DateButton(label: 'Hasta', fecha: hasta, onPicked: onHastaChanged)),
              ],
            ),
          ],
          if (periodo == 'anio') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Cierre de ejercicio:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textoSecundario),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    initialValue: mesCierreEjercicio,
                    isDense: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_nombreMes(i + 1), style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    onChanged: (v) => onMesCierreChanged(v!),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.fecha, required this.onPicked});
  final String label;
  final DateTime? fecha;
  final void Function(DateTime) onPicked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: fecha ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
        ),
        child: Text(
          fecha != null ? _fmtFecha.format(fecha!) : 'Seleccionar',
          style: TextStyle(
            color: fecha != null ? AppTheme.textoPrincipal : AppTheme.textoSecundario,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ── Botón Vista (Detallado / Agrupado) ───────────────────────────────────────

class _BotonVista extends StatelessWidget {
  const _BotonVista({
    required this.icono,
    required this.label,
    required this.activo,
    required this.onTap,
  });
  final IconData icono;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? AppTheme.azulMedio : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: activo ? AppTheme.azulMedio : const Color(0xFFb0dff0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 15,
                color: activo ? Colors.white : AppTheme.textoSecundario),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: activo ? Colors.white : AppTheme.textoSecundario,
                fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab Balance ───────────────────────────────────────────────────────────────

class _BalanceTab extends StatefulWidget {
  const _BalanceTab({required this.rango, required this.periodo, required this.vistaDetallada});
  final DateTimeRange rango;
  final String periodo;
  final bool vistaDetallada;

  @override
  State<_BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends State<_BalanceTab> {
  final _saldoCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _saldoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cerrarBalance() async {
    final prov = context.read<InformesProvider>();
    final r = prov.resultado;
    if (r == null) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.datosUsuario?['id'] as String? ?? '';

    if (!r.saldoBancoExacto && r.saldoBanco != null) {
      final continuar = await _mostrarAdvertenciaBanco(r);
      if (!continuar) return;
    }

    final tipo = switch (widget.periodo) {
      'mes' => 'mensual',
      'anio' => 'anual',
      _ => 'libre',
    };

    await prov.cerrarBalance(
      usuarioId: uid,
      tipo: tipo,
      advertenciaSaldoBanco: !r.saldoBancoExacto && r.saldoBanco != null
          ? {
              'fechaDatoUsado': r.fechaSaldoBanco?.toIso8601String(),
              'fechaCierreSolicitada': r.fechaHasta.toIso8601String(),
            }
          : null,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Balance cerrado correctamente'),
        backgroundColor: AppTheme.verdeTeal,
      ),
    );
  }

  Future<bool> _mostrarAdvertenciaBanco(BalanceResultado r) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saldo bancario sin confirmar'),
        content: Text(
          'No hay saldo de Cuenta Bancaria cargado para el ${_fmtFecha.format(r.fechaHasta)}.\n\n'
          'El último disponible es del ${_fmtFecha.format(r.fechaSaldoBanco!)}.\n\n'
          '¿Generar el informe igual?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar de todas formas'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<InformesProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Saldo ejercicio anterior
        Row(
          children: [
            const Text(
              'Saldo ejercicio anterior:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textoPrincipal,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              child: TextFormField(
                controller: _saldoCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.azulMedio,
                ),
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onChanged: (v) {
                  final monto = double.tryParse(
                        v.replaceAll('.', '').replaceAll(',', '.'),
                      ) ??
                      0;
                  prov.setSaldoAnterior(monto);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (prov.error != null)
          Card(
            color: AppTheme.rojoGasto.withAlpha(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(prov.error!, style: const TextStyle(color: AppTheme.rojoGasto)),
            ),
          ),

        if (prov.resultado != null) ...[
          _ResultadoBalance(resultado: prov.resultado!, vistaDetallada: widget.vistaDetallada),
          const SizedBox(height: 12),

          if (prov.snapshotsPeriodo.isNotEmpty) ...[
            _SnapshotsPeriodo(snapshots: prov.snapshotsPeriodo),
            const SizedBox(height: 12),
          ],

          if (prov.puedeCerrarBalance)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.azulOscuro),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Cerrar balance'),
                onPressed: prov.isCalculating ? null : _cerrarBalance,
              ),
            ),
        ],
      ],
    );
  }
}

// ── Tab Gráficos ──────────────────────────────────────────────────────────────

class _GraficosTab extends StatefulWidget {
  const _GraficosTab({required this.rango});
  final DateTimeRange rango;

  @override
  State<_GraficosTab> createState() => _GraficosTabState();
}

class _GraficosTabState extends State<_GraficosTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _calcularEvolucion();
    });
  }

  @override
  void didUpdateWidget(_GraficosTab old) {
    super.didUpdateWidget(old);
    if (old.rango.start != widget.rango.start || old.rango.end != widget.rango.end) {
      _calcularEvolucion();
    }
  }

  void _calcularEvolucion() {
    final cats = context.read<CategoriaProvider>().categorias;
    context.read<InformesProvider>().calcularEvolucion(
      categorias: cats,
      hasta: widget.rango.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<InformesProvider>();

    if (prov.isCalculatingEvolucion) {
      return const Center(child: CircularProgressIndicator());
    }

    final resultado = prov.resultado;
    final evolucion = prov.evolucion;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (resultado != null || evolucion.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exportar gráficos: próximamente disponible')),
              ),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Exportar gráficos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.azulMedio,
                side: const BorderSide(color: AppTheme.azulMedio),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (evolucion.isNotEmpty) ...[
          const Text('Evolución mensual (12 meses)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          SizedBox(height: 220, child: _GraficoEvolucion(datos: evolucion)),
          const SizedBox(height: 24),
        ],

        if (resultado != null) ...[
          if (resultado.entradas.isNotEmpty) ...[
            const Text('Entradas por rubro',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            SizedBox(height: 200,
                child: _GraficoPie(rubros: resultado.entradas, color: AppTheme.verdeIngreso)),
            const SizedBox(height: 24),
          ],
          if (resultado.salidas.isNotEmpty) ...[
            const Text('Salidas por rubro',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            SizedBox(height: 200,
                child: _GraficoPie(rubros: resultado.salidas, color: AppTheme.rojoGasto)),
            const SizedBox(height: 24),
          ],
          if (resultado.salidas.isNotEmpty) ...[
            const Text('Top categorías de gasto',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            _TopCategorias(rubros: resultado.salidas),
          ],
        ],

        if (resultado == null && evolucion.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text(
                'Calculá un período en la pestaña Balance para ver gráficos',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textoSecundario),
              ),
            ),
          ),
      ],
    );
  }
}


// ── Resultado del balance ─────────────────────────────────────────────────────

class _ResultadoBalance extends StatelessWidget {
  const _ResultadoBalance({required this.resultado, required this.vistaDetallada});
  final BalanceResultado resultado;
  final bool vistaDetallada;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SeccionBalance(titulo: 'ENTRADAS', color: AppTheme.verdeIngreso,
            rubros: r.entradas, total: r.totalEntradas),
        const SizedBox(height: 8),
        if (vistaDetallada && r.salidasDetalle.isNotEmpty)
          _SeccionDetalladaSalidas(
              rubros: r.salidas, movimientos: r.salidasDetalle, total: r.totalSalidas)
        else
          _SeccionBalance(titulo: 'SALIDAS', color: AppTheme.rojoGasto,
              rubros: r.salidas, total: r.totalSalidas),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.celesteBorde),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Resumen del período',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textoPrincipal,
                ),
              ),
              const Divider(),
              _FilaResumen('Total Entradas', r.totalEntradas, color: AppTheme.verdeIngreso),
              _FilaResumen('+ Saldo ejercicio anterior', r.saldoEjercicioAnterior),
              _FilaResumen('= Total General', r.totalGeneral, negrita: true),
              const Divider(),
              _FilaResumen('- Total Salidas', r.totalSalidas, color: AppTheme.rojoGasto),
              const Divider(thickness: 2),
              _FilaResumen(
                '= Saldo próximo ejercicio',
                r.saldoProximoEjercicio,
                color: r.saldoProximoEjercicio >= 0 ? AppTheme.verdeIngreso : AppTheme.rojoGasto,
                negrita: true,
                fontSize: 16,
              ),
              if (r.saldoBanco != null || r.saldoCajaChica != null) ...[
                const SizedBox(height: 8),
                if (r.saldoBanco != null)
                  _FilaResumen('En Banco', r.saldoBanco!, color: AppTheme.textoSecundario),
                if (r.saldoCajaChica != null)
                  _FilaResumen('En Caja Chica', r.saldoCajaChica!, color: AppTheme.textoSecundario),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saldos al cierre del período',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                if (r.saldoCajaChica != null)
                  _FilaSaldo('En Caja Chica', r.saldoCajaChica!, r.fechaSaldoCajaChica, exacto: true),
                if (r.saldoBanco != null)
                  _FilaSaldo('En Banco', r.saldoBanco!, r.fechaSaldoBanco, exacto: r.saldoBancoExacto),
                if (r.saldoCajaChica == null && r.saldoBanco == null)
                  const Text('Sin datos de saldo disponibles',
                      style: TextStyle(color: AppTheme.textoSecundario, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SeccionBalance extends StatefulWidget {
  const _SeccionBalance({
    required this.titulo, required this.color,
    required this.rubros, required this.total,
  });
  final String titulo;
  final Color color;
  final List<RubroBalance> rubros;
  final double total;

  @override
  State<_SeccionBalance> createState() => _SeccionBalanceState();
}

class _SeccionBalanceState extends State<_SeccionBalance> {
  bool _expandido = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            onTap: () => setState(() => _expandido = !_expandido),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    widget.titulo == 'ENTRADAS' ? Icons.arrow_downward : Icons.arrow_upward,
                    color: widget.color, size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.titulo,
                        style: TextStyle(fontWeight: FontWeight.w700, color: widget.color)),
                  ),
                  Text(_ars(widget.total),
                      style: TextStyle(fontWeight: FontWeight.w700, color: widget.color)),
                  const SizedBox(width: 4),
                  Icon(_expandido ? Icons.expand_less : Icons.expand_more,
                      size: 20, color: AppTheme.textoSecundario),
                ],
              ),
            ),
          ),
          if (_expandido)
            ...widget.rubros.map((r) => _RubroBalanceTile(rubro: r, color: widget.color)),
        ],
      ),
    );
  }
}

class _RubroBalanceTile extends StatefulWidget {
  const _RubroBalanceTile({required this.rubro, required this.color});
  final RubroBalance rubro;
  final Color color;

  @override
  State<_RubroBalanceTile> createState() => _RubroBalanceTileState();
}

class _RubroBalanceTileState extends State<_RubroBalanceTile> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1, indent: 16),
        InkWell(
          onTap: widget.rubro.categorias.isNotEmpty
              ? () => setState(() => _expandido = !_expandido)
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, size: 16, color: widget.color.withAlpha(180)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.rubro.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Text(_ars(widget.rubro.total),
                    style: TextStyle(fontWeight: FontWeight.w600, color: widget.color)),
                if (widget.rubro.categorias.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Icon(_expandido ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: AppTheme.textoSecundario),
                ],
              ],
            ),
          ),
        ),
        if (_expandido)
          ...widget.rubro.categorias.map((c) => Padding(
                padding: const EdgeInsets.fromLTRB(40, 4, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${c.nombre} (${c.cantidad})',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textoSecundario)),
                    ),
                    Text(_ars(c.total),
                        style: const TextStyle(fontSize: 13, color: AppTheme.textoPrincipal)),
                  ],
                ),
              )),
      ],
    );
  }
}

// ── Salidas en vista Detallada ────────────────────────────────────────────────

class _SeccionDetalladaSalidas extends StatelessWidget {
  const _SeccionDetalladaSalidas({
    required this.rubros,
    required this.movimientos,
    required this.total,
  });
  final List<RubroBalance> rubros;
  final List<MovimientoBalance> movimientos;
  final double total;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<MovimientoBalance>> porRubro = {};
    for (final m in movimientos) {
      porRubro.putIfAbsent(m.rubroId, () => []).add(m);
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.arrow_upward, color: AppTheme.rojoGasto, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('SALIDAS',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: AppTheme.rojoGasto)),
                ),
                Text(_ars(total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppTheme.rojoGasto)),
              ],
            ),
          ),
          // Encabezados de columna
          Container(
            color: AppTheme.celesteFondo,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                SizedBox(
                    width: 44,
                    child: Text('Fecha',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textoSecundario,
                            fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 56,
                    child: Text('N° Comp.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textoSecundario,
                            fontWeight: FontWeight.w600))),
                const Expanded(
                    child: Text('Descripción',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textoSecundario,
                            fontWeight: FontWeight.w600))),
                Text('Monto',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textoSecundario,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Filas por rubro
          ...rubros.expand((r) {
            final movs = porRubro[r.rubroId] ?? [];
            if (movs.isEmpty) return <Widget>[];
            return [
              const Divider(height: 1, indent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined,
                        size: 14, color: AppTheme.rojoGasto.withAlpha(180)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(r.nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    Text(_ars(r.total),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.rojoGasto,
                            fontSize: 13)),
                  ],
                ),
              ),
              ...movs.map((m) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(_fmtCorto.format(m.fecha),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textoSecundario)),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(m.nroComprobante ?? '—',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textoSecundario),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          child: Text(
                              m.descripcion.isEmpty
                                  ? '(sin descripción)'
                                  : m.descripcion,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(_ars(m.monto),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.rojoGasto)),
                      ],
                    ),
                  )),
            ];
          }),
        ],
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen(this.label, this.valor, {this.color, this.negrita = false, this.fontSize = 14});
  final String label;
  final double valor;
  final Color? color;
  final bool negrita;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fw = negrita ? FontWeight.bold : FontWeight.normal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: AppTheme.textoPrincipal, fontWeight: fw)),
          Text(_ars(valor), style: TextStyle(fontSize: fontSize, color: color ?? AppTheme.textoPrincipal, fontWeight: fw)),
        ],
      ),
    );
  }
}

class _FilaSaldo extends StatelessWidget {
  const _FilaSaldo(this.label, this.valor, this.fecha, {required this.exacto});
  final String label;
  final double valor;
  final DateTime? fecha;
  final bool exacto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                if (fecha != null)
                  Row(
                    children: [
                      Text(_fmtFecha.format(fecha!),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textoSecundario)),
                      if (!exacto) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.warning_amber_rounded,
                            size: 13, color: AppTheme.amarilloAlerta),
                        const Text(' estimado',
                            style: TextStyle(fontSize: 11, color: AppTheme.amarilloAlerta)),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          Text(_ars(valor), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Snapshots previos ─────────────────────────────────────────────────────────

class _SnapshotsPeriodo extends StatelessWidget {
  const _SnapshotsPeriodo({required this.snapshots});
  final List<BalanceSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.celesteFondo,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 16, color: AppTheme.azulMedio),
                const SizedBox(width: 6),
                Text(
                  'Cierres anteriores para este período (${snapshots.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...snapshots.map((s) => _SnapshotTile(s)),
          ],
        ),
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  const _SnapshotTile(this.snap);
  final BalanceSnapshot snap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            snap.esConfiable ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 16,
            color: snap.esConfiable ? AppTheme.verdeTeal : AppTheme.amarilloAlerta,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'v${snap.version} — ${_fmtFecha.format(snap.fechaCierre)}'
              '${snap.esConfiable ? '' : ' (banco estimado)'}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(_ars(snap.saldoProximoEjercicio),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Gráficos ──────────────────────────────────────────────────────────────────

class _GraficoEvolucion extends StatelessWidget {
  const _GraficoEvolucion({required this.datos});
  final List<MesBalance> datos;

  @override
  Widget build(BuildContext context) {
    final maxY = datos.fold(0.0, (m, d) {
      final v = d.entradas > d.salidas ? d.entradas : d.salidas;
      return v > m ? v : m;
    });
    return BarChart(
      BarChartData(
        maxY: maxY * 1.15,
        barGroups: datos.asMap().entries.map((e) {
          final i = e.key;
          final d = e.value;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: d.entradas,
                color: AppTheme.verdeIngreso,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: d.salidas,
                color: AppTheme.rojoGasto,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= datos.length) return const SizedBox.shrink();
                final d = datos[idx];
                return Text(_fmtMes.format(DateTime(d.anio, d.mes)),
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _GraficoPie extends StatelessWidget {
  const _GraficoPie({required this.rubros, required this.color});
  final List<RubroBalance> rubros;
  final Color color;

  static const _colores = [
    Color(0xFF2E6DA4), Color(0xFF2E9E7A), Color(0xFF9B59B6),
    Color(0xFFF39C12), Color(0xFFE74C3C), Color(0xFF1A3A5C),
    Color(0xFF27AE60), Color(0xFF8E44AD),
  ];

  @override
  Widget build(BuildContext context) {
    final total = rubros.fold(0.0, (s, r) => s + r.total);
    if (total == 0) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sections: rubros.asMap().entries.map((e) {
                final i = e.key;
                final r = e.value;
                final pct = r.total / total * 100;
                return PieChartSectionData(
                  value: r.total,
                  title: '${pct.toStringAsFixed(1)}%',
                  color: _colores[i % _colores.length],
                  radius: 70,
                  titleStyle: const TextStyle(
                      fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rubros.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: _colores[i % _colores.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(child: Text(r.nombre, style: const TextStyle(fontSize: 11))),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TopCategorias extends StatelessWidget {
  const _TopCategorias({required this.rubros});
  final List<RubroBalance> rubros;

  @override
  Widget build(BuildContext context) {
    final cats = rubros.expand((r) => r.categorias).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final top = cats.take(8).toList();
    final maxVal = top.isNotEmpty ? top.first.total : 1.0;

    return Column(
      children: top.map((c) {
        final pct = c.total / maxVal;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(c.nombre, style: const TextStyle(fontSize: 12))),
                  Text(_ars(c.total),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 3),
              LinearProgressIndicator(
                value: pct,
                backgroundColor: AppTheme.rojoGasto.withAlpha(30),
                valueColor: const AlwaysStoppedAnimation(AppTheme.rojoGasto),
                minHeight: 6,
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
