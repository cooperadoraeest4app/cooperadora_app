import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../proyectos/presentation/providers/proyecto_provider.dart';
import '../../../proyectos/presentation/screens/proyecto_detalle_screen.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/campana_notificaciones_widget.dart';

class VotacionesScreen extends StatefulWidget {
  const VotacionesScreen({super.key});

  @override
  State<VotacionesScreen> createState() => _VotacionesScreenState();
}

class _VotacionesScreenState extends State<VotacionesScreen> {
  String _filtroEstado = 'todas';
  String _filtroTipo = 'todos';

  Stream<QuerySnapshot> _buildQuery() {
    return FirebaseFirestore.instance
        .collection('votaciones')
        .orderBy('fechaCreacion', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            IconButton(
              icon: Icon(Icons.home, color: Colors.white.withValues(alpha: 0.8), size: 20),
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              ),
            ),
            Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 12),
            const Text(
              'Votaciones',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: const [CampanaNotificacionesWidget(), AccionAuthWidget()],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.celesteBorde),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filtroEstado,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'todas', child: Text('Todas')),
                      DropdownMenuItem(
                          value: 'en_curso', child: Text('En curso')),
                      DropdownMenuItem(
                          value: 'aprobada', child: Text('Aprobadas')),
                      DropdownMenuItem(
                          value: 'rechazada', child: Text('Rechazadas')),
                      DropdownMenuItem(
                          value: 'cerrada_sin_quorum',
                          child: Text('Sin quórum')),
                    ],
                    onChanged: (v) => setState(() => _filtroEstado = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filtroTipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(
                          value: 'proyecto', child: Text('Proyectos')),
                      DropdownMenuItem(
                          value: 'presupuesto', child: Text('Presupuestos')),
                    ],
                    onChanged: (v) => setState(() => _filtroTipo = v!),
                  ),
                ),
              ],
            ),
          ),
          // Listado
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.celesteBorde),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _buildQuery(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const LinearProgressIndicator();
                    }

                    var votaciones = snap.data!.docs;
                    if (_filtroEstado != 'todas') {
                      votaciones = votaciones
                          .where((d) =>
                              (d.data() as Map)['estado'] == _filtroEstado)
                          .toList();
                    }
                    if (_filtroTipo != 'todos') {
                      votaciones = votaciones
                          .where((d) =>
                              (d.data() as Map)['tipo'] == _filtroTipo)
                          .toList();
                    }

                    if (votaciones.isEmpty) {
                      return Center(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.celesteBorde),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.how_to_vote_outlined,
                                  size: 48, color: AppTheme.textoSecundario),
                              SizedBox(height: 12),
                              Text(
                                'No hay votaciones con ese filtro',
                                style: TextStyle(
                                    color: AppTheme.textoSecundario),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: votaciones.length,
                      itemBuilder: (context, i) {
                        final data =
                            votaciones[i].data() as Map<String, dynamic>;
                        return _VotacionTile(
                          votacionId: votaciones[i].id,
                          data: data,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VotacionTile extends StatelessWidget {
  const _VotacionTile({required this.votacionId, required this.data});

  final String votacionId;
  final Map<String, dynamic> data;

  Future<void> _navegar(BuildContext context) async {
    final tipo = data['tipo'] as String? ?? '';
    final objetoId = data['objetoId'] as String? ?? '';
    if (objetoId.isEmpty) return;

    String proyectoId;
    if (tipo == 'proyecto') {
      proyectoId = objetoId;
    } else {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('presupuestos_proyecto')
            .doc(objetoId)
            .get();
        proyectoId = snap.data()?['proyectoId'] as String? ?? '';
      } catch (_) {
        return;
      }
    }

    if (!context.mounted || proyectoId.isEmpty) return;
    final proyecto =
        context.read<ProyectoProvider>().obtenerPorId(proyectoId);
    if (proyecto == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProyectoDetalleScreen(proyecto: proyecto),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = data['estado'] as String? ?? 'en_curso';
    final tipo = data['tipo'] as String? ?? 'presupuesto';
    final titulo = data['titulo'] as String? ?? '';
    final fechaCreacion = (data['fechaCreacion'] as Timestamp?)?.toDate();
    final fechaCierre = (data['fechaCierre'] as Timestamp?)?.toDate();

    final (colorEstado, iconoEstado, labelEstado) = switch (estado) {
      'aprobada' => (AppTheme.verdeIngreso, Icons.check_circle, 'Aprobada'),
      'rechazada' => (AppTheme.rojoGasto, Icons.cancel, 'Rechazada'),
      'cerrada_sin_quorum' => (
          AppTheme.textoSecundario,
          Icons.remove_circle,
          'Sin quórum'
        ),
      _ => (AppTheme.verdeTeal, Icons.how_to_vote, 'En curso'),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navegar(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorEstado.withValues(alpha: 0.12),
                ),
                child: Icon(iconoEstado, color: colorEstado, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.celesteFondo,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.celesteBorde),
                          ),
                          child: Text(
                            tipo == 'proyecto' ? 'Proyecto' : 'Presupuesto',
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.azulOscuro),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorEstado.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: colorEstado.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        labelEstado,
                        style: TextStyle(
                            fontSize: 10,
                            color: colorEstado,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (fechaCreacion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Iniciada ${DateFormat('dd/MM/yyyy').format(fechaCreacion)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textoSecundario),
                      ),
                    ],
                    if (fechaCierre != null)
                      Text(
                        'Cerrada ${DateFormat('dd/MM/yyyy').format(fechaCierre)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textoSecundario),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget para la sección de votaciones en HomeScreen
class SeccionVotacionesHome extends StatelessWidget {
  const SeccionVotacionesHome({super.key, this.mostrarVerTodas = true});

  final bool mostrarVerTodas;

  Future<void> _navegar(BuildContext context, Map<String, dynamic> data) async {
    final tipo = data['tipo'] as String? ?? 'proyecto';
    final objetoId = data['objetoId'] as String?;
    if (objetoId == null) return;

    String? proyectoId;
    if (tipo == 'proyecto') {
      proyectoId = objetoId;
    } else if (tipo == 'presupuesto') {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('presupuestos_proyecto')
            .doc(objetoId)
            .get();
        proyectoId = snap.data()?['proyectoId'] as String?;
      } catch (_) {
        return;
      }
    }

    if (proyectoId == null || !context.mounted) return;
    final proyecto = context.read<ProyectoProvider>().obtenerPorId(proyectoId);
    if (proyecto == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ProyectoDetalleScreen(proyecto: proyecto)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('votaciones')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final docs = (snap.data?.docs ?? [])
            .where((d) => (d.data() as Map)['estado'] == 'en_curso')
            .toList();

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.how_to_vote_outlined,
                    size: 40, color: AppTheme.textoSecundario),
                SizedBox(height: 8),
                Text(
                  'No hay votaciones activas',
                  style: TextStyle(color: AppTheme.textoSecundario),
                ),
              ],
            ),
          );
        }

        final visibles = docs.take(3).toList();

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                itemCount: visibles.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 52),
                itemBuilder: (context, i) {
                  final data = visibles[i].data() as Map<String, dynamic>;
                  final votacionId = visibles[i].id;

                  return FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('votos')
                        .where('votacionId', isEqualTo: votacionId)
                        .get(),
                    builder: (context, votosSnap) {
                      final totalVotos = votosSnap.data?.docs.length ?? 0;
                      final miSocioId =
                          context.read<AuthProvider>().socioId;
                      final yaVote = miSocioId != null &&
                          (votosSnap.data?.docs.any((v) =>
                                  (v.data() as Map)['socioId'] ==
                                  miSocioId) ??
                              false);
                      final tipo = data['tipo'] as String? ?? 'proyecto';
                      final titulo = (data['titulo'] as String? ?? '')
                          .replaceFirst('Votación — ', '')
                          .replaceFirst('Votación de presupuestos — ', '');

                      return Material(
                        color: Colors.white,
                        child: InkWell(
                          onTap: () => _navegar(context, data),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.celesteFondo,
                                  ),
                                  child: Icon(
                                    tipo == 'proyecto'
                                        ? Icons.folder
                                        : Icons.receipt_long,
                                    color: AppTheme.azulMedio,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        titulo,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textoPrincipal),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.celesteFondo,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color:
                                                      AppTheme.celesteBorde),
                                            ),
                                            child: Text(
                                              tipo == 'proyecto'
                                                  ? 'Proyecto'
                                                  : 'Presupuesto',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppTheme.azulOscuro),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '· $totalVotos votos emitidos',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppTheme.textoSecundario),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (yaVote)
                                  const Icon(Icons.check_circle,
                                      color: AppTheme.verdeIngreso, size: 18)
                                else if (miSocioId != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.verdeTeal,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Votar',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  )
                                else
                                  const Icon(Icons.chevron_right,
                                      color: AppTheme.textoSecundario,
                                      size: 18),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (mostrarVerTodas)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const VotacionesScreen()),
                ),
                child: const Text('Ver todas las votaciones'),
              ),
          ],
        );
      },
    );
  }
}
