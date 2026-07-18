import 'package:cloud_firestore/cloud_firestore.dart';

class PagoCuota {
  final String id;
  final String socioId;
  final double monto;
  final String metodoPagoId;
  final DateTime fechaPago;
  final String? observaciones;
  final String? ingresoId;
  final String usuarioId;
  final DateTime fechaCreacion;
  final String? migradoDeCuotaId;

  const PagoCuota({
    required this.id,
    required this.socioId,
    required this.monto,
    required this.metodoPagoId,
    required this.fechaPago,
    this.observaciones,
    this.ingresoId,
    required this.usuarioId,
    required this.fechaCreacion,
    this.migradoDeCuotaId,
  });

  Map<String, dynamic> toMap() => {
        'socioId': socioId,
        'monto': monto,
        'metodoPagoId': metodoPagoId,
        'fechaPago': Timestamp.fromDate(fechaPago),
        if (observaciones != null) 'observaciones': observaciones,
        if (ingresoId != null) 'ingresoId': ingresoId,
        'usuarioId': usuarioId,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
        if (migradoDeCuotaId != null) 'migradoDeCuotaId': migradoDeCuotaId,
      };

  factory PagoCuota.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
    return PagoCuota(
      id: id,
      socioId: map['socioId'] as String? ?? '',
      monto: (map['monto'] as num? ?? 0).toDouble(),
      metodoPagoId: map['metodoPagoId'] as String? ?? '',
      fechaPago: ts(map['fechaPago']),
      observaciones: map['observaciones'] as String?,
      ingresoId: map['ingresoId'] as String?,
      usuarioId: map['usuarioId'] as String? ?? '',
      fechaCreacion: ts(map['fechaCreacion']),
      migradoDeCuotaId: map['migradoDeCuotaId'] as String?,
    );
  }
}
