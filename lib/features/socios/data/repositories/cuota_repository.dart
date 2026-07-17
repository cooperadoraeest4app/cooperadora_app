import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/services/log_cambio_service.dart';
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

  Stream<List<Cuota>> obtenerPorTipo(String tipoCuotaId) {
    return _cuotasCol
        .where('tipoCuotaId', isEqualTo: tipoCuotaId)
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

  Future<void> registrarPago(Cuota cuota) async {
    final ref = await _cuotasCol.add(cuota.toMap());
    await LogCambioService().registrar(
      entidadTipo: 'cuota',
      entidadId: ref.id,
      usuarioId: cuota.usuarioId,
      accion: 'creacion',
      nuevo: cuota.toMap(),
    );
  }

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
    final ahora = DateTime.now();
    final mesActual = DateTime(ahora.year, ahora.month);

    // Resolución de tipos anuales (una sola query para todos)
    final tiposSnap = await _tiposCuotaCol.get();
    final tiposAnuales = tiposSnap.docs
        .where((d) =>
            (d.data()['nombre'] as String? ?? '')
                .toLowerCase()
                .contains('anual'))
        .map((d) => d.id)
        .toSet();

    final cuotasSnap =
        await _cuotasCol.where('socioId', isEqualTo: socioId).get();

    for (final doc in cuotasSnap.docs) {
      final data = doc.data();
      final tipoCuotaId = data['tipoCuotaId'] as String? ?? '';
      final fechaPagoRaw = data['fechaPago'];
      if (fechaPagoRaw == null) continue;
      final fechaPago = (fechaPagoRaw as Timestamp).toDate();
      final periodo = data['periodo'] as String?;

      if (tiposAnuales.contains(tipoCuotaId)) {
        // Cuota anual: cubre 12 meses desde el mes de pago
        final mesInicio = DateTime(fechaPago.year, fechaPago.month);
        final mesFin = DateTime(fechaPago.year + 1, fechaPago.month);
        if (!mesActual.isBefore(mesInicio) && mesActual.isBefore(mesFin)) {
          return true;
        }
      } else {
        // Cuota mensual: el período debe coincidir con el mes actual
        if (periodo != null) {
          final partes = periodo.split('/');
          if (partes.length == 2) {
            final mes = int.tryParse(partes[0]) ?? 0;
            final anio = int.tryParse(partes[1]) ?? 0;
            if (mes == ahora.month && anio == ahora.year) return true;
          }
        }
      }
    }

    return false;
  }

  Future<Map<String, dynamic>> calcularDeudaSocio(
      String socioId, DateTime fechaIngreso) async {
    try {
      final ahora = DateTime.now();
      final mesActual = DateTime(ahora.year, ahora.month);
      final mesIngreso = DateTime(fechaIngreso.year, fechaIngreso.month);

      final cuotasPagadasSnap = await _cuotasCol
          .where('socioId', isEqualTo: socioId)
          .where('estado', isEqualTo: 'pagada')
          .get();

      final tarifasSnap = await _tarifasCol.orderBy('vigenciaDesde').get();

      if (tarifasSnap.docs.isEmpty) {
        return {
          'deudaTotal': 0.0,
          'cuotasAdeudadas': 0,
          'estaAlDia': false,
          'sinTarifa': true,
        };
      }

      final mesesCubiertos = <String>{};
      for (final doc in cuotasPagadasSnap.docs) {
        final data = doc.data();
        final tipoCuota = data['tipoCuota'] as String? ?? 'mensual';

        if (tipoCuota == 'anual') {
          final fechaPago = (data['fechaPago'] as Timestamp).toDate();
          for (var i = 0; i < 12; i++) {
            final m = DateTime(fechaPago.year, fechaPago.month + i);
            mesesCubiertos
                .add('${m.month.toString().padLeft(2, '0')}/${m.year}');
          }
        } else {
          final periodo = data['periodo'] as String? ?? '';
          if (periodo.isNotEmpty) mesesCubiertos.add(periodo);
        }
      }

      double deudaTotal = 0.0;
      int cuotasAdeudadas = 0;
      var mes = mesIngreso;

      while (!mes.isAfter(mesActual)) {
        final periodoStr =
            '${mes.month.toString().padLeft(2, '0')}/${mes.year}';
        if (!mesesCubiertos.contains(periodoStr)) {
          final monto = _tarifaParaMes(tarifasSnap.docs, mes);
          if (monto != null) {
            deudaTotal += monto;
            cuotasAdeudadas++;
          }
        }
        mes = DateTime(mes.year, mes.month + 1);
      }

      return {
        'deudaTotal': deudaTotal,
        'cuotasAdeudadas': cuotasAdeudadas,
        'estaAlDia': cuotasAdeudadas == 0,
      };
    } catch (e) {
      // ignore: avoid_print
      print('[calcularDeudaSocio] ERROR socioId=$socioId: $e');
      return {
        'deudaTotal': 0.0,
        'cuotasAdeudadas': 0,
        'estaAlDia': false,
        'error': true,
      };
    }
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
