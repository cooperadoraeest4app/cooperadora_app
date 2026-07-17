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
    if (gasto.presupuestoProyectoId != null && gasto.proyectoId != null) {
      await _actualizarItemsPresupuesto(
        proyectoId: gasto.proyectoId!,
        presupuestoId: gasto.presupuestoProyectoId!,
        nuevoEstado: 'comprado',
        gastoId: ref.id,
      );
      await _marcarPresupuestoComoComprado(
        presupuestoId: gasto.presupuestoProyectoId!,
        gastoId: ref.id,
      );
    }
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

    final presupuestoId = anterior?['presupuestoProyectoId'] as String?;
    if (presupuestoId != null) {
      await _revertirItemsPresupuesto(gastoId: id);
      await _revertirVotacionComprada(presupuestoId: presupuestoId);
    }

    await _collection.doc(id).delete();
    await _log.registrar(
      entidadTipo: 'gasto',
      entidadId: id,
      usuarioId: usuarioId,
      accion: 'eliminacion',
      anterior: anterior,
    );
  }

  Future<void> _actualizarItemsPresupuesto({
    required String proyectoId,
    required String presupuestoId,
    required String nuevoEstado,
    required String gastoId,
  }) async {
    final itemsSnap = await FirebaseFirestore.instance
        .collection('items_proyecto')
        .where('proyectoId', isEqualTo: proyectoId)
        .where('presupuestosIds', arrayContains: presupuestoId)
        .get();
    if (itemsSnap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in itemsSnap.docs) {
      final estadoAnterior = doc.data()['estado'] as String? ?? 'pendiente';
      batch.update(doc.reference, {
        'estado': nuevoEstado,
        'estadoAnterior': estadoAnterior,
        'gastoQueLoActualizó': gastoId,
      });
    }
    await batch.commit();
  }

  Future<void> _marcarPresupuestoComoComprado({
    required String presupuestoId,
    required String gastoId,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection('votaciones')
        .where('objetoId', isEqualTo: presupuestoId)
        .where('estado', isEqualTo: 'aprobada')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return;
    await snap.docs.first.reference.update({
      'estado': 'comprado',
      'gastoId': gastoId,
    });
  }

  Future<void> _revertirVotacionComprada({required String presupuestoId}) async {
    final snap = await FirebaseFirestore.instance
        .collection('votaciones')
        .where('objetoId', isEqualTo: presupuestoId)
        .where('estado', isEqualTo: 'comprado')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return;
    await snap.docs.first.reference.update({
      'estado': 'aprobada',
      'gastoId': FieldValue.delete(),
    });
  }

  Future<void> _revertirItemsPresupuesto({required String gastoId}) async {
    final itemsSnap = await FirebaseFirestore.instance
        .collection('items_proyecto')
        .where('gastoQueLoActualizó', isEqualTo: gastoId)
        .get();
    if (itemsSnap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in itemsSnap.docs) {
      final estadoAnterior = doc.data()['estadoAnterior'] as String? ?? 'pendiente';
      batch.update(doc.reference, {
        'estado': estadoAnterior,
        'estadoAnterior': FieldValue.delete(),
        'gastoQueLoActualizó': FieldValue.delete(),
      });
    }
    await batch.commit();
  }
}
