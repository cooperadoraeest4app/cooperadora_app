import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/gasto.dart';
import '../../../../shared/services/log_cambio_service.dart';

class GastoRepository {
  final _collection = FirebaseFirestore.instance.collection('gastos');
  final _log = LogCambioService();

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

  Future<String> agregar(Gasto gasto) async {
    final ref = await _collection.add(gasto.toMap());
    await _log.registrar(
      entidadTipo: 'gasto',
      entidadId: ref.id,
      usuarioId: gasto.usuarioId,
      accion: 'creacion',
      nuevo: gasto.toMap(),
    );
    return ref.id;
  }

  Future<void> actualizar(Gasto gasto) async {
    final snap = await _collection.doc(gasto.id).get();
    final anterior = snap.data();
    await _collection.doc(gasto.id).update(gasto.toMap());
    await _log.registrar(
      entidadTipo: 'gasto',
      entidadId: gasto.id,
      usuarioId: gasto.usuarioId,
      accion: 'modificacion',
      anterior: anterior,
      nuevo: gasto.toMap(),
    );
  }

  Future<void> eliminar(String id) async {
    final snap = await _collection.doc(id).get();
    final anterior = snap.data();
    final usuarioId = anterior?['usuarioId'] as String? ?? 'desconocido';
    await _collection.doc(id).delete();
    await _log.registrar(
      entidadTipo: 'gasto',
      entidadId: id,
      usuarioId: usuarioId,
      accion: 'eliminacion',
      anterior: anterior,
    );
  }
}
