import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/cuenta_bancaria.dart';
import '../../domain/models/movimiento_bancario.dart';

class CuentaBancariaRepository {
  static const _docId = 'cuenta_principal';

  final _col = FirebaseFirestore.instance.collection('cuenta_bancaria');
  final _movCol = FirebaseFirestore.instance
      .collection('cuenta_bancaria')
      .doc('cuenta_principal')
      .collection('movimientos');

  Stream<CuentaBancaria?> obtener() {
    return _col.doc(_docId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return CuentaBancaria.fromMap(snap.data()!, snap.id);
    });
  }

  Future<void> crear(CuentaBancaria cuenta) =>
      _col.doc(_docId).set(cuenta.toMap());

  Future<void> actualizarSaldo(
    double nuevoSaldo,
    String usuarioId, {
    String? observaciones,
  }) async {
    final snap = await _col.doc(_docId).get();
    final saldoAnterior =
        (snap.data()?['saldoActual'] as num? ?? 0).toDouble();

    final batch = FirebaseFirestore.instance.batch();

    batch.update(_col.doc(_docId), {
      'saldoActual': nuevoSaldo,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });

    batch.set(_movCol.doc(), {
      'tipo': 'actualizacion_saldo',
      'saldoAnterior': saldoAnterior,
      'saldoNuevo': nuevoSaldo,
      'observaciones': observaciones,
      'usuarioId': usuarioId,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> actualizarSaldoConResumen(
    double nuevoSaldo,
    String usuarioId,
    String periodo,
    String archivoPlaceholder, {
    String? observaciones,
  }) async {
    final snap = await _col.doc(_docId).get();
    final saldoAnterior =
        (snap.data()?['saldoActual'] as num? ?? 0).toDouble();

    final batch = FirebaseFirestore.instance.batch();

    batch.update(_col.doc(_docId), {
      'saldoActual': nuevoSaldo,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });

    batch.set(_movCol.doc(), {
      'tipo': 'resumen_mensual',
      'saldoAnterior': saldoAnterior,
      'saldoNuevo': nuevoSaldo,
      'periodo': periodo,
      'archivo': archivoPlaceholder,
      'observaciones': observaciones,
      'usuarioId': usuarioId,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Stream<List<MovimientoBancario>> obtenerMovimientos() {
    return _movCol
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => MovimientoBancario.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> agregarMovimiento(MovimientoBancario movimiento) =>
      _movCol.add(movimiento.toMap());

  Future<void> eliminarMovimiento(String id) => _movCol.doc(id).delete();
}
