import 'package:flutter/foundation.dart';
import '../../../admin/domain/models/rubro.dart';
import '../../data/repositories/informes_repository.dart';
import '../../data/repositories/snapshot_repository.dart';
import '../../domain/models/balance_resultado.dart';
import '../../domain/models/balance_snapshot.dart';
import '../../../../shared/services/comision_service.dart';

enum TipoRango { mensual, anual, libre }

class InformesProvider extends ChangeNotifier {
  final _repo = InformesRepository();
  final _snapRepo = SnapshotRepository();

  // ── Estado de cálculo ────────────────────────────────────────────────────
  BalanceResultado? resultado;
  List<MesBalance> evolucion = [];
  bool isCalculating = false;
  bool isCalculatingEvolucion = false;
  String? error;

  // ── Configuración del período ────────────────────────────────────────────
  TipoRango tipoRango = TipoRango.mensual;
  late DateTime _fechaDesde;
  late DateTime _fechaHasta;

  // Saldo del ejercicio anterior (ajustable manualmente)
  double saldoEjercicioAnterior = 0.0;

  // ── Snapshots del período activo ─────────────────────────────────────────
  List<BalanceSnapshot> snapshotsPeriodo = [];
  bool isLoadingSnapshots = false;

  // ── Permiso para cerrar balance ──────────────────────────────────────────
  bool puedeCerrarBalance = false;

  InformesProvider() {
    final now = DateTime.now();
    _fechaDesde = DateTime(now.year, now.month, 1);
    _fechaHasta = DateTime(now.year, now.month + 1, 0); // último día del mes
  }

  DateTime get fechaDesde => _fechaDesde;
  DateTime get fechaHasta => _fechaHasta;

  void setRangoMensual(int anio, int mes) {
    tipoRango = TipoRango.mensual;
    _fechaDesde = DateTime(anio, mes, 1);
    _fechaHasta = DateTime(anio, mes + 1, 0);
    resultado = null;
    notifyListeners();
  }

  void setRangoAnual(int anio) {
    tipoRango = TipoRango.anual;
    _fechaDesde = DateTime(anio, 1, 1);
    _fechaHasta = DateTime(anio, 12, 31);
    resultado = null;
    notifyListeners();
  }

  void setRangoLibre(DateTime desde, DateTime hasta) {
    tipoRango = TipoRango.libre;
    _fechaDesde = desde;
    _fechaHasta = hasta;
    resultado = null;
    notifyListeners();
  }

  void setSaldoAnterior(double v) {
    saldoEjercicioAnterior = v;
    // Recalcula los totales derivados si ya hay un resultado
    if (resultado != null) {
      final r = resultado!;
      final total = r.totalEntradas + v;
      resultado = BalanceResultado(
        fechaDesde: r.fechaDesde,
        fechaHasta: r.fechaHasta,
        entradas: r.entradas,
        salidas: r.salidas,
        totalEntradas: r.totalEntradas,
        totalSalidas: r.totalSalidas,
        saldoEjercicioAnterior: v,
        totalGeneral: total,
        saldoProximoEjercicio: total - r.totalSalidas,
        saldoCajaChica: r.saldoCajaChica,
        fechaSaldoCajaChica: r.fechaSaldoCajaChica,
        saldoBanco: r.saldoBanco,
        fechaSaldoBanco: r.fechaSaldoBanco,
        saldoBancoExacto: r.saldoBancoExacto,
      );
    }
    notifyListeners();
  }

  Future<void> verificarPermiso(String? uid) async {
    puedeCerrarBalance = await ComisionService.esMiembroComisionDirectiva(uid);
    notifyListeners();
  }

  Future<void> calcular(
    DateTime desde,
    DateTime hasta, {
    required List<Map<String, dynamic>> categorias,
    required List<Rubro> rubros,
  }) async {
    _fechaDesde = desde;
    _fechaHasta = hasta;
    tipoRango = TipoRango.libre;
    isCalculating = true;
    error = null;
    notifyListeners();
    try {
      resultado = await _repo.calcular(
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
        categorias: categorias,
        rubros: rubros,
        saldoEjercicioAnterior: saldoEjercicioAnterior,
      );
      await cargarSnapshotsPeriodo();
    } catch (e) {
      error = e.toString();
    } finally {
      isCalculating = false;
      notifyListeners();
    }
  }

  void limpiarResultado() {
    resultado = null;
    error = null;
    snapshotsPeriodo = [];
    notifyListeners();
  }

  Future<void> calcularEvolucion({
    required List<Map<String, dynamic>> categorias,
    DateTime? hasta,
  }) async {
    isCalculatingEvolucion = true;
    notifyListeners();
    try {
      evolucion = await _repo.calcularEvolucionMensual(
        fechaHasta: hasta ?? _fechaHasta,
        categorias: categorias,
      );
    } catch (_) {
      evolucion = [];
    } finally {
      isCalculatingEvolucion = false;
      notifyListeners();
    }
  }

  Future<void> cargarSnapshotsPeriodo() async {
    isLoadingSnapshots = true;
    notifyListeners();
    try {
      snapshotsPeriodo =
          await _snapRepo.obtenerParaPeriodo(_fechaDesde, _fechaHasta);
    } catch (_) {
      snapshotsPeriodo = [];
    } finally {
      isLoadingSnapshots = false;
      notifyListeners();
    }
  }

  Future<void> cerrarBalance({
    required String usuarioId,
    required String tipo,
    Map<String, dynamic>? advertenciaSaldoBanco,
  }) async {
    final r = resultado;
    if (r == null) return;
    isCalculating = true;
    error = null;
    notifyListeners();
    try {
      final snapshot = BalanceSnapshot(
        id: '',
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
        tipo: tipo,
        version: 1,
        totalEntradas: r.totalEntradas,
        totalSalidas: r.totalSalidas,
        saldoEjercicioAnterior: r.saldoEjercicioAnterior,
        totalGeneral: r.totalGeneral,
        saldoProximoEjercicio: r.saldoProximoEjercicio,
        saldoCajaChica: r.saldoCajaChica,
        saldoBanco: r.saldoBanco,
        fechaSaldoBanco: r.fechaSaldoBanco,
        saldoBancoExacto: r.saldoBancoExacto,
        usuarioId: usuarioId,
        fechaCierre: DateTime.now(),
        advertenciaSaldoBanco: advertenciaSaldoBanco,
      );
      await _snapRepo.cerrar(snapshot);
      await cargarSnapshotsPeriodo();
    } catch (e) {
      error = e.toString();
    } finally {
      isCalculating = false;
      notifyListeners();
    }
  }
}
