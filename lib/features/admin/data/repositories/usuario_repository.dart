import 'package:cloud_firestore/cloud_firestore.dart';

class UsuarioRepository {
  final _collection = FirebaseFirestore.instance.collection('usuarios');

  Stream<List<Map<String, dynamic>>> obtenerTodos() {
    return _collection.snapshots().map(
          (snap) => snap.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList(),
        );
  }

  Future<void> actualizarRol(String id, String nuevoRol) {
    return _collection.doc(id).update({'rol': nuevoRol});
  }

  Future<void> activarDesactivar(String id, bool activo) {
    return _collection.doc(id).update({'activo': activo});
  }
}
