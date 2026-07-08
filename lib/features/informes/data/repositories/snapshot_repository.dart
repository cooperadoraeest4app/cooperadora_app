import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/balance_snapshot.dart';

class SnapshotRepository {
  final _col = FirebaseFirestore.instance.collection('balance_snapshots');

  /// Snapshots para un período exacto (por fechaDesde + fechaHasta).
  Future<List<BalanceSnapshot>> obtenerParaPeriodo(
      DateTime desde, DateTime hasta) async {
    final desdeTs = Timestamp.fromDate(DateTime(desde.year, desde.month, desde.day));
    final hastaTs = Timestamp.fromDate(DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59));

    print('[SnapshotRepo] Consultando desde: $desdeTs hasta: $hastaTs');

    try {
      final snap = await _col
          .where('fechaDesde', isEqualTo: desdeTs)
          .where('fechaHasta', isEqualTo: hastaTs)
          .orderBy('version', descending: true)
          .get();
      print('[SnapshotRepo] Resultados: ${snap.docs.length}');
      return snap.docs.map((d) => BalanceSnapshot.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      print('[SnapshotRepo] ERROR: $e');
      rethrow;
    }
  }

  /// Versión más alta existente para el período. Retorna 0 si no hay ninguna.
  Future<int> ultimaVersion(DateTime desde, DateTime hasta) async {
    final lista = await obtenerParaPeriodo(desde, hasta);
    if (lista.isEmpty) return 0;
    return lista.first.version;
  }

  /// Guarda un nuevo snapshot incrementando la versión automáticamente.
  Future<void> cerrar(BalanceSnapshot snapshot) async {
    final nuevaVersion =
        await ultimaVersion(snapshot.fechaDesde, snapshot.fechaHasta) + 1;
    final data = snapshot.toMap();
    data['version'] = nuevaVersion;
    await _col.add(data);
  }

  Stream<List<BalanceSnapshot>> obtenerTodos() {
    return _col
        .orderBy('fechaCierre', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => BalanceSnapshot.fromMap(d.data(), d.id)).toList());
  }
}
