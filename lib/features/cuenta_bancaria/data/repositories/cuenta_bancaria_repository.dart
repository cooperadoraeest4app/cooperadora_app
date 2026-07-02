import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/services/log_cambio_service.dart';
import '../../domain/models/cuenta_bancaria.dart';
import '../../domain/models/movimiento_bancario.dart';

class CuentaBancariaRepository {
  static const _docId = 'cuenta_principal';
  static const _cajaChicaId = 'caja_chica';

  final _col = FirebaseFirestore.instance.collection('cuenta_bancaria');
  final _movCol = FirebaseFirestore.instance
      .collection('cuenta_bancaria')
      .doc('cuenta_principal')
      .collection('movimientos');
  late final _cajaChicaMovCol =
      _col.doc(_cajaChicaId).collection('movimientos');

  Stream<CuentaBancaria?> obtener() {
    return _col.doc(_docId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return CuentaBancaria.fromMap(snap.data()!, snap.id);
    });
  }

  Future<void> crear(CuentaBancaria cuenta, String usuarioId) async {
    final snap = await _col.doc(_docId).get();
    final anterior = snap.exists && snap.data() != null
        ? _extractDatosCuenta(snap.data()!)
        : null;

    await _col.doc(_docId).set(cuenta.toMap());

    await LogCambioService().registrar(
      entidadTipo: 'cuenta_bancaria',
      entidadId: _docId,
      usuarioId: usuarioId,
      accion: anterior == null ? 'creacion' : 'modificacion',
      anterior: anterior,
      nuevo: _extractDatosCuenta(cuenta.toMap()),
    );
  }

  Future<void> actualizarSaldo(
    double nuevoSaldo,
    String usuarioId, {
    String? observaciones,
  }) async {
    final snap = await _col.doc(_docId).get();
    final saldoAnterior =
        (snap.data()?['saldoActual'] as num? ?? 0).toDouble();

    final batch = FirebaseFirestore.instance.batch();

    batch.update(_col.doc(_docId), {
      'saldoActual': nuevoSaldo,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });

    batch.set(_movCol.doc(), {
      'tipo': 'actualizacion_saldo',
      'saldoAnterior': saldoAnterior,
      'saldoNuevo': nuevoSaldo,
      'observaciones': observaciones,
      'usuarioId': usuarioId,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    await LogCambioService().registrar(
      entidadTipo: 'cuenta_bancaria',
      entidadId: _docId,
      usuarioId: usuarioId,
      accion: 'actualizacion_saldo',
      anterior: {'saldo': saldoAnterior},
      nuevo: {
        'saldo': nuevoSaldo,
        'observaciones': ?observaciones,
      },
    );
  }

  Future<void> actualizarSaldoConResumen(
    double nuevoSaldo,
    String usuarioId,
    String periodo,
    String archivoUrl, {
    String? observaciones,
  }) async {
    final snap = await _col.doc(_docId).get();
    final saldoAnterior =
        (snap.data()?['saldoActual'] as num? ?? 0).toDouble();

    final batch = FirebaseFirestore.instance.batch();

    batch.update(_col.doc(_docId), {
      'saldoActual': nuevoSaldo,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });

    batch.set(_movCol.doc(), {
      'tipo': 'resumen_mensual',
      'saldoAnterior': saldoAnterior,
      'saldoNuevo': nuevoSaldo,
      'periodo': periodo,
      'archivo': archivoUrl,
      'observaciones': observaciones,
      'usuarioId': usuarioId,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    await LogCambioService().registrar(
      entidadTipo: 'cuenta_bancaria',
      entidadId: _docId,
      usuarioId: usuarioId,
      accion: 'actualizacion_saldo',
      anterior: {'saldo': saldoAnterior},
      nuevo: {
        'saldo': nuevoSaldo,
        'periodo': periodo,
        if (archivoUrl.isNotEmpty) 'archivo': archivoUrl,
        'observaciones': ?observaciones,
      },
    );
  }

  Stream<List<MovimientoBancario>> obtenerMovimientos() {
    return _movCol
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => MovimientoBancario.fromMap(d.data(), d.id))
            .toList());
  }

  // ── Caja Chica ────────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>?> obtenerCajaChica() {
    return _col.doc(_cajaChicaId).snapshots().map(
          (snap) => snap.exists && snap.data() != null ? snap.data() : null,
        );
  }

  Stream<List<Map<String, dynamic>>> obtenerMovimientosCajaChica() {
    return _cajaChicaMovCol
        .orderBy('fechaCreacion', descending: true)
        .limit(20)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Future<void> actualizarCajaChica(
    double nuevoSaldo,
    String usuarioId,
    String? observaciones, {
    String accion = 'actualizacion_saldo',
  }) async {
    final snap = await _col.doc(_cajaChicaId).get();
    final saldoAnterior =
        (snap.data()?['saldoActual'] as num? ?? 0).toDouble();

    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      _col.doc(_cajaChicaId),
      {
        'saldoActual': nuevoSaldo,
        'moneda': 'ARS',
        'fechaActualizacion': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(_cajaChicaMovCol.doc(), {
      'saldoAnterior': saldoAnterior,
      'saldoNuevo': nuevoSaldo,
      'observaciones': ?observaciones,
      'usuarioId': usuarioId,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    await LogCambioService().registrar(
      entidadTipo: 'caja_chica',
      entidadId: _cajaChicaId,
      usuarioId: usuarioId,
      accion: accion,
      anterior: {'saldo': saldoAnterior},
      nuevo: {
        'saldo': nuevoSaldo,
        'observaciones': ?observaciones,
      },
    );
  }

  Future<void> sumarACajaChica(
    double monto,
    String usuarioId,
    String descripcion,
  ) async {
    final snap = await _col.doc(_cajaChicaId).get();
    final saldoActual =
        (snap.data()?['saldoActual'] as num? ?? 0).toDouble();
    await actualizarCajaChica(saldoActual + monto, usuarioId, descripcion,
        accion: 'ingreso_efectivo');
  }

  Future<void> descontarDeCajaChica(
    double monto,
    String usuarioId,
    String descripcion,
  ) async {
    final snap = await _col.doc(_cajaChicaId).get();
    final saldoActual =
        (snap.data()?['saldoActual'] as num? ?? 0).toDouble();
    await actualizarCajaChica(saldoActual - monto, usuarioId, descripcion);
  }

  Future<void> depositarACuentaBancaria(
    double monto,
    String usuarioId,
    String? observaciones,
  ) async {
    final cajaSnap = await _col.doc(_cajaChicaId).get();
    final saldoCaja =
        (cajaSnap.data()?['saldoActual'] as num? ?? 0).toDouble();
    final cuentaSnap = await _col.doc(_docId).get();
    final saldoCuenta =
        (cuentaSnap.data()?['saldoActual'] as num? ?? 0).toDouble();

    final nuevoSaldoCaja = saldoCaja - monto;
    final nuevoSaldoCuenta = saldoCuenta + monto;
    final obs = observaciones ?? 'Depósito desde Caja Chica';

    final batch = FirebaseFirestore.instance.batch();
    batch.update(_col.doc(_cajaChicaId), {
      'saldoActual': nuevoSaldoCaja,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });
    batch.set(_cajaChicaMovCol.doc(), {
      'saldoAnterior': saldoCaja,
      'saldoNuevo': nuevoSaldoCaja,
      'observaciones': obs,
      'tipo': 'deposito_banco',
      'usuarioId': usuarioId,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
    batch.update(_col.doc(_docId), {
      'saldoActual': nuevoSaldoCuenta,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });
    batch.set(_movCol.doc(), {
      'tipo': 'actualizacion_saldo',
      'saldoAnterior': saldoCuenta,
      'saldoNuevo': nuevoSaldoCuenta,
      'observaciones': obs,
      'usuarioId': usuarioId,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    await LogCambioService().registrar(
      entidadTipo: 'transferencia_caja_banco',
      entidadId: _cajaChicaId,
      usuarioId: usuarioId,
      accion: 'deposito',
      anterior: {'saldoCajaChica': saldoCaja, 'saldoCuenta': saldoCuenta},
      nuevo: {
        'saldoCajaChica': nuevoSaldoCaja,
        'saldoCuenta': nuevoSaldoCuenta,
        'monto': monto,
        'observaciones': ?observaciones,
      },
    );
  }

  // TODO: Mecanismo de adelanto y reintegro — gasto adelantado por miembro,
  // se asienta al momento del reintegro desde Caja Chica.

  Future<void> agregarMovimiento(MovimientoBancario movimiento) =>
      _movCol.add(movimiento.toMap());

  Future<void> eliminarMovimiento(String id, String usuarioId) async {
    final snap = await _movCol.doc(id).get();
    final anterior = snap.data();

    await _movCol.doc(id).delete();

    if (anterior != null) {
      await LogCambioService().registrar(
        entidadTipo: 'cuenta_bancaria',
        entidadId: id,
        usuarioId: usuarioId,
        accion: 'eliminacion',
        anterior: anterior,
        nuevo: null,
      );
    }
  }

  Map<String, dynamic> _extractDatosCuenta(Map<String, dynamic> data) => {
        'banco': data['banco'],
        if (data['titular'] != null) 'titular': data['titular'],
        'tipoCuenta': data['tipoCuenta'],
        'cbu': data['cbu'],
        if (data['alias'] != null) 'alias': data['alias'],
      };
}
