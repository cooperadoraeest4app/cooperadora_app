import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UsuariosProvider extends ChangeNotifier {
  StreamSubscription? _usuariosSub;
  int _generacion = 0;

  List<Map<String, dynamic>> _usuarios = [];
  bool isLoading = false;
  String? error;

  List<Map<String, dynamic>> get usuarios => _usuarios;

  Stream<List<Map<String, dynamic>>> get usuariosStream =>
      FirebaseFirestore.instance.collection('usuarios').snapshots().map(
            (snap) =>
                snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
          );

  void iniciarSiNecesario() {
    if (_usuariosSub != null) return;
    isLoading = true;
    _usuariosSub = FirebaseFirestore.instance
        .collection('usuarios')
        .snapshots()
        .listen(
      (snap) {
        final rawUsers =
            snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        _enriquecerUsuarios(rawUsers, ++_generacion);
      },
      onError: (e) {
        error = 'Error al cargar usuarios.';
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _enriquecerUsuarios(
      List<Map<String, dynamic>> rawUsers, int gen) async {
    final personaIds = rawUsers
        .map((u) => u['personaId'] as String?)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final personaMap = <String, Map<String, dynamic>>{};
    if (personaIds.isNotEmpty) {
      final snaps = await Future.wait(
        personaIds.map((id) =>
            FirebaseFirestore.instance.collection('personas').doc(id).get()),
      );
      for (final snap in snaps) {
        if (snap.exists && snap.data() != null) {
          personaMap[snap.id] = snap.data()!;
        }
      }
    }

    if (gen != _generacion) return;

    _usuarios = rawUsers.map((u) {
      final personaId = u['personaId'] as String?;
      String nombreCompleto = '';
      if (personaId != null &&
          personaId.isNotEmpty &&
          personaMap.containsKey(personaId)) {
        final p = personaMap[personaId]!;
        final n =
            '${p['nombre'] ?? ''} ${p['apellido'] ?? ''}'.trim();
        if (n.isNotEmpty) nombreCompleto = n;
      }
      if (nombreCompleto.isEmpty) {
        nombreCompleto = u['email'] as String? ?? u['id'] as String? ?? '';
      }
      return {...u, 'nombreCompleto': nombreCompleto};
    }).toList();

    isLoading = false;
    notifyListeners();
  }

  void limpiar() {
    _generacion++;
    _usuariosSub?.cancel();
    _usuariosSub = null;
    _usuarios = [];
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _generacion++;
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
