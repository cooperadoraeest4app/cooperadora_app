import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../providers/curso_provider.dart';

class CursosScreen extends StatelessWidget {
  const CursosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CursoProvider>();

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: AppTheme.blanco,
        iconTheme: const IconThemeData(color: AppTheme.blanco),
        titleTextStyle: const TextStyle(
          color: AppTheme.blanco,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: const Text('Cursos'),
        actions: const [AccionAuthWidget()],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.todos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_outlined,
                          size: 64,
                          color: AppTheme.textoSecundario.withAlpha(100)),
                      const SizedBox(height: 16),
                      const Text(
                        'Inicializando cursos…',
                        style: TextStyle(color: AppTheme.textoSecundario),
                      ),
                    ],
                  ),
                )
              : _CursosAgrupados(provider: provider),
    );
  }
}

class _CursosAgrupados extends StatelessWidget {
  const _CursosAgrupados({required this.provider});
  final CursoProvider provider;

  @override
  Widget build(BuildContext context) {
    // Agrupar por número, manteniendo orden
    final grupos = <String, List<dynamic>>{};
    for (final c in provider.todos) {
      grupos.putIfAbsent(c.numero, () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.celesteFondo,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.celesteBorde),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: AppTheme.textoSecundario),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Activá o desactivá los cursos según la matrícula de la institución.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textoSecundario),
                ),
              ),
            ],
          ),
        ),
        ...grupos.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key}° Año',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.azulMedio,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: entry.value.map((c) {
                      final label = c.turno == 'manana'
                          ? '1 (Mañana)'
                          : '2 (Tarde)';
                      return FilterChip(
                        label: Text(label),
                        selected: c.activo as bool,
                        selectedColor:
                            AppTheme.verdeTeal.withValues(alpha: 0.15),
                        checkmarkColor: AppTheme.verdeTeal,
                        side: BorderSide(
                          color: (c.activo as bool)
                              ? AppTheme.verdeTeal
                              : AppTheme.celesteBorde,
                        ),
                        onSelected: (v) => context
                            .read<CursoProvider>()
                            .activarDesactivar(c.id as String, v),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),
                ],
              ),
            )),
      ],
    );
  }
}
