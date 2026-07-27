import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../proyectos/presentation/providers/proyecto_provider.dart';
import '../../../proyectos/presentation/screens/proyecto_detalle_screen.dart';
import 'confirmar_pago_cuota_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  String _filtroLeida = 'todas';

  Map<String, dynamic> _configNotificacion(String tipo) {
    return switch (tipo) {
      'pago_cuota_pendiente' || 'pago_declarado' => {
          'icono': Icons.payment,
          'color': AppTheme.amarilloAlerta,
          'etiqueta': 'Pago pendiente',
        },
      'pago_cuota_confirmado' || 'pago_confirmado' => {
          'icono': Icons.check_circle,
          'color': AppTheme.verdeIngreso,
          'etiqueta': 'Pago confirmado',
        },
      'pago_cuota_rechazado' || 'pago_rechazado' => {
          'icono': Icons.cancel,
          'color': AppTheme.rojoGasto,
          'etiqueta': 'Pago rechazado',
        },
      'votacion_proyecto_habilitada' || 'votacion_proyecto_abierta' => {
          'icono': Icons.how_to_vote,
          'color': AppTheme.verdeTeal,
          'etiqueta': 'Votación disponible',
        },
      'proyecto_aprobado' => {
          'icono': Icons.thumb_up,
          'color': AppTheme.verdeIngreso,
          'etiqueta': 'Proyecto aprobado',
        },
      'proyecto_rechazado' => {
          'icono': Icons.thumb_down,
          'color': AppTheme.rojoGasto,
          'etiqueta': 'Proyecto rechazado',
        },
      _ => {
          'icono': Icons.notifications,
          'color': AppTheme.azulMedio,
          'etiqueta': 'Notificación',
        },
    };
  }

  String _tituloParaTipo(String tipo, Map<String, dynamic> data) {
    final stored = data['titulo'] as String?;
    if (stored != null && stored.isNotEmpty) return stored;
    return switch (tipo) {
      'pago_declarado' => 'Pago declarado',
      'pago_confirmado' => 'Pago confirmado',
      'pago_rechazado' => 'Pago rechazado',
      _ => 'Notificación',
    };
  }

  String _mensajeParaTipo(String tipo, Map<String, dynamic> data) {
    final stored = data['mensaje'] as String?;
    if (stored != null && stored.isNotEmpty) return stored;
    if (tipo.startsWith('pago_')) {
      final nombre = data['nombreSocio'] as String? ?? 'Socio';
      final numero = (data['numeroSocio'] as num? ?? 0).toInt();
      final monto = (data['monto'] as num? ?? 0).toDouble();
      return '$nombre (N° ${numero.toString().padLeft(3, '0')}) — '
          '\$${NumberFormat('#,##0.00', 'es_AR').format(monto)}';
    }
    return '';
  }

  Future<void> _navegarANotificacion(
    Map<String, dynamic> data,
    DocumentReference ref,
  ) async {
    final leida = data['leida'] as bool? ?? false;
    if (!leida) await ref.update({'leida': true});
    if (!mounted) return;

    final tipo = data['tipo'] as String? ?? '';
    // Try generic referenciaId first, then legacy field names
    final referenciaId = (data['referenciaId'] as String?)?.isNotEmpty == true
        ? data['referenciaId'] as String
        : (data['pagoPendienteId'] as String?)?.isNotEmpty == true
            ? data['pagoPendienteId'] as String
            : null;

    switch (tipo) {
      case 'pago_declarado':
      case 'pago_cuota_pendiente':
      case 'pago_confirmado':
      case 'pago_cuota_confirmado':
      case 'pago_rechazado':
      case 'pago_cuota_rechazado':
        if (referenciaId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ConfirmarPagoCuotaScreen(pagoPendienteId: referenciaId),
            ),
          );
        }
        break;
      case 'votacion_proyecto_habilitada':
      case 'votacion_proyecto_abierta':
      case 'proyecto_aprobado':
      case 'proyecto_rechazado':
      case 'votacion_proyecto_resultado':
        final pid = referenciaId ?? data['proyectoId'] as String?;
        if (pid != null && pid.isNotEmpty) {
          final proyecto =
              context.read<ProyectoProvider>().obtenerPorId(pid);
          if (proyecto != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProyectoDetalleScreen(proyecto: proyecto),
              ),
            );
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _filtroLeida,
              decoration: const InputDecoration(
                labelText: 'Mostrar',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'todas', child: Text('Todas')),
                DropdownMenuItem(
                    value: 'no_leidas', child: Text('No leídas')),
                DropdownMenuItem(value: 'leidas', child: Text('Leídas')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _filtroLeida = v);
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notificaciones')
                  .where('destinatarioRol', isEqualTo: 'editor')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = List.of(snap.data?.docs ?? [])
                  ..sort((a, b) {
                    final aTs = (a.data() as Map)['creadoEn'];
                    final bTs = (b.data() as Map)['creadoEn'];
                    if (aTs == null && bTs == null) return 0;
                    if (aTs == null) return 1;
                    if (bTs == null) return -1;
                    return (bTs as Timestamp).compareTo(aTs as Timestamp);
                  });

                if (_filtroLeida == 'no_leidas') {
                  docs = docs
                      .where((d) =>
                          !((d.data() as Map)['leida'] as bool? ?? false))
                      .toList();
                } else if (_filtroLeida == 'leidas') {
                  docs = docs
                      .where((d) =>
                          (d.data() as Map)['leida'] as bool? ?? false)
                      .toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 48, color: AppTheme.textoSecundario),
                        SizedBox(height: 12),
                        Text('Sin notificaciones',
                            style:
                                TextStyle(color: AppTheme.textoSecundario)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, i) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final leida = data['leida'] as bool? ?? false;
                    final tipo = data['tipo'] as String? ?? '';
                    final config = _configNotificacion(tipo);
                    final color = config['color'] as Color;
                    final titulo = _tituloParaTipo(tipo, data);
                    final mensaje = _mensajeParaTipo(tipo, data);
                    final creadoEn = data['creadoEn'] is Timestamp
                        ? (data['creadoEn'] as Timestamp).toDate()
                        : DateTime.now();

                    return ListTile(
                      tileColor: leida
                          ? null
                          : AppTheme.celesteFondo.withValues(alpha: 0.6),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          config['icono'] as IconData,
                          color: color,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              titulo,
                              style: TextStyle(
                                fontWeight: leida
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              config['etiqueta'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (mensaje.isNotEmpty)
                            Text(
                              mensaje,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(creadoEn),
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.textoSecundario),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppTheme.textoSecundario),
                      isThreeLine: mensaje.isNotEmpty,
                      onTap: () => _navegarANotificacion(data, doc.reference),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
