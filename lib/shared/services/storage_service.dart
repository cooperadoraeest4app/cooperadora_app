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
    if (bytes.isEmpty) {
      throw Exception('Los bytes del archivo están vacíos');
    }

    final ref = _storage.ref('comprobantes/$path/$nombreArchivo');
    // ignore: avoid_print
    print('[StorageService] Subiendo $nombreArchivo (${bytes.length} bytes) → comprobantes/$path/');

    final uploadTask = ref.putData(bytes);
    await uploadTask;

    final url = await ref.getDownloadURL();
    // ignore: avoid_print
    print('[StorageService] Upload completo. URL: $url');
    return url;
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
