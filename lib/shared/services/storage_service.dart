import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  /// Sube un archivo a Storage y retorna la URL de descarga.
  /// [path] es la ruta relativa sin slash inicial ni final, ej: 'ingresos/2026/06'
  Future<String> subirComprobante(
    String path,
    Uint8List bytes,
    String nombreArchivo,
  ) async {
    final ref = _storage.ref('comprobantes/$path/$nombreArchivo');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }

  /// Elimina un archivo dado su URL de descarga de Firebase Storage.
  Future<void> eliminarComprobante(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // Archivo ya eliminado o URL inválida — ignorar
    }
  }
}
