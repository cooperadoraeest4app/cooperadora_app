import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/log_cambio_service.dart';

class ConfirmarPagoCuotaScreen extends StatefulWidget {
  final String pagoPendienteId;
  const ConfirmarPagoCuotaScreen({super.key, required this.pagoPendienteId});

  @override
  State<ConfirmarPagoCuotaScreen> createState() =>
      _ConfirmarPagoCuotaScreenState();
}

class _ConfirmarPagoCuotaScreenState
    extends State<ConfirmarPagoCuotaScreen> {
  bool _procesando = false;

  static String _fmt(double m) =>
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2)
          .format(m);

  Future<void> _confirmar(Map<String, dynamic> data) async {
    setState(() => _procesando = true);
    try {
      final socioId = data['socioId'] as String;
      final monto = (data['monto'] as num).toDouble();
      final fechaPago = (data['fechaPago'] as Timestamp).toDate();
      final observaciones = data['observaciones'] as String?;
      final usuarioUid = data['usuarioUid'] as String? ?? '';

      final batch = FirebaseFirestore.instance.batch();

      // 1. Update pagos_pendientes
      final pagoRef = FirebaseFirestore.instance
          .collection('pagos_pendientes')
          .doc(widget.pagoPendienteId);
      batch.update(pagoRef, {
        'estado': 'confirmado',
        'confirmadoEn': FieldValue.serverTimestamp(),
      });

      // 2. Create pagos_cuota
      final pagoCuotaRef =
          FirebaseFirestore.instance.collection('pagos_cuota').doc();
      batch.set(pagoCuotaRef, {
        'socioId': socioId,
        'monto': monto,
        'metodoPagoId': 'transferencia',
        'fechaPago': Timestamp.fromDate(fechaPago),
        'observaciones': observaciones,
        'usuarioId': usuarioUid,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'pagoPendienteId': widget.pagoPendienteId,
      });

      // 3. Notify socio
      final notifRef =
          FirebaseFirestore.instance.collection('notificaciones').doc();
      batch.set(notifRef, {
        'tipo': 'pago_confirmado',
        'pagoPendienteId': widget.pagoPendienteId,
        'socioId': socioId,
        'destinatarioRol': 'socio',
        'destinatarioUid': usuarioUid,
        'leida': false,
        'creadoEn': FieldValue.serverTimestamp(),
        'monto': monto,
      });

      await batch.commit();

      await LogCambioService().registrar(
        entidadTipo: 'pago_cuota_pendiente',
        entidadId: widget.pagoPendienteId,
        usuarioId: FirebaseAuth.instance.currentUser?.uid ?? '',
        accion: 'confirmacion',
        nuevo: {'estado': 'confirmado', 'monto': monto},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago confirmado correctamente'),
          backgroundColor: AppTheme.verdeTeal,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.rojoGasto),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _rechazar(Map<String, dynamic> data) async {
    final motivoCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Indicá el motivo del rechazo:'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                  hintText: 'Motivo (obligatorio)'),
              autofocus: true,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.rojoGasto,
                foregroundColor: Colors.white),
            onPressed: () {
              if (motivoCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final motivo = motivoCtrl.text.trim();
    motivoCtrl.dispose();

    setState(() => _procesando = true);
    try {
      final socioId = data['socioId'] as String;
      final monto = (data['monto'] as num).toDouble();
      final usuarioUid = data['usuarioUid'] as String? ?? '';

      final batch = FirebaseFirestore.instance.batch();

      final pagoRef = FirebaseFirestore.instance
          .collection('pagos_pendientes')
          .doc(widget.pagoPendienteId);
      batch.update(pagoRef, {
        'estado': 'rechazado',
        'motivoRechazo': motivo,
        'rechazadoEn': FieldValue.serverTimestamp(),
      });

      final notifRef =
          FirebaseFirestore.instance.collection('notificaciones').doc();
      batch.set(notifRef, {
        'tipo': 'pago_rechazado',
        'pagoPendienteId': widget.pagoPendienteId,
        'socioId': socioId,
        'destinatarioRol': 'socio',
        'destinatarioUid': usuarioUid,
        'leida': false,
        'creadoEn': FieldValue.serverTimestamp(),
        'monto': monto,
        'motivoRechazo': motivo,
      });

      await batch.commit();

      await LogCambioService().registrar(
        entidadTipo: 'pago_cuota_pendiente',
        entidadId: widget.pagoPendienteId,
        usuarioId: FirebaseAuth.instance.currentUser?.uid ?? '',
        accion: 'rechazo',
        nuevo: {'estado': 'rechazado', 'motivoRechazo': motivo},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago rechazado'),
          backgroundColor: AppTheme.amarilloAlerta,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.rojoGasto),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar pago de cuota'),
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('pagos_pendientes')
            .doc(widget.pagoPendienteId)
            .get(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('No se encontró el pago'));
          }

          final data = snap.data!.data() as Map<String, dynamic>;
          final estado = data['estado'] as String? ?? 'pendiente';
          final nombreSocio = data['nombreSocio'] as String? ?? 'Socio';
          final numeroSocio =
              (data['numeroSocio'] as num? ?? 0).toInt();
          final monto = (data['monto'] as num? ?? 0).toDouble();
          final fechaPago = data['fechaPago'] is Timestamp
              ? (data['fechaPago'] as Timestamp).toDate()
              : DateTime.now();
          final comprobanteUrl = data['comprobanteUrl'] as String?;
          final observaciones = data['observaciones'] as String?;

          final yaResuelto = estado != 'pendiente';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Estado
              if (yaResuelto)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: estado == 'confirmado'
                        ? AppTheme.verdeIngreso.withValues(alpha: 0.1)
                        : AppTheme.rojoGasto.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: estado == 'confirmado'
                          ? AppTheme.verdeIngreso
                          : AppTheme.rojoGasto,
                    ),
                  ),
                  child: Text(
                    estado == 'confirmado'
                        ? 'Este pago ya fue confirmado'
                        : 'Este pago fue rechazado',
                    style: TextStyle(
                      color: estado == 'confirmado'
                          ? AppTheme.verdeIngreso
                          : AppTheme.rojoGasto,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // Datos del socio
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Datos del pago',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _fila('Socio',
                          '$nombreSocio (N° ${numeroSocio.toString().padLeft(3, '0')})'),
                      _fila('Monto', _fmt(monto)),
                      _fila('Fecha declarada',
                          DateFormat('dd/MM/yyyy').format(fechaPago)),
                      if (observaciones != null && observaciones.isNotEmpty)
                        _fila('Observaciones', observaciones),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Comprobante
              if (comprobanteUrl != null) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Ver comprobante'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.azulMedio,
                    side: const BorderSide(color: AppTheme.azulMedio),
                  ),
                  onPressed: () async {
                    final url = Uri.parse(comprobanteUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'No se pudo abrir el comprobante')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Botones
              if (!yaResuelto && !_procesando) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.verdeTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _confirmar(data),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar pago',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.rojoGasto,
                    side: const BorderSide(color: AppTheme.rojoGasto),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _rechazar(data),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Rechazar',
                      style: TextStyle(fontSize: 15)),
                ),
              ],
              if (_procesando)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                )),
            ],
          );
        },
      ),
    );
  }

  Widget _fila(String label, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textoSecundario)),
            Flexible(
              child: Text(valor,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}
