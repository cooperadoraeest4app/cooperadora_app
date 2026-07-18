import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/services/log_cambio_service.dart';
import '../../domain/models/pago_cuota.dart';

class PagoCuotaRepository {
  final _col = FirebaseFirestore.instance.collection('pagos_cuota');

  Stream<List<PagoCuota>> obtenerPagosSocio(String socioId) {
    return _col
        .where('socioId', isEqualTo: socioId)
        .orderBy('fechaPago', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PagoCuota.fromMap(d.data(), d.id)).toList());
  }

  Future<String> registrarPago(PagoCuota pago) async {
    final doc = await _col.add(pago.toMap());
    await LogCambioService().registrar(
      entidadTipo: 'pago_cuota',
      entidadId: doc.id,
      usuarioId: pago.usuarioId,
      accion: 'creacion',
      nuevo: pago.toMap(),
    );
    return doc.id;
  }

  Future<void> eliminarPago(String id, String usuarioId) async {
    final snap = await _col.doc(id).get();
    await LogCambioService().registrar(
      entidadTipo: 'pago_cuota',
      entidadId: id,
      usuarioId: usuarioId,
      accion: 'eliminacion',
      anterior: snap.data(),
    );
    await _col.doc(id).delete();
  }

  Future<void> migrarCuotasAPagos() async {
    final cuotasSnap = await FirebaseFirestore.instance
        .collection('cuotas')
        .where('estado', isEqualTo: 'pagada')
        .get();

    if (cuotasSnap.docs.isEmpty) return;

    const chunkSize = 500;
    for (var i = 0; i < cuotasSnap.docs.length; i += chunkSize) {
      final chunk = cuotasSnap.docs
          .sublist(i, (i + chunkSize).clamp(0, cuotasSnap.docs.length));
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in chunk) {
        final data = doc.data();
        final ref = _col.doc();
        batch.set(ref, {
          'socioId': data['socioId'] ?? '',
          'monto': data['monto'] ?? 0.0,
          'metodoPagoId': data['metodoPagoId'] ?? '',
          'fechaPago': data['fechaPago'] ?? data['fechaCreacion'],
          'usuarioId': data['usuarioId'] ?? '',
          'fechaCreacion':
              data['fechaCreacion'] ?? FieldValue.serverTimestamp(),
          if (data['ingresoId'] != null) 'ingresoId': data['ingresoId'],
          'migradoDeCuotaId': doc.id,
        });
      }
      await batch.commit();
    }

    // ignore: avoid_print
    print('[Migracion] ${cuotasSnap.docs.length} cuotas migradas a pagos_cuota');
  }
}
