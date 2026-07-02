import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/curso_repository.dart';
import '../../domain/models/curso.dart';

class CursoProvider extends ChangeNotifier {
  final _repo = CursoRepository();
  StreamSubscription<List<Curso>>? _sub;
  StreamSubscription<List<Curso>>? _activosSub;

  List<Curso> todos = [];
  List<Curso> activos = [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  CursoProvider() {
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
    _activosSub = _repo.obtenerActivos().listen(
      (list) {
        activos = list;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _activosSub?.cancel();
    super.dispose();
  }

  Future<void> agregar(Curso curso) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.agregar(curso);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> actualizar(Curso curso) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizar(curso);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> activarDesactivar(String id, bool activo) async {
    try {
      await _repo.activarDesactivar(id, activo);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }
}
