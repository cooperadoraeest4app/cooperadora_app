import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/metodo_pago_repository.dart';

class MetodoPagoProvider extends ChangeNotifier {
  final _repo = MetodoPagoRepository();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  List<Map<String, dynamic>> _metodos = [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  MetodoPagoProvider() {
    _sub = _repo.obtenerTodos().listen(
      (lista) {
        _metodos = lista;
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

  List<Map<String, dynamic>> get metodosPago => _metodos;

  List<Map<String, dynamic>> obtenerActivos() {
    return _metodos.where((m) => m['activo'] as bool? ?? false).toList();
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

  Future<void> inicializarDatosDefault() async {
    if (!(await _repo.estaVacia())) return;
    try {
      await _repo.crearLote(_kDefaultMetodos);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  static const _kDefaultMetodos = <Map<String, dynamic>>[
    {'nombre': 'Efectivo', 'orden': 1, 'activo': true},
    {'nombre': 'Transferencia bancaria', 'orden': 2, 'activo': true},
    {'nombre': 'Débito', 'orden': 3, 'activo': true},
    {'nombre': 'Crédito', 'orden': 4, 'activo': true},
    {'nombre': 'Cheque', 'orden': 5, 'activo': true},
  ];
}
