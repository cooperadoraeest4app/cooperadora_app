import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pago_cuota.dart';
import '../models/recibo.dart';

class ReciboService {
  final _db = FirebaseFirestore.instance;

  static int ejercicioParaFecha(DateTime fecha) {
    return fecha.month >= 5 ? fecha.year : fecha.year - 1;
  }

  Future<int> _proximoNumero(int ejercicio) async {
    final snap = await _db
        .collection('recibos')
        .where('ejercicio', isEqualTo: ejercicio)
        .get();
    if (snap.docs.isEmpty) return 1;
    final nums = snap.docs
        .map((d) => (d.data()['numero'] as num? ?? 0).toInt())
        .toList();
    return nums.reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<Recibo?> obtenerPorPago(String pagoId) async {
    final snap = await _db
        .collection('recibos')
        .where('pagoId', isEqualTo: pagoId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Recibo.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  Future<Recibo> crearRecibo({
    required PagoCuota pago,
    required int numeroSocio,
    required String nombreSocio,
    required String metodoPago,
  }) async {
    final ejercicio = ejercicioParaFecha(pago.fechaPago);
    final numero = await _proximoNumero(ejercicio);
    final ahora = DateTime.now();

    final data = {
      'numero': numero,
      'ejercicio': ejercicio,
      'pagoId': pago.id,
      'socioId': pago.socioId,
      'numeroSocio': numeroSocio,
      'nombreSocio': nombreSocio,
      'monto': pago.monto,
      'fechaPago': Timestamp.fromDate(pago.fechaPago),
      'metodoPago': metodoPago,
      'usuarioId': pago.usuarioId,
      'creadoEn': Timestamp.fromDate(ahora),
    };

    final ref = await _db.collection('recibos').add(data);
    return Recibo(
      id: ref.id,
      numero: numero,
      ejercicio: ejercicio,
      pagoId: pago.id,
      socioId: pago.socioId,
      numeroSocio: numeroSocio,
      nombreSocio: nombreSocio,
      monto: pago.monto,
      fechaPago: pago.fechaPago,
      metodoPago: metodoPago,
      usuarioId: pago.usuarioId,
      creadoEn: ahora,
    );
  }

  Future<Recibo> obtenerOCrear({
    required PagoCuota pago,
    required int numeroSocio,
    required String nombreSocio,
    required String metodoPago,
  }) async {
    final existing = await obtenerPorPago(pago.id);
    if (existing != null) return existing;
    return crearRecibo(
      pago: pago,
      numeroSocio: numeroSocio,
      nombreSocio: nombreSocio,
      metodoPago: metodoPago,
    );
  }
}
