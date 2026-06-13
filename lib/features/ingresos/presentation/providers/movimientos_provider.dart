import 'package:flutter/foundation.dart';
import '../../data/repositories/ingreso_repository.dart';
import '../../domain/models/ingreso.dart';
import '../../../gastos/data/repositories/gasto_repository.dart';
import '../../../gastos/domain/models/gasto.dart';

class MovimientosProvider extends ChangeNotifier {
  final _ingresoRepo = IngresoRepository();
  final _gastoRepo = GastoRepository();

  bool isLoading = false;
  String? error;

  Stream<List<Ingreso>> get ingresos => _ingresoRepo.obtenerTodos();
  Stream<List<Gasto>> get gastos => _gastoRepo.obtenerTodos();

  Future<void> agregarIngreso(Ingreso ingreso) async {
    _setLoading(true);
    try {
      await _ingresoRepo.agregar(ingreso);
    } catch (e) {
      error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> agregarGasto(Gasto gasto) async {
    _setLoading(true);
    try {
      await _gastoRepo.agregar(gasto);
    } catch (e) {
      error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> actualizarIngreso(Ingreso ingreso) async {
    _setLoading(true);
    try {
      await _ingresoRepo.actualizar(ingreso);
    } catch (e) {
      error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> actualizarGasto(Gasto gasto) async {
    _setLoading(true);
    try {
      await _gastoRepo.actualizar(gasto);
    } catch (e) {
      error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> eliminarIngreso(String id) async {
    _setLoading(true);
    try {
      await _ingresoRepo.eliminar(id);
    } catch (e) {
      error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> eliminarGasto(String id) async {
    _setLoading(true);
    try {
      await _gastoRepo.eliminar(id);
    } catch (e) {
      error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void limpiarError() {
    error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
