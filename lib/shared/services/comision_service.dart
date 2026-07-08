import 'package:cloud_firestore/cloud_firestore.dart';

class ComisionService {
  static final _usuarios = FirebaseFirestore.instance.collection('usuarios');

  /// true si el uid tiene rol editor o admin (puede cerrar balance).
  static Future<bool> esMiembroComisionDirectiva(String? uid) async {
    if (uid == null || uid.isEmpty) return false;
    try {
      final doc = await _usuarios.doc(uid).get();
      final rol = doc.data()?['rol'] as String?;
      return rol == 'editor' || rol == 'admin';
    } catch (_) {
      return false;
    }
  }
}
