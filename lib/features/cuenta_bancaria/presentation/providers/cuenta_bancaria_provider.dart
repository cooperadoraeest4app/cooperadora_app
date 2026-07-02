import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/cuenta_bancaria_repository.dart';
import '../../domain/models/cuenta_bancaria.dart';
import '../../domain/models/movimiento_bancario.dart';

class CuentaBancariaProvider extends ChangeNotifier {
  final _repo = CuentaBancariaRepository();
  StreamSubscription<CuentaBancaria?>? _cuentaSub;
  StreamSubscription<List<MovimientoBancario>>? _movimientosSub;
  StreamSubscription<Map<String, dynamic>?>? _cajaChicaSub;
  StreamSubscription<List<Map<String, dynamic>>>? _movCajaChicaSub;

  CuentaBancaria? cuenta;
  List<MovimientoBancario> movimientos = [];
  Map<String, dynamic>? cajaChica;
  List<Map<String, dynamic>> movimientosCajaChica = [];
  bool isLoading = true;
  bool isSaving = false;
  String? error;

  CuentaBancariaProvider() {
    // Debug directo — sin pasar por repo
    FirebaseFirestore.instance
        .collection('movimientos_bancarios')
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .listen(
          (snap) => print('Movimientos bancarios: ${snap.docs.length}'),
          onError: (e) => print('Error movimientos_bancarios: $e'),
        );

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
        // ignore: avoid_print
        print('Movimientos recibidos: ${list.length}');
        movimientos = list;
        notifyListeners();
      },
      onError: (e) {
        // ignore: avoid_print
        print('Error stream movimientos_bancarios: $e');
        error = e.toString();
        notifyListeners();
      },
    );
    _cajaChicaSub = _repo.obtenerCajaChica().listen(
      (data) {
        cajaChica = data;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        notifyListeners();
      },
    );
    _movCajaChicaSub = _repo.obtenerMovimientosCajaChica().listen(
      (list) {
        movimientosCajaChica = list;
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
    _cuentaSub?.cancel();
    _movimientosSub?.cancel();
    _cajaChicaSub?.cancel();
    _movCajaChicaSub?.cancel();
    super.dispose();
  }

  Future<void> crearCuenta(CuentaBancaria c, String usuarioId) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.crear(c, usuarioId);
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

  Future<void> actualizarCajaChica(
    double nuevoSaldo,
    String usuarioId, {
    String? observaciones,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizarCajaChica(nuevoSaldo, usuarioId, observaciones);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> sumarACajaChica(
    double monto,
    String usuarioId,
    String descripcion,
  ) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.sumarACajaChica(monto, usuarioId, descripcion);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> descontarDeCajaChica(
    double monto,
    String usuarioId,
    String descripcion,
  ) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.descontarDeCajaChica(monto, usuarioId, descripcion);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> depositarACuentaBancaria(
    double monto,
    String usuarioId, {
    String? observaciones,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.depositarACuentaBancaria(monto, usuarioId, observaciones);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> eliminarMovimiento(String id, String usuarioId) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.eliminarMovimiento(id, usuarioId);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
