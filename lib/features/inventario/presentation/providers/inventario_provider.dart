import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/inventario_repository.dart';
import '../../domain/models/bien_inventario.dart';

class InventarioProvider extends ChangeNotifier {
  final _repo = InventarioRepository();
  StreamSubscription<List<BienInventario>>? _sub;

  List<BienInventario> todos = [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  InventarioProvider() {
    _sub = _repo.obtenerTodos().listen(
      (list) {
        todos = list;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<String?> agregar(BienInventario bien) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      final id = await _repo.agregar(bien);
      return id;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> actualizar(BienInventario bien, String usuarioId) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizar(bien, usuarioId);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> registrarBaja(
    String id,
    Map<String, dynamic> datosBaja,
    String usuarioId,
  ) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.registrarBaja(id, datosBaja, usuarioId);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
