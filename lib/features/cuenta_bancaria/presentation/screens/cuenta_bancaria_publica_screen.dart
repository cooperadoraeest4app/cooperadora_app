import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/cuenta_bancaria.dart';
import '../../domain/models/movimiento_bancario.dart';
import '../providers/cuenta_bancaria_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

const _mesesEs = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

String _doubleToArgentino(double v) {
  final format = v == v.truncateToDouble()
      ? NumberFormat('#,##0', 'es_AR')
      : NumberFormat('#,##0.##', 'es_AR');
  return format.format(v);
}

Widget _buildSaldoWidget(double saldo) {
  const mainStyle = TextStyle(
    color: AppTheme.textoPrincipal,
    fontSize: 44,
    fontWeight: FontWeight.bold,
    height: 1,
  );

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
      Text(
        cents.toString().padLeft(2, '0'),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppTheme.textoPrincipal,
        ),
      ),
    ],
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CuentaBancariaPublicaScreen extends StatelessWidget {
  const CuentaBancariaPublicaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CuentaBancariaProvider>();
    final cuenta = provider.cuenta;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: AppTheme.blanco,
        iconTheme: const IconThemeData(color: AppTheme.blanco),
        titleTextStyle: const TextStyle(
          color: AppTheme.blanco,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: const Text('Cuenta Bancaria'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : cuenta == null
              ? const _SinCuenta()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SaldoCard(cuenta: cuenta),
                      const SizedBox(height: 16),
                      _InfoCard(cuenta: cuenta),
                      const SizedBox(height: 16),
                      _HistorialCard(movimientos: provider.movimientos),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}

// ── Sin cuenta ────────────────────────────────────────────────────────────────

class _SinCuenta extends StatelessWidget {
  const _SinCuenta();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_outlined,
                size: 64, color: AppTheme.textoSecundario),
            SizedBox(height: 16),
            Text(
              'La cuenta bancaria aún no ha sido configurada.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Saldo ─────────────────────────────────────────────────────────────────────

class _SaldoCard extends StatelessWidget {
  const _SaldoCard({required this.cuenta});

  final CuentaBancaria cuenta;

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
            _buildSaldoWidget(cuenta.saldoActual),
            const SizedBox(height: 4),
            Text(
              'Actualizado: ${_fmtFecha(cuenta.fechaActualizacion)}',
              style: const TextStyle(
                  color: AppTheme.textoSecundario, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info ──────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.cuenta});

  final CuentaBancaria cuenta;

  @override
  Widget build(BuildContext context) {
    final cbu = cuenta.cbu;
    final cbuMask =
        'CBU ····${cbu.length >= 4 ? cbu.substring(cbu.length - 4) : cbu}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datos de la cuenta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textoPrincipal,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Banco', valor: cuenta.banco),
            const SizedBox(height: 6),
            _InfoRow(label: 'Tipo', valor: cuenta.tipoCuenta),
            const SizedBox(height: 6),
            _InfoRow(label: 'CBU', valor: cbuMask),
            if (cuenta.alias != null && cuenta.alias!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _AliasRow(alias: cuenta.alias!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
              color: AppTheme.textoSecundario, fontSize: 13),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(
              color: AppTheme.textoPrincipal,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Alias con copia ───────────────────────────────────────────────────────────

class _AliasRow extends StatelessWidget {
  const _AliasRow({required this.alias});

  final String alias;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Alias: ',
          style: TextStyle(color: AppTheme.textoSecundario, fontSize: 13),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              alias,
              style: const TextStyle(
                color: AppTheme.textoPrincipal,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              color: AppTheme.azulMedio,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Copiar alias',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: alias));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppTheme.verdeIngreso, size: 18),
                          const SizedBox(width: 8),
                          Text('Alias copiado: $alias'),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── Historial ─────────────────────────────────────────────────────────────────

enum _ModoHistorial { defecto, resumenes, fecha }

class _HistorialCard extends StatefulWidget {
  const _HistorialCard({required this.movimientos});

  final List<MovimientoBancario> movimientos;

  @override
  State<_HistorialCard> createState() => _HistorialCardState();
}

class _HistorialCardState extends State<_HistorialCard> {
  _ModoHistorial _modo = _ModoHistorial.defecto;
  bool _ascendente = false;
  int _anioSeleccionado = DateTime.now().year;
  DateTime? _desde;
  DateTime? _hasta;
  int _pagina = 0;
  static const _porPagina = 12;

  List<MovimientoBancario> get _ordenados {
    final lista = [...widget.movimientos];
    if (_ascendente) {
      lista.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
    }
    return lista;
  }

  List<int> get _aniosDisponibles {
    final anios = widget.movimientos
        .map((m) => m.fechaCreacion.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final anioActual = DateTime.now().year;
    if (!anios.contains(anioActual)) anios.insert(0, anioActual);
    return anios;
  }

  List<MovimientoBancario> get _filtradoFecha {
    return _ordenados.where((m) {
      if (_desde != null && m.fechaCreacion.isBefore(_desde!)) return false;
      if (_hasta != null &&
          m.fechaCreacion.isAfter(_hasta!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildOrdenSelector() {
    return Row(
      children: [
        const Text(
          'Ordenar por',
          style: TextStyle(color: AppTheme.textoSecundario, fontSize: 13),
        ),
        TextButton(
          onPressed: () => setState(() {
            _ascendente = !_ascendente;
            _pagina = 0;
          }),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.azulMedio,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_ascendente ? 'Más antiguo' : 'Más reciente'),
              const Icon(Icons.keyboard_arrow_down, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Historial',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textoPrincipal,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Recientes'),
                  selected: _modo == _ModoHistorial.defecto,
                  onSelected: (_) =>
                      setState(() => _modo = _ModoHistorial.defecto),
                ),
                FilterChip(
                  label: const Text('Por año'),
                  selected: _modo == _ModoHistorial.resumenes,
                  onSelected: (_) =>
                      setState(() => _modo = _ModoHistorial.resumenes),
                ),
                FilterChip(
                  label: const Text('Por fecha'),
                  selected: _modo == _ModoHistorial.fecha,
                  onSelected: (_) => setState(() {
                    _modo = _ModoHistorial.fecha;
                    _pagina = 0;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_modo == _ModoHistorial.defecto)
              _buildDefecto()
            else if (_modo == _ModoHistorial.resumenes)
              _buildResumenes()
            else
              _buildFecha(),
          ],
        ),
      ),
    );
  }

  Widget _buildDefecto() {
    final ultimos = _ordenados.take(6).toList();
    if (ultimos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Sin movimientos registrados',
            style: TextStyle(color: AppTheme.textoSecundario, fontSize: 13),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOrdenSelector(),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ultimos.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _MovimientoTile(movimiento: ultimos[i]),
        ),
        if (widget.movimientos.length > 6) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _modo = _ModoHistorial.fecha;
              _pagina = 0;
            }),
            child:
                Text('Ver todo el historial (${widget.movimientos.length})'),
          ),
        ],
      ],
    );
  }

  Widget _buildResumenes() {
    final anios = _aniosDisponibles;
    if (!anios.contains(_anioSeleccionado)) {
      _anioSeleccionado = anios.first;
    }

    final resumenesPorMes = <int, MovimientoBancario>{};
    for (final m
        in widget.movimientos.where((m) => m.tipo == 'resumen_mensual')) {
      final periodo = m.periodo;
      if (periodo != null && RegExp(r'^\d{2}/\d{4}$').hasMatch(periodo)) {
        final partes = periodo.split('/');
        final anio = int.tryParse(partes[1]);
        final mes = int.tryParse(partes[0]);
        if (anio == _anioSeleccionado && mes != null) {
          resumenesPorMes[mes] = m;
        }
      }
    }

    final ahora = DateTime.now();
    final mesLimite =
        _anioSeleccionado == ahora.year ? ahora.month : 12;
    final meses = _ascendente
        ? List.generate(mesLimite, (i) => i + 1)
        : List.generate(mesLimite, (i) => mesLimite - i);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                initialValue: _anioSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Año',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: anios
                    .map((a) => DropdownMenuItem(value: a, child: Text('$a')))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _anioSeleccionado = v ?? _anioSeleccionado),
              ),
            ),
          ],
        ),
        _buildOrdenSelector(),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: meses.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final mes = meses[i];
            final resumen = resumenesPorMes[mes];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                '${_mesesEs[mes - 1]} $_anioSeleccionado',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textoPrincipal,
                ),
              ),
              trailing: resumen != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf,
                            size: 18, color: AppTheme.azulMedio),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () =>
                              ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Descarga disponible cuando se configure Firebase Storage',
                              ),
                            ),
                          ),
                          child: const Icon(Icons.download,
                              size: 18, color: AppTheme.azulMedio),
                        ),
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.textoSecundario
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Sin resumen',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textoSecundario,
                        ),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFecha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOrdenSelector(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DatePickerButton(
                label: 'Desde',
                fecha: _desde,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _desde ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() { _desde = d; _pagina = 0; });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DatePickerButton(
                label: 'Hasta',
                fecha: _hasta,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _hasta ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() { _hasta = d; _pagina = 0; });
                },
              ),
            ),
            if (_desde != null || _hasta != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => setState(() {
                  _desde = null;
                  _hasta = null;
                  _pagina = 0;
                }),
                tooltip: 'Limpiar filtros',
              ),
          ],
        ),
        const SizedBox(height: 12),
        Builder(builder: (_) {
          final filtrados = _filtradoFecha;
          final total = filtrados.length;
          if (total == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Sin movimientos en el período seleccionado',
                  style: TextStyle(
                      color: AppTheme.textoSecundario, fontSize: 13),
                ),
              ),
            );
          }
          final totalPaginas = (total / _porPagina).ceil();
          final inicio = _pagina * _porPagina;
          final fin = (inicio + _porPagina).clamp(0, total);
          final pagina = filtrados.sublist(inicio, fin);

          return Column(
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pagina.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) =>
                    _MovimientoTile(movimiento: pagina[i]),
              ),
              if (totalPaginas > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _pagina > 0
                          ? () => setState(() => _pagina--)
                          : null,
                    ),
                    Text('${_pagina + 1} / $totalPaginas',
                        style: const TextStyle(fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _pagina < totalPaginas - 1
                          ? () => setState(() => _pagina++)
                          : null,
                    ),
                  ],
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$total movimiento${total == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: AppTheme.textoSecundario, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ── Item del historial ────────────────────────────────────────────────────────

class _MovimientoTile extends StatefulWidget {
  const _MovimientoTile({required this.movimiento});

  final MovimientoBancario movimiento;

  @override
  State<_MovimientoTile> createState() => _MovimientoTileState();
}

class _MovimientoTileState extends State<_MovimientoTile> {
  bool _expandido = false;

  String _fmt(double? v) => v != null ? '\$${_doubleToArgentino(v)}' : '-';

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final mov = widget.movimiento;
    final esResumen = mov.tipo == 'resumen_mensual';
    final tieneDescarga =
        esResumen || (mov.archivo != null && mov.archivo!.isNotEmpty);
    final tieneObs =
        mov.observaciones != null && mov.observaciones!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 2),
                child: Icon(
                  esResumen
                      ? Icons.description_outlined
                      : Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: AppTheme.azulMedio,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            esResumen
                                ? 'Resumen ${mov.periodo ?? ''}'
                                : 'Actualización de saldo',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textoPrincipal,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmt(mov.saldoAnterior),
                              style: const TextStyle(
                                  color: AppTheme.textoSecundario,
                                  fontSize: 12),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.arrow_forward,
                                  size: 12, color: AppTheme.azulMedio),
                            ),
                            Text(
                              _fmt(mov.saldoNuevo),
                              style: const TextStyle(
                                color: AppTheme.textoPrincipal,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      _fmtFecha(mov.fechaCreacion),
                      style: const TextStyle(
                          color: AppTheme.textoSecundario, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (tieneDescarga)
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Descarga disponible cuando se configure Firebase Storage',
                      ),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8, top: 2),
                    child: Icon(Icons.download,
                        size: 18, color: AppTheme.azulMedio),
                  ),
                ),
              if (tieneObs)
                GestureDetector(
                  onTap: () => setState(() => _expandido = !_expandido),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Icon(
                      _expandido ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppTheme.textoSecundario,
                    ),
                  ),
                ),
            ],
          ),
          if (tieneObs && _expandido)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.celesteFondo,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  mov.observaciones!,
                  style: const TextStyle(
                    color: AppTheme.textoSecundario,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Date picker button ────────────────────────────────────────────────────────

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = fecha != null
        ? '${fecha!.day.toString().padLeft(2, '0')}/'
            '${fecha!.month.toString().padLeft(2, '0')}/'
            '${fecha!.year}'
        : label;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today, size: 14),
      label: Text(texto, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        foregroundColor:
            fecha != null ? AppTheme.azulMedio : AppTheme.textoSecundario,
        side: BorderSide(
          color: fecha != null
              ? AppTheme.azulMedio
              : AppTheme.textoSecundario.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
