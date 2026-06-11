import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/socio_repository.dart';
import '../../domain/models/socio.dart';
import '../../domain/models/tipo_socio.dart';

class SocioProvider extends ChangeNotifier {
  final _repo = SocioRepository();

  StreamSubscription<List<Socio>>? _todosSub;
  StreamSubscription<List<TipoSocio>>? _tiposSub;

  List<Socio> todos = [];
  List<TipoSocio> tipos = [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  SocioProvider() {
    _todosSub = _repo.obtenerTodos().listen(
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
    _repo.inicializarDatosDefault();
  }

  @override
  void dispose() {
    _todosSub?.cancel();
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

  TipoSocio? tipoById(String tipoId) {
    try {
      return tipos.firstWhere((t) => t.id == tipoId);
    } catch (_) {
      return null;
    }
  }

  SocioRepository get repo => _repo;

  Future<void> agregar(Socio socio) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.agregar(socio);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> actualizar(Socio socio) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizar(socio);
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
