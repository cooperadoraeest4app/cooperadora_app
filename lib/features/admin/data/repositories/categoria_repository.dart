import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriaRepository {
  final _col = FirebaseFirestore.instance.collection('categorias');

  Stream<List<Map<String, dynamic>>> obtenerTodas() {
    return _col.orderBy('nombre').snapshots().map(
          (s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
        );
  }

  Future<void> crear(Map<String, dynamic> datos) =>
      _col.add({...datos, 'fechaCreacion': FieldValue.serverTimestamp()});

  Future<void> actualizar(String id, Map<String, dynamic> datos) =>
      _col.doc(id).update(datos);

  Future<void> activarDesactivar(String id, bool activa) =>
      _col.doc(id).update({'activa': activa});

  Future<bool> estaVacia() async =>
      (await _col.limit(1).get()).docs.isEmpty;

  Future<void> crearLote(List<Map<String, dynamic>> items) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final item in items) {
      batch.set(_col.doc(), {...item, 'fechaCreacion': Timestamp.now()});
    }
    await batch.commit();
  }
}
