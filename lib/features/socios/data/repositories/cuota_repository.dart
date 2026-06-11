import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/cuota.dart';
import '../../domain/models/tarifa_cuota.dart';
import '../../domain/models/tipo_cuota.dart';

class CuotaRepository {
  final _cuotasCol =
      FirebaseFirestore.instance.collection('cuotas');
  final _tarifasCol =
      FirebaseFirestore.instance.collection('tarifas_cuota');
  final _tiposCuotaCol =
      FirebaseFirestore.instance.collection('tipos_cuota');

  Stream<List<Cuota>> obtenerPorSocio(String socioId) {
    return _cuotasCol
        .where('socioId', isEqualTo: socioId)
        .snapshots()
        .map((s) {
      final list =
          s.docs.map((d) => Cuota.fromMap(d.data(), d.id)).toList()
            ..sort((a, b) => b.fechaPago.compareTo(a.fechaPago));
      return list;
    });
  }

  Stream<List<Cuota>> obtenerPorPeriodo(String periodo) {
    return _cuotasCol
        .where('periodo', isEqualTo: periodo)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Cuota.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<TarifaCuota>> obtenerTarifas() {
    return _tarifasCol.snapshots().map((s) {
      final list = s.docs
          .map((d) => TarifaCuota.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) => b.vigenciaDesde.compareTo(a.vigenciaDesde));
      return list;
    });
  }

  Future<TarifaCuota?> obtenerTarifaVigente(String tipoCuotaId) async {
    final snap = await _tarifasCol
        .where('tipoCuotaId', isEqualTo: tipoCuotaId)
        .get();
    if (snap.docs.isEmpty) return null;
    final list = snap.docs
        .map((d) => TarifaCuota.fromMap(d.data(), d.id))
        .toList()
      ..sort((a, b) => b.vigenciaDesde.compareTo(a.vigenciaDesde));
    return list.first;
  }

  Future<void> registrarPago(Cuota cuota) =>
      _cuotasCol.add(cuota.toMap());

  Future<void> actualizarTarifa(TarifaCuota tarifa) {
    if (tarifa.id.isEmpty) return _tarifasCol.add(tarifa.toMap());
    return _tarifasCol.doc(tarifa.id).set(tarifa.toMap());
  }

  Stream<List<TipoCuota>> obtenerTiposCuota() {
    return _tiposCuotaCol.snapshots().map((s) {
      final list = s.docs
          .map((d) => TipoCuota.fromMap(d.data(), d.id))
          .where((t) => t.activo)
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
      return list;
    });
  }

  Future<bool> estaAlDia(String socioId) async {
    final now = DateTime.now();
    final periodo =
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
    final snap = await _cuotasCol
        .where('socioId', isEqualTo: socioId)
        .get();
    return snap.docs.any((d) => d.data()['periodo'] == periodo);
  }

  Future<void> inicializarDatosDefault() async {
    final snap = await _tiposCuotaCol.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final defaults = [
      {'nombre': 'Mensual', 'orden': 1, 'activo': true},
      {'nombre': 'Anual', 'orden': 2, 'activo': true},
    ];
    for (final d in defaults) {
      batch.set(_tiposCuotaCol.doc(), d);
    }
    await batch.commit();
  }
}
