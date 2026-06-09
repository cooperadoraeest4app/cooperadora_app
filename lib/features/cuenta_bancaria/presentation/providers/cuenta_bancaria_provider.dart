import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/cuenta_bancaria_repository.dart';
import '../../domain/models/cuenta_bancaria.dart';
import '../../domain/models/movimiento_bancario.dart';

class CuentaBancariaProvider extends ChangeNotifier {
  final _repo = CuentaBancariaRepository();
  StreamSubscription<CuentaBancaria?>? _cuentaSub;
  StreamSubscription<List<MovimientoBancario>>? _movimientosSub;

  CuentaBancaria? cuenta;
  List<MovimientoBancario> movimientos = [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  CuentaBancariaProvider() {
    _cuentaSub = _repo.obtener().listen(
      (c) {
        cuenta = c;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );
    _movimientosSub = _repo.obtenerMovimientos().listen(
      (list) {
        movimientos = list;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _cuentaSub?.cancel();
    _movimientosSub?.cancel();
    super.dispose();
  }

  Future<void> crearCuenta(CuentaBancaria c) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.crear(c);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> actualizarSaldo(
    double nuevoSaldo,
    String usuarioId, {
    String? observaciones,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizarSaldo(nuevoSaldo, usuarioId,
          observaciones: observaciones);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> actualizarSaldoConResumen(
    double nuevoSaldo,
    String usuarioId,
    String periodo,
    String archivoPlaceholder, {
    String? observaciones,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizarSaldoConResumen(
        nuevoSaldo,
        usuarioId,
        periodo,
        archivoPlaceholder,
        observaciones: observaciones,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> agregarMovimiento(MovimientoBancario movimiento) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.agregarMovimiento(movimiento);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> eliminarMovimiento(String id) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.eliminarMovimiento(id);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
