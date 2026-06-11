import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/cuota_repository.dart';
import '../../domain/models/cuota.dart';
import '../../domain/models/tarifa_cuota.dart';
import '../../domain/models/tipo_cuota.dart';

class CuotaProvider extends ChangeNotifier {
  final _repo = CuotaRepository();

  StreamSubscription<List<TipoCuota>>? _tiposSub;
  StreamSubscription<List<TarifaCuota>>? _tarifasSub;

  List<TipoCuota> tiposCuota = [];
  List<TarifaCuota> tarifas = [];
  bool isSaving = false;
  String? error;

  CuotaProvider() {
    _tiposSub = _repo.obtenerTiposCuota().listen(
      (list) {
        tiposCuota = list;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        notifyListeners();
      },
    );
    _tarifasSub = _repo.obtenerTarifas().listen(
      (list) {
        tarifas = list;
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
    _tiposSub?.cancel();
    _tarifasSub?.cancel();
    super.dispose();
  }

  String nombreTipoCuota(String tipoCuotaId) {
    try {
      return tiposCuota.firstWhere((t) => t.id == tipoCuotaId).nombre;
    } catch (_) {
      return '';
    }
  }

  CuotaRepository get repo => _repo;

  Future<TarifaCuota?> obtenerTarifaVigente(String tipoCuotaId) =>
      _repo.obtenerTarifaVigente(tipoCuotaId);

  Future<void> registrarPago(Cuota cuota) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.registrarPago(cuota);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> actualizarTarifa(TarifaCuota tarifa) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizarTarifa(tarifa);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
