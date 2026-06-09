import 'package:cloud_firestore/cloud_firestore.dart';

const _unset = Object();

class CuentaBancaria {
  final String id;
  final String banco;
  final String tipoCuenta;
  final String cbu;
  final String? alias;
  final double saldoActual;
  final String moneda;
  final bool activa;
  final DateTime fechaActualizacion;

  const CuentaBancaria({
    required this.id,
    required this.banco,
    required this.tipoCuenta,
    required this.cbu,
    this.alias,
    required this.saldoActual,
    this.moneda = 'ARS',
    required this.activa,
    required this.fechaActualizacion,
  });

  Map<String, dynamic> toMap() => {
        'banco': banco,
        'tipoCuenta': tipoCuenta,
        'cbu': cbu,
        'alias': alias,
        'saldoActual': saldoActual,
        'moneda': moneda,
        'activa': activa,
        'fechaActualizacion': Timestamp.fromDate(fechaActualizacion),
      };

  factory CuentaBancaria.fromMap(Map<String, dynamic> map, String id) =>
      CuentaBancaria(
        id: id,
        banco: map['banco'] as String? ?? '',
        tipoCuenta: map['tipoCuenta'] as String? ?? '',
        cbu: map['cbu'] as String? ?? '',
        alias: map['alias'] as String?,
        saldoActual: (map['saldoActual'] as num? ?? 0).toDouble(),
        moneda: map['moneda'] as String? ?? 'ARS',
        activa: map['activa'] as bool? ?? true,
        fechaActualizacion: map['fechaActualizacion'] != null
            ? (map['fechaActualizacion'] as Timestamp).toDate()
            : DateTime.now(),
      );

  CuentaBancaria copyWith({
    String? banco,
    String? tipoCuenta,
    String? cbu,
    Object? alias = _unset,
    double? saldoActual,
    String? moneda,
    bool? activa,
    DateTime? fechaActualizacion,
  }) =>
      CuentaBancaria(
        id: id,
        banco: banco ?? this.banco,
        tipoCuenta: tipoCuenta ?? this.tipoCuenta,
        cbu: cbu ?? this.cbu,
        alias: alias == _unset ? this.alias : alias as String?,
        saldoActual: saldoActual ?? this.saldoActual,
        moneda: moneda ?? this.moneda,
        activa: activa ?? this.activa,
        fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      );
}
