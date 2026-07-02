import 'package:cloud_firestore/cloud_firestore.dart';

class NombreUsuarioService {
  static final Map<String, String> _cache = {};

  static Future<String> obtenerNombre(String usuarioId) async {
    if (usuarioId.isEmpty) return 'sin dato';
    if (_cache.containsKey(usuarioId)) return _cache[usuarioId]!;

    try {
      final usuarioSnap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioId)
          .get();

      final data = usuarioSnap.data();
      if (data == null) return _cache[usuarioId] = usuarioId;

      final personaId = data['personaId'] as String?;
      if (personaId != null && personaId.isNotEmpty) {
        final personaSnap = await FirebaseFirestore.instance
            .collection('personas')
            .doc(personaId)
            .get();
        final personaData = personaSnap.data();
        if (personaData != null) {
          final nombre =
              '${personaData['nombre'] ?? ''} ${personaData['apellido'] ?? ''}'
                  .trim();
          if (nombre.isNotEmpty) {
            return _cache[usuarioId] = nombre;
          }
        }
      }

      final email = data['email'] as String?;
      return _cache[usuarioId] = email ?? usuarioId;
    } catch (_) {
      return usuarioId;
    }
  }
}
