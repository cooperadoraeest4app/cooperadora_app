import 'package:cloud_firestore/cloud_firestore.dart';

class ConfiguracionRepository {
  final _doc =
      FirebaseFirestore.instance.collection('configuracion').doc('config');

  Future<Map<String, dynamic>?> obtener() async {
    final snap = await _doc.get();
    return snap.exists ? snap.data() : null;
  }

  Future<void> guardar(Map<String, dynamic> datos) {
    return _doc.set(datos, SetOptions(merge: true));
  }
}
