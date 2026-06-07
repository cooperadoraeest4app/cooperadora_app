import 'package:cloud_firestore/cloud_firestore.dart';

class InvitacionRepository {
  final _collection = FirebaseFirestore.instance.collection('invitaciones');

  Stream<List<Map<String, dynamic>>> obtenerTodas() {
    return _collection
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Future<void> crear(Map<String, dynamic> datos) {
    return _collection.add(datos);
  }

  Future<void> eliminar(String id) {
    return _collection.doc(id).delete();
  }

  Future<Map<String, dynamic>?> obtenerPorCodigo(String codigo) async {
    final snap = await _collection
        .where('codigo', isEqualTo: codigo)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return {...doc.data(), 'id': doc.id};
  }
}
