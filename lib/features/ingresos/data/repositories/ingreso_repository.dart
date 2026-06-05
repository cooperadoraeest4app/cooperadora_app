import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/ingreso.dart';

class IngresoRepository {
  final _collection =
      FirebaseFirestore.instance.collection('ingresos');

  Stream<List<Ingreso>> obtenerTodos() {
    return _collection
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Ingreso.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Ingreso>> obtenerPorMes(int mes, int anio) {
    final inicio = Timestamp.fromDate(DateTime(anio, mes));
    final fin = Timestamp.fromDate(DateTime(anio, mes + 1));

    return _collection
        .where('fecha', isGreaterThanOrEqualTo: inicio)
        .where('fecha', isLessThan: fin)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Ingreso.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> agregar(Ingreso ingreso) {
    return _collection.add(ingreso.toMap());
  }

  Future<void> actualizar(Ingreso ingreso) {
    return _collection.doc(ingreso.id).update(ingreso.toMap());
  }

  Future<void> eliminar(String id) {
    return _collection.doc(id).delete();
  }
}
