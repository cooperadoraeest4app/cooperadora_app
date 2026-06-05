import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';

String _formatMonto(double monto) {
  final format = monto == monto.truncateToDouble()
      ? NumberFormat('#,##0', 'es_AR')
      : NumberFormat('#,##0.##', 'es_AR');
  return '\$${format.format(monto)}';
}

const _movimientosPrueba = [
  {
    'tipo': 'ingreso',
    'descripcion': 'Cuota mensual marzo',
    'monto': 15000.0,
    'fecha': '2025-03-10',
  },
  {
    'tipo': 'gasto',
    'descripcion': 'Compra de útiles',
    'monto': 8500.0,
    'fecha': '2025-03-08',
  },
  {
    'tipo': 'ingreso',
    'descripcion': 'Donación evento',
    'monto': 20000.0,
    'fecha': '2025-03-05',
  },
  {
    'tipo': 'gasto',
    'descripcion': 'Servicio de limpieza',
    'monto': 5000.0,
    'fecha': '2025-03-03',
  },
  {
    'tipo': 'ingreso',
    'descripcion': 'Cuota mensual febrero',
    'monto': 15000.0,
    'fecha': '2025-02-28',
  },
  {
    'tipo': 'gasto',
    'descripcion': 'Reparación sanitaria',
    'monto': 12000.0,
    'fecha': '2025-02-20',
  },
];

class MovimientosScreen extends StatelessWidget {
  const MovimientosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final totalIngresos = _movimientosPrueba
        .where((m) => m['tipo'] == 'ingreso')
        .fold(0.0, (sum, m) => sum + (m['monto'] as double));

    final totalGastos = _movimientosPrueba
        .where((m) => m['tipo'] == 'gasto')
        .fold(0.0, (sum, m) => sum + (m['monto'] as double));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
      ),
      body: Column(
        children: [
          _ResumenRow(totalIngresos: totalIngresos, totalGastos: totalGastos),
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _movimientosPrueba.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final movimiento = _movimientosPrueba[index];
                return _MovimientoItem(movimiento: movimiento);
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 16),
        child: FloatingActionButton(
          backgroundColor: AppTheme.verdeTeal,
          foregroundColor: AppTheme.blanco,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Próximamente: agregar movimiento'),
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
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

class _MovimientoItem extends StatelessWidget {
  const _MovimientoItem({required this.movimiento});

  final Map<String, Object> movimiento;

  @override
  Widget build(BuildContext context) {
    final esIngreso = movimiento['tipo'] == 'ingreso';
    final color = esIngreso ? AppTheme.verdeIngreso : AppTheme.rojoGasto;
    final monto = movimiento['monto'] as double;
    final descripcion = movimiento['descripcion'] as String;
    final fecha = _formatearFecha(movimiento['fecha'] as String);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(30),
        child: Icon(
          esIngreso ? Icons.arrow_upward : Icons.arrow_downward,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        descripcion,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: Text(
        fecha,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Text(
        '${esIngreso ? '+' : '-'}${_formatMonto(monto)}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  String _formatearFecha(String isoFecha) {
    final partes = isoFecha.split('-');
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }
}
