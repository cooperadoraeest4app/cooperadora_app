import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/ingreso.dart';
import '../../../../shared/services/log_cambio_service.dart';

class IngresoRepository {
  final _collection = FirebaseFirestore.instance.collection('ingresos');
  final _log = LogCambioService();

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

  Future<String> agregar(Ingreso ingreso) async {
    final ref = await _collection.add(ingreso.toMap());
    await _log.registrar(
      entidadTipo: 'ingreso',
      entidadId: ref.id,
      usuarioId: ingreso.usuarioId,
      accion: 'creacion',
      nuevo: ingreso.toMap(),
    );
    return ref.id;
  }

  Future<void> actualizar(Ingreso ingreso) async {
    final snap = await _collection.doc(ingreso.id).get();
    final anterior = snap.data();
    await _collection.doc(ingreso.id).update(ingreso.toMap());
    await _log.registrar(
      entidadTipo: 'ingreso',
      entidadId: ingreso.id,
      usuarioId: ingreso.usuarioId,
      accion: 'modificacion',
      anterior: anterior,
      nuevo: ingreso.toMap(),
    );
  }

  Future<void> eliminar(String id) async {
    final snap = await _collection.doc(id).get();
    final anterior = snap.data();
    final usuarioId = anterior?['usuarioId'] as String? ?? 'desconocido';
    await _collection.doc(id).delete();
    await _log.registrar(
      entidadTipo: 'ingreso',
      entidadId: id,
      usuarioId: usuarioId,
      accion: 'eliminacion',
      anterior: anterior,
    );
  }
}
