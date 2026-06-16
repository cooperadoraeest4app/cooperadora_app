import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UsuariosProvider extends ChangeNotifier {
  StreamSubscription? _usuariosSub;

  List<Map<String, dynamic>> _usuarios = [];
  bool isLoading = false;
  String? error;

  List<Map<String, dynamic>> get usuarios => _usuarios;

  Stream<List<Map<String, dynamic>>> get usuariosStream =>
      FirebaseFirestore.instance.collection('usuarios').snapshots().map(
            (snap) =>
                snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
          );

  // Llamado desde ProxyProvider cuando hay usuario autenticado.
  void iniciarSiNecesario() {
    if (_usuariosSub != null) return;
    isLoading = true;
    _usuariosSub = FirebaseFirestore.instance
        .collection('usuarios')
        .snapshots()
        .listen(
      (snap) {
        _usuarios = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        error = 'Error al cargar usuarios.';
        isLoading = false;
        notifyListeners();
      },
    );
  }

  // Llamado desde ProxyProvider cuando se cierra sesión.
  void limpiar() {
    _usuariosSub?.cancel();
    _usuariosSub = null;
    _usuarios = [];
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _usuariosSub?.cancel();
    super.dispose();
  }

  Future<void> actualizarRol(String id, String rol) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(id)
          .update({'rol': rol});
    } catch (_) {
      error = 'Error al actualizar el rol.';
      notifyListeners();
    }
  }

  Future<void> activarDesactivar(String id, bool activo) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(id)
          .update({'activo': activo});
    } catch (_) {
      error = 'Error al actualizar el estado.';
      notifyListeners();
    }
  }
}
