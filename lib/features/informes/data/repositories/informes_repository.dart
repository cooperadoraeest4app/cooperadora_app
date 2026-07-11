import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/balance_resultado.dart';
import '../../../admin/domain/models/rubro.dart';

class InformesRepository {
  final _ingresos = FirebaseFirestore.instance.collection('ingresos');
  final _gastos = FirebaseFirestore.instance.collection('gastos');
  final _cuentaBancaria =
      FirebaseFirestore.instance.collection('cuenta_bancaria');

  Future<BalanceResultado> calcular({
    required DateTime fechaDesde,
    required DateTime fechaHasta,
    required List<Map<String, dynamic>> categorias,
    required List<Rubro> rubros,
    required double saldoEjercicioAnterior,
  }) async {
    final desde = Timestamp.fromDate(
        DateTime(fechaDesde.year, fechaDesde.month, fechaDesde.day));
    final hasta = Timestamp.fromDate(
        DateTime(fechaHasta.year, fechaHasta.month, fechaHasta.day, 23, 59, 59));

    final ingSnap = await _ingresos
        .where('fecha', isGreaterThanOrEqualTo: desde)
        .where('fecha', isLessThanOrEqualTo: hasta)
        .get();
    final gasSnap = await _gastos
        .where('fecha', isGreaterThanOrEqualTo: desde)
        .where('fecha', isLessThanOrEqualTo: hasta)
        .get();

    final Map<String, String> catToRubro = {
      for (final c in categorias)
        if (c['id'] != null && c['rubroId'] != null)
          c['id'] as String: c['rubroId'] as String,
    };
    final Map<String, String> catNombre = {
      for (final c in categorias)
        if (c['id'] != null) c['id'] as String: c['nombre'] as String? ?? '',
    };
    // Agrupa ingresos por rubroId → categoriaId
    final Map<String, Map<String, _Acum>> entGrupo = {};
    for (final doc in ingSnap.docs) {
      final data = doc.data();
      final catId = data['categoriaId'] as String? ?? '';
      final rubroId = catToRubro[catId] ?? '_sin_rubro';
      final cNombre = catNombre[catId] ?? catId;
      final monto = (data['monto'] as num? ?? 0).toDouble();
      entGrupo.putIfAbsent(rubroId, () => {});
      entGrupo[rubroId]!.putIfAbsent(catId, () => _Acum(cNombre));
      entGrupo[rubroId]![catId]!.add(monto);
    }

    // Agrupa gastos por rubroId → categoriaId + recolecta detalle individual
    final Map<String, Map<String, _Acum>> salGrupo = {};
    final salidasDetalle = <MovimientoBalance>[];
    for (final doc in gasSnap.docs) {
      final data = doc.data();
      final catId = data['categoriaId'] as String? ?? '';
      final rubroId = catToRubro[catId] ?? '_sin_rubro';
      final cNombre = catNombre[catId] ?? catId;
      final monto = (data['monto'] as num? ?? 0).toDouble();
      salGrupo.putIfAbsent(rubroId, () => {});
      salGrupo[rubroId]!.putIfAbsent(catId, () => _Acum(cNombre));
      salGrupo[rubroId]![catId]!.add(monto);
      final ts = data['fecha'];
      salidasDetalle.add(MovimientoBalance(
        fecha: ts is Timestamp ? ts.toDate() : DateTime.now(),
        nroComprobante: data['nroComprobante'] as String?,
        descripcion: data['descripcion'] as String? ?? '',
        monto: monto,
        rubroId: rubroId,
      ));
    }
    salidasDetalle.sort((a, b) => a.fecha.compareTo(b.fecha));

    // Ordena rubros según el orden definido en la lista `rubros`
    List<RubroBalance> construir(Map<String, Map<String, _Acum>> grupo) {
      final result = <RubroBalance>[];
      // Primero los rubros que existen en el catálogo (en orden)
      for (final r in rubros) {
        if (!grupo.containsKey(r.id)) continue;
        final cats = grupo[r.id]!.entries
            .map((e) => CategoriaBalance(
                  categoriaId: e.key,
                  nombre: e.value.nombre,
                  total: e.value.total,
                  cantidad: e.value.cantidad,
                ))
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));
        result.add(RubroBalance(
          rubroId: r.id,
          nombre: r.nombre,
          total: cats.fold(0, (s, c) => s + c.total),
          categorias: cats,
        ));
      }
      // Al final, categorías sin rubro
      if (grupo.containsKey('_sin_rubro')) {
        final cats = grupo['_sin_rubro']!.entries
            .map((e) => CategoriaBalance(
                  categoriaId: e.key,
                  nombre: e.value.nombre,
                  total: e.value.total,
                  cantidad: e.value.cantidad,
                ))
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));
        result.add(RubroBalance(
          rubroId: '_sin_rubro',
          nombre: 'Sin rubro',
          total: cats.fold(0, (s, c) => s + c.total),
          categorias: cats,
        ));
      }
      return result;
    }

    final entradas = construir(entGrupo);
    final salidas = construir(salGrupo);
    final totalEntradas = entradas.fold(0.0, (s, r) => s + r.total);
    final totalSalidas = salidas.fold(0.0, (s, r) => s + r.total);
    final totalGeneral = totalEntradas + saldoEjercicioAnterior;

    // Saldo Caja Chica: último movimiento con fechaCreacion <= hasta
    final (saldoCaja, fechaCaja) = await _ultimoSaldoCajaChica(hasta);

    // Saldo Banco: último movimiento con fechaCreacion <= hasta
    final (saldoBanco, fechaBanco) = await _ultimoSaldoBanco(hasta);
    final bancoExacto = fechaBanco != null &&
        fechaBanco.year == fechaHasta.year &&
        fechaBanco.month == fechaHasta.month &&
        fechaBanco.day == fechaHasta.day;

    return BalanceResultado(
      fechaDesde: fechaDesde,
      fechaHasta: fechaHasta,
      entradas: entradas,
      salidas: salidas,
      totalEntradas: totalEntradas,
      totalSalidas: totalSalidas,
      saldoEjercicioAnterior: saldoEjercicioAnterior,
      totalGeneral: totalGeneral,
      saldoProximoEjercicio: totalGeneral - totalSalidas,
      saldoCajaChica: saldoCaja,
      fechaSaldoCajaChica: fechaCaja,
      saldoBanco: saldoBanco,
      fechaSaldoBanco: fechaBanco,
      saldoBancoExacto: bancoExacto,
      salidasDetalle: salidasDetalle,
    );
  }

  Future<(double?, DateTime?)> _ultimoSaldoCajaChica(
      Timestamp hasta) async {
    try {
      final snap = await _cuentaBancaria
          .doc('caja_chica')
          .collection('movimientos')
          .where('fechaCreacion', isLessThanOrEqualTo: hasta)
          .orderBy('fechaCreacion', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return (null, null);
      final data = snap.docs.first.data();
      final saldo = (data['saldoNuevo'] as num?)?.toDouble();
      final fecha =
          data['fechaCreacion'] is Timestamp
              ? (data['fechaCreacion'] as Timestamp).toDate()
              : null;
      return (saldo, fecha);
    } catch (_) {
      return (null, null);
    }
  }

  Future<(double?, DateTime?)> _ultimoSaldoBanco(Timestamp hasta) async {
    try {
      final snap = await _cuentaBancaria
          .doc('cuenta_principal')
          .collection('movimientos')
          .where('fechaCreacion', isLessThanOrEqualTo: hasta)
          .orderBy('fechaCreacion', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return (null, null);
      final data = snap.docs.first.data();
      final saldo = (data['saldoNuevo'] as num?)?.toDouble();
      final fecha =
          data['fechaCreacion'] is Timestamp
              ? (data['fechaCreacion'] as Timestamp).toDate()
              : null;
      return (saldo, fecha);
    } catch (_) {
      return (null, null);
    }
  }

  /// Datos mensuales para gráficos — carga hasta 12 meses hacia atrás desde fechaHasta.
  Future<List<MesBalance>> calcularEvolucionMensual({
    required DateTime fechaHasta,
    required List<Map<String, dynamic>> categorias,
  }) async {
    final result = <MesBalance>[];
    DateTime cursor = DateTime(fechaHasta.year, fechaHasta.month);
    for (int i = 0; i < 12; i++) {
      final desde = Timestamp.fromDate(cursor);
      final hasta = Timestamp.fromDate(
          DateTime(cursor.year, cursor.month + 1, 0, 23, 59, 59));
      final ingSnap = await _ingresos
          .where('fecha', isGreaterThanOrEqualTo: desde)
          .where('fecha', isLessThanOrEqualTo: hasta)
          .get();
      final gasSnap = await _gastos
          .where('fecha', isGreaterThanOrEqualTo: desde)
          .where('fecha', isLessThanOrEqualTo: hasta)
          .get();
      final entradas =
          ingSnap.docs.fold(0.0, (s, d) => s + ((d['monto'] as num?)?.toDouble() ?? 0));
      final salidas =
          gasSnap.docs.fold(0.0, (s, d) => s + ((d['monto'] as num?)?.toDouble() ?? 0));
      result.insert(0, MesBalance(anio: cursor.year, mes: cursor.month, entradas: entradas, salidas: salidas));
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    return result;
  }
}

class _Acum {
  final String nombre;
  double total = 0;
  int cantidad = 0;
  _Acum(this.nombre);
  void add(double v) { total += v; cantidad++; }
}
