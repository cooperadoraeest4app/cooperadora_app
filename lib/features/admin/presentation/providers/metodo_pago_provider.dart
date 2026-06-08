import 'package:flutter/foundation.dart';
import '../../data/repositories/metodo_pago_repository.dart';

class MetodoPagoProvider extends ChangeNotifier {
  final _repo = MetodoPagoRepository();

  bool isLoading = false;
  bool isSaving = false;
  String? error;

  Stream<List<Map<String, dynamic>>> get metodosPago => _repo.obtenerTodos();

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
    isLoading = true;
    notifyListeners();
    try {
      await _repo.crearLote(_kDefaultMetodos);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
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
