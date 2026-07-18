import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pago_cuota.dart';

class MesCuota {
  final DateTime mes;
  final double tarifa;
  final double pagado;
  final String estado; // 'cubierto' / 'parcial' / 'sin_cubrir' / 'sin_tarifa'

  const MesCuota({
    required this.mes,
    required this.tarifa,
    required this.pagado,
    required this.estado,
  });
}

class CuotaEstado {
  final double totalPagado;
  final double totalRequerido;
  final double deuda;
  final double creditoAFavor;
  final bool estaAlDia;
  final List<MesCuota> mesesCubiertos;
  final List<PagoCuota> pagos;

  const CuotaEstado({
    required this.totalPagado,
    required this.totalRequerido,
    required this.deuda,
    required this.creditoAFavor,
    required this.estaAlDia,
    required this.mesesCubiertos,
    required this.pagos,
  });
}

class CuotaCalculoService {
  Future<CuotaEstado> calcularEstado({
    required String socioId,
    required DateTime fechaIngreso,
  }) async {
    final ahora = DateTime.now();
    final mesActual = DateTime(ahora.year, ahora.month);
    final mesIngreso = DateTime(fechaIngreso.year, fechaIngreso.month);

    final pagosSnap = await FirebaseFirestore.instance
        .collection('pagos_cuota')
        .where('socioId', isEqualTo: socioId)
        .orderBy('fechaPago')
        .get();

    final pagos = pagosSnap.docs
        .map((d) => PagoCuota.fromMap(d.data(), d.id))
        .toList();

    final tarifasSnap = await FirebaseFirestore.instance
        .collection('tarifas_cuota')
        .orderBy('vigenciaDesde')
        .get();

    final totalPagado = pagos.fold(0.0, (acc, p) => acc + p.monto);

    final mesesCubiertos = <MesCuota>[];
    double saldoDisponible = totalPagado;
    var mes = mesIngreso;

    while (!mes.isAfter(mesActual)) {
      final tarifa = _tarifaParaMes(tarifasSnap.docs, mes);
      final tarifaMes = tarifa ?? 0.0;

      MesCuota mesCuota;
      if (tarifaMes == 0) {
        mesCuota = MesCuota(
            mes: mes, tarifa: 0, pagado: 0, estado: 'sin_tarifa');
      } else if (saldoDisponible >= tarifaMes) {
        saldoDisponible -= tarifaMes;
        mesCuota = MesCuota(
            mes: mes,
            tarifa: tarifaMes,
            pagado: tarifaMes,
            estado: 'cubierto');
      } else if (saldoDisponible > 0) {
        mesCuota = MesCuota(
            mes: mes,
            tarifa: tarifaMes,
            pagado: saldoDisponible,
            estado: 'parcial');
        saldoDisponible = 0;
      } else {
        mesCuota = MesCuota(
            mes: mes, tarifa: tarifaMes, pagado: 0, estado: 'sin_cubrir');
      }

      mesesCubiertos.add(mesCuota);
      mes = DateTime(mes.year, mes.month + 1);
    }

    final totalRequerido =
        mesesCubiertos.fold(0.0, (acc, m) => acc + m.tarifa);
    final rawDeuda = totalRequerido - totalPagado;
    final deuda = rawDeuda > 0 ? rawDeuda : 0.0;
    final creditoAFavor = saldoDisponible;

    return CuotaEstado(
      totalPagado: totalPagado,
      totalRequerido: totalRequerido,
      deuda: deuda,
      creditoAFavor: creditoAFavor,
      estaAlDia: deuda <= 0,
      mesesCubiertos: mesesCubiertos,
      pagos: pagos.reversed.toList(), // most recent first for display
    );
  }

  double? _tarifaParaMes(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> tarifas,
      DateTime mes) {
    double? resultado;
    for (final doc in tarifas) {
      final data = doc.data();
      final vigenciaDesde = (data['vigenciaDesde'] as Timestamp).toDate();
      final vigencia = DateTime(vigenciaDesde.year, vigenciaDesde.month);
      if (!vigencia.isAfter(mes)) {
        resultado = (data['monto'] as num).toDouble();
      }
    }
    return resultado;
  }
}
