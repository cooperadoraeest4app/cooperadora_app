import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/proyecto_repository.dart';
import '../../domain/models/proyecto.dart';
import '../../domain/models/tipo_proyecto.dart';

class ProyectoProvider extends ChangeNotifier {
  final _repo = ProyectoRepository();

  StreamSubscription<List<Proyecto>>? _enCursoSub;
  StreamSubscription<List<Proyecto>>? _planificadosSub;
  StreamSubscription<List<Proyecto>>? _finalizadosSub;
  StreamSubscription<List<TipoProyecto>>? _tiposSub;

  List<Proyecto> enCurso = [];
  List<Proyecto> planificados = [];
  List<Proyecto> finalizados = [];
  List<TipoProyecto> tipos = [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  ProyectoProvider() {
    _enCursoSub = _repo.obtenerPorEstado('en_curso').listen(
      (list) {
        enCurso = list;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );
    _planificadosSub = _repo.obtenerPorEstado('planificado').listen(
      (list) {
        planificados = list;
        notifyListeners();
      },
    );
    _finalizadosSub = _repo.obtenerPorEstado('finalizado').listen(
      (list) {
        finalizados = list;
        notifyListeners();
      },
    );
    _tiposSub = _repo.obtenerTipos().listen(
      (list) {
        tipos = list;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        notifyListeners();
      },
    );
    _repo.inicializarTiposDefault();
  }

  @override
  void dispose() {
    _enCursoSub?.cancel();
    _planificadosSub?.cancel();
    _finalizadosSub?.cancel();
    _tiposSub?.cancel();
    super.dispose();
  }

  String nombreTipo(String tipoId) {
    try {
      return tipos.firstWhere((t) => t.id == tipoId).nombre;
    } catch (_) {
      return '';
    }
  }

  Proyecto? obtenerPorId(String id) {
    final todos = [...enCurso, ...planificados, ...finalizados];
    try {
      return todos.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Proyecto> proyectosPorEstado(String estado) => switch (estado) {
        'en_curso' => enCurso,
        'planificado' => planificados,
        _ => finalizados,
      };

  Future<void> agregar(Proyecto p) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.agregar(p);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> actualizar(Proyecto p) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizar(p);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> eliminar(String id) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.eliminar(id);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
