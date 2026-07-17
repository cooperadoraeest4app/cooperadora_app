import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/socio_repository.dart';
import '../../domain/models/socio.dart';
import '../../domain/models/tipo_socio.dart';

class SocioProvider extends ChangeNotifier {
  final _repo = SocioRepository();

  StreamSubscription? _authSub;
  StreamSubscription<List<Socio>>? _todosSub;
  StreamSubscription<List<TipoSocio>>? _tiposSub;

  List<Socio> todos = [];
  List<TipoSocio> tipos = [];
  bool isLoading = false;
  bool isSaving = false;
  String? error;

  SocioProvider() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _arrancar();
      } else {
        _detener();
      }
    });
  }

  void _arrancar() {
    _todosSub?.cancel();
    _tiposSub?.cancel();
    isLoading = true;
    error = null;
    notifyListeners();

    _todosSub = _repo.obtenerTodos().listen(
      (list) {
        debugPrint('[SocioProvider] stream recibió ${list.length} socios');
        todos = list;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[SocioProvider] stream error: $e');
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

  void _detener() {
    _todosSub?.cancel();
    _tiposSub?.cancel();
    _todosSub = null;
    _tiposSub = null;
    todos = [];
    tipos = [];
    isLoading = false;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
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

  Socio? porId(String id) {
    try {
      return todos.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  SocioRepository get repo => _repo;

  Future<String?> agregar(Socio socio) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      return await _repo.agregar(socio);
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> actualizar(Socio socio, String usuarioId) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizar(socio, usuarioId);
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
