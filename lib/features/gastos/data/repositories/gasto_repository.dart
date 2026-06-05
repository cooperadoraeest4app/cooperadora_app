import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/gasto.dart';

class GastoRepository {
  final _collection =
      FirebaseFirestore.instance.collection('gastos');

  Stream<List<Gasto>> obtenerTodos() {
    return _collection
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Gasto.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Gasto>> obtenerPorMes(int mes, int anio) {
    final inicio = Timestamp.fromDate(DateTime(anio, mes));
    final fin = Timestamp.fromDate(DateTime(anio, mes + 1));

    return _collection
        .where('fecha', isGreaterThanOrEqualTo: inicio)
        .where('fecha', isLessThan: fin)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Gasto.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> agregar(Gasto gasto) {
    return _collection.add(gasto.toMap());
  }

  Future<void> actualizar(Gasto gasto) {
    return _collection.doc(gasto.id).update(gasto.toMap());
  }

  Future<void> eliminar(String id) {
    return _collection.doc(id).delete();
  }
}
