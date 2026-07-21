import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import 'confirmar_pago_cuota_screen.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => _marcarTodasLeidas(),
            child: const Text('Marcar todas',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notificaciones')
            .where('destinatarioRol', isEqualTo: 'editor')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            // ignore: avoid_print
            print('[Notificaciones] error: ${snap.error}');
          }
          final docs = List.of(snap.data?.docs ?? [])
            ..sort((a, b) {
              final aTs = a.data() is Map
                  ? (a.data() as Map)['creadoEn']
                  : null;
              final bTs = b.data() is Map
                  ? (b.data() as Map)['creadoEn']
                  : null;
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return (bTs as Timestamp)
                  .compareTo(aTs as Timestamp);
            });
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none,
                      size: 48, color: AppTheme.textoSecundario),
                  SizedBox(height: 12),
                  Text('Sin notificaciones',
                      style: TextStyle(color: AppTheme.textoSecundario)),
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
              final nombreSocio = data['nombreSocio'] as String? ?? 'Socio';
              final numeroSocio =
                  (data['numeroSocio'] as num? ?? 0).toInt();
              final monto = (data['monto'] as num? ?? 0).toDouble();
              final pagoPendienteId =
                  data['pagoPendienteId'] as String? ?? '';
              final creadoEn = data['creadoEn'] is Timestamp
                  ? (data['creadoEn'] as Timestamp).toDate()
                  : DateTime.now();

              final titulo = switch (tipo) {
                'pago_declarado' => 'Pago declarado',
                _ => 'Notificación',
              };
              final subtitulo =
                  '$nombreSocio (N° ${numeroSocio.toString().padLeft(3, '0')}) — '
                  '\$${NumberFormat('#,##0.00', 'es_AR').format(monto)}';

              return ListTile(
                tileColor: leida
                    ? null
                    : AppTheme.celesteFondo.withValues(alpha: 0.5),
                leading: CircleAvatar(
                  backgroundColor: leida
                      ? AppTheme.textoSecundario.withValues(alpha: 0.15)
                      : AppTheme.celesteAccento,
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color:
                        leida ? AppTheme.textoSecundario : AppTheme.azulOscuro,
                    size: 20,
                  ),
                ),
                title: Text(
                  titulo,
                  style: TextStyle(
                    fontWeight:
                        leida ? FontWeight.normal : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subtitulo,
                        style: const TextStyle(fontSize: 12)),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(creadoEn),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textoSecundario),
                    ),
                  ],
                ),
                isThreeLine: true,
                onTap: () async {
                  if (!leida) {
                    await doc.reference.update({'leida': true});
                  }
                  if (pagoPendienteId.isNotEmpty && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConfirmarPagoCuotaScreen(
                          pagoPendienteId: pagoPendienteId,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _marcarTodasLeidas() async {
    final snap = await FirebaseFirestore.instance
        .collection('notificaciones')
        .where('destinatarioRol', isEqualTo: 'editor')
        .where('leida', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'leida': true});
    }
    await batch.commit();
  }
}
