import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/rubro_repository.dart';
import '../../domain/models/rubro.dart';

class RubroProvider extends ChangeNotifier {
  final _repo = RubroRepository();
  StreamSubscription<List<Rubro>>? _sub;

  List<Rubro> _rubros = [];
  bool _cargado = false;
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  bool get cargado => _cargado;

  RubroProvider() {
    _sub = _repo.obtenerTodos().listen(
      (lista) {
        debugPrint('[RubroProvider] documentos: ${lista.length}');
        _rubros = lista;
        _cargado = true;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[RubroProvider] ERROR: $e');
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

  List<Rubro> get rubros => _rubros;

  List<Rubro> obtenerActivosPorTipo(String tipo) =>
      _rubros.where((r) => r.tipo == tipo && r.activo).toList();

  Future<void> inicializarSiVacio() async {
    try {
      await _repo.inicializarDatosDefault();
    } catch (e) {
      debugPrint('[RubroProvider] init error: $e');
    }
  }

  Future<void> crear(Map<String, dynamic> datos) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.crear(datos);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> actualizar(String id, Map<String, dynamic> datos) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizar(id, datos);
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

  Future<bool> tieneCategorias(String rubroId) =>
      _repo.tieneCategorias(rubroId);
}
