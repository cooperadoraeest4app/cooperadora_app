import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/proyecto.dart';
import '../providers/proyecto_provider.dart';
import 'proyecto_detalle_screen.dart';

class ProyectosCanceladosScreen extends StatelessWidget {
  const ProyectosCanceladosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        title: const Text(
          'Proyectos cancelados',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _CuerpoProyectosCancelados(),
    );
  }
}

class _CuerpoProyectosCancelados extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProyectoProvider>();
    final puedeGestionar = context.select<AuthProvider, bool>(
      (a) => a.esEditor || a.esAdmin,
    );

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final cancelados = provider.proyectosPorEstado('cancelado');

    if (cancelados.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined,
                size: 48, color: AppTheme.textoSecundario),
            SizedBox(height: 12),
            Text(
              'No hay proyectos cancelados',
              style: TextStyle(color: AppTheme.textoSecundario),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: cancelados.length,
      itemBuilder: (_, i) => _CardCancelado(
        proyecto: cancelados[i],
        puedeGestionar: puedeGestionar,
      ),
    );
  }
}

class _CardCancelado extends StatelessWidget {
  const _CardCancelado({
    required this.proyecto,
    required this.puedeGestionar,
  });

  final Proyecto proyecto;
  final bool puedeGestionar;

  @override
  Widget build(BuildContext context) {
    final tipoNombre =
        context.read<ProyectoProvider>().nombreTipo(proyecto.tipoProyectoId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProyectoDetalleScreen(proyecto: proyecto)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.textoSecundario.withAlpha(25),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(12)),
                      ),
                      child: const Text(
                        'Cancelado',
                        style: TextStyle(
                            color: AppTheme.textoSecundario,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      proyecto.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textoPrincipal,
                      ),
                    ),
                    if (proyecto.descripcion?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        proyecto.descripcion!,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textoSecundario),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      tipoNombre,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textoSecundario),
                    ),
                  ],
                ),
              ),
              if (puedeGestionar)
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: AppTheme.rojoGasto,
                    onPressed: () => _confirmarEliminar(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar proyecto'),
        content: Text(
            '¿Eliminar "${proyecto.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<ProyectoProvider>().eliminar(proyecto.id);
              Navigator.pop(context);
            },
            child: Text('Eliminar',
                style: TextStyle(color: AppTheme.rojoGasto)),
          ),
        ],
      ),
    );
  }
}
