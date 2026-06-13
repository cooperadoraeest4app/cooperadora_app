import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class LogCambiosScreen extends StatefulWidget {
  const LogCambiosScreen({super.key});

  @override
  State<LogCambiosScreen> createState() => _LogCambiosScreenState();
}

class _LogCambiosScreenState extends State<LogCambiosScreen> {
  String _filtroTipo = 'todos';
  DateTime? _desde;
  DateTime? _hasta;

  static const _tipos = [
    ('todos', 'Todos'),
    ('ingreso', 'Ingresos'),
    ('gasto', 'Gastos'),
    ('cuota', 'Cuotas'),
    ('proyecto', 'Proyectos'),
  ];

  Stream<List<Map<String, dynamic>>> get _stream {
    return FirebaseFirestore.instance
        .collection('log_cambios')
        .orderBy('fecha', descending: true)
        .limit(200)
        .snapshots()
        .map((s) {
      var docs = s.docs.map((d) => {...d.data(), 'id': d.id}).toList();

      if (_filtroTipo != 'todos') {
        docs = docs
            .where((d) => d['entidadTipo'] == _filtroTipo)
            .toList();
      }
      if (_desde != null) {
        docs = docs.where((d) {
          final ts = d['fecha'];
          if (ts == null) return false;
          final dt = ts is Timestamp ? ts.toDate() : ts as DateTime;
          return !dt.isBefore(_desde!);
        }).toList();
      }
      if (_hasta != null) {
        final limite = _hasta!.add(const Duration(days: 1));
        docs = docs.where((d) {
          final ts = d['fecha'];
          if (ts == null) return false;
          final dt = ts is Timestamp ? ts.toDate() : ts as DateTime;
          return dt.isBefore(limite);
        }).toList();
      }

      return docs;
    });
  }

  Future<void> _seleccionarDesde() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _desde ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _desde = picked);
  }

  Future<void> _seleccionarHasta() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hasta ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _hasta = picked);
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Log de cambios'),
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history,
                            size: 64,
                            color: AppTheme.textoSecundario.withAlpha(100)),
                        const SizedBox(height: 16),
                        Text(
                          'Sin cambios registrados',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppTheme.textoSecundario,
                              ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _LogItem(item: items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    final formato = _formatFecha;
    return Container(
      color: AppTheme.celesteFondo,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _filtroTipo,
            decoration: const InputDecoration(
              labelText: 'Tipo de entidad',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _tipos
                .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _filtroTipo = v);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_desde == null
                      ? 'Desde'
                      : 'Desde: ${formato(_desde!)}'),
                  onPressed: _seleccionarDesde,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                      _hasta == null ? 'Hasta' : 'Hasta: ${formato(_hasta!)}'),
                  onPressed: _seleccionarHasta,
                ),
              ),
              if (_desde != null || _hasta != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.rojoGasto),
                  tooltip: 'Limpiar fechas',
                  onPressed: () =>
                      setState(() => _desde = _hasta = null),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _formatFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _formatFechaHora(dynamic timestamp) {
  if (timestamp == null) return '-';
  final dt = timestamp is Timestamp
      ? timestamp.toDate()
      : timestamp as DateTime;
  return '${_formatFecha(dt)} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

class _LogItem extends StatelessWidget {
  const _LogItem({required this.item});
  final Map<String, dynamic> item;

  static (Color bg, Color fg, String label) _accionStyle(String accion) =>
      switch (accion) {
        'creacion' => (
            AppTheme.verdeIngreso.withAlpha(30),
            AppTheme.verdeIngreso,
            'Creación'
          ),
        'modificacion' => (
            AppTheme.amarilloAlerta.withAlpha(40),
            AppTheme.amarilloAlerta,
            'Modificación'
          ),
        'eliminacion' => (
            AppTheme.rojoGasto.withAlpha(30),
            AppTheme.rojoGasto,
            'Eliminación'
          ),
        _ => (AppTheme.celesteFondo, AppTheme.textoSecundario, accion),
      };

  @override
  Widget build(BuildContext context) {
    final accion = item['accion'] as String? ?? '-';
    final entidadTipo = item['entidadTipo'] as String? ?? '-';
    final usuarioId = item['usuarioId'] as String? ?? '-';
    final (bg, fg, label) = _accionStyle(accion);

    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: fg, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          _capitalize(entidadTipo),
          style: const TextStyle(
              fontWeight: FontWeight.w500, color: AppTheme.textoPrincipal),
        ),
        subtitle: Text(
          'Por: $usuarioId\n${_formatFechaHora(item['fecha'])}',
          style: const TextStyle(
              fontSize: 12, color: AppTheme.textoSecundario),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right,
            color: AppTheme.textoSecundario),
        onTap: () => _mostrarDetalle(context, item),
      ),
    );
  }

  void _mostrarDetalle(
      BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Detalle del cambio',
            style: const TextStyle(
                color: AppTheme.textoPrincipal,
                fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item['camposAnteriores'] != null) ...[
                const Text('Valores anteriores:',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.rojoGasto)),
                const SizedBox(height: 4),
                _MapView(data: item['camposAnteriores'] as Map),
                const SizedBox(height: 12),
              ],
              if (item['camposNuevos'] != null) ...[
                const Text('Valores nuevos:',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.verdeIngreso)),
                const SizedBox(height: 4),
                _MapView(data: item['camposNuevos'] as Map),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _MapView extends StatelessWidget {
  const _MapView({required this.data});
  final Map data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.celesteFondo,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries
            .where((e) => e.key != 'fechaCreacion')
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textoPrincipal),
                      children: [
                        TextSpan(
                          text: '${e.key}: ',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.azulMedio),
                        ),
                        TextSpan(text: '${e.value}'),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
