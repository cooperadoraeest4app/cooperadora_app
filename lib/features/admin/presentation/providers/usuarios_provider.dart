import 'package:flutter/foundation.dart';
import '../../data/repositories/usuario_repository.dart';

class UsuariosProvider extends ChangeNotifier {
  final _repo = UsuarioRepository();

  bool isLoading = false;
  String? error;

  Stream<List<Map<String, dynamic>>> get usuarios => _repo.obtenerTodos();

  Future<void> actualizarRol(String id, String rol) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizarRol(id, rol);
    } catch (e) {
      error = 'Error al actualizar el rol.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> activarDesactivar(String id, bool activo) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _repo.activarDesactivar(id, activo);
    } catch (e) {
      error = 'Error al actualizar el estado.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
