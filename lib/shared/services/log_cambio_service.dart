import 'package:cloud_firestore/cloud_firestore.dart';

class LogCambioService {
  final _col = FirebaseFirestore.instance.collection('log_cambios');

  Future<void> registrar({
    required String entidadTipo,
    required String entidadId,
    required String usuarioId,
    required String accion,
    Map<String, dynamic>? anterior,
    Map<String, dynamic>? nuevo,
  }) async {
    await _col.add({
      'entidadTipo': entidadTipo,
      'entidadId': entidadId,
      'usuarioId': usuarioId,
      'accion': accion,
      'camposAnteriores': anterior,
      'camposNuevos': nuevo,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> obtenerPorEntidad(
    String entidadTipo,
    String entidadId,
  ) {
    return _col
        .where('entidadTipo', isEqualTo: entidadTipo)
        .where('entidadId', isEqualTo: entidadId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Stream<List<Map<String, dynamic>>> obtenerTodos({int limite = 50}) {
    return _col
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }
}
