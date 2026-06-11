import 'package:cloud_firestore/cloud_firestore.dart';

class Cuota {
  final String id;
  final String socioId;
  final String tipoCuotaId;
  final String periodo; // MM/YYYY
  final double monto;
  final String moneda;
  final String metodoPagoId;
  final String? observaciones;
  final String? comprobante;
  final String usuarioId;
  final DateTime fechaPago;
  final DateTime fechaCreacion;

  const Cuota({
    required this.id,
    required this.socioId,
    required this.tipoCuotaId,
    required this.periodo,
    required this.monto,
    required this.moneda,
    required this.metodoPagoId,
    this.observaciones,
    this.comprobante,
    required this.usuarioId,
    required this.fechaPago,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() => {
        'socioId': socioId,
        'tipoCuotaId': tipoCuotaId,
        'periodo': periodo,
        'monto': monto,
        'moneda': moneda,
        'metodoPagoId': metodoPagoId,
        'observaciones': observaciones,
        'comprobante': comprobante,
        'usuarioId': usuarioId,
        'fechaPago': Timestamp.fromDate(fechaPago),
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      };

  factory Cuota.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();
    return Cuota(
      id: id,
      socioId: map['socioId'] as String? ?? '',
      tipoCuotaId: map['tipoCuotaId'] as String? ?? '',
      periodo: map['periodo'] as String? ?? '',
      monto: (map['monto'] as num? ?? 0).toDouble(),
      moneda: map['moneda'] as String? ?? 'ARS',
      metodoPagoId: map['metodoPagoId'] as String? ?? '',
      observaciones: map['observaciones'] as String?,
      comprobante: map['comprobante'] as String?,
      usuarioId: map['usuarioId'] as String? ?? '',
      fechaPago: ts(map['fechaPago']),
      fechaCreacion: ts(map['fechaCreacion']),
    );
  }
}
