import 'package:cloud_firestore/cloud_firestore.dart';

class Recibo {
  final String id;
  final int numero;
  final int ejercicio;
  final String pagoId;
  final String socioId;
  final int numeroSocio;
  final String nombreSocio;
  final double monto;
  final DateTime fechaPago;
  final String metodoPago;
  final String usuarioId;
  final DateTime creadoEn;

  const Recibo({
    required this.id,
    required this.numero,
    required this.ejercicio,
    required this.pagoId,
    required this.socioId,
    required this.numeroSocio,
    required this.nombreSocio,
    required this.monto,
    required this.fechaPago,
    required this.metodoPago,
    required this.usuarioId,
    required this.creadoEn,
  });

  String get numeroFormateado =>
      '$ejercicio-${numero.toString().padLeft(4, '0')}';

  factory Recibo.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
    return Recibo(
      id: id,
      numero: (map['numero'] as num? ?? 0).toInt(),
      ejercicio: (map['ejercicio'] as num? ?? 0).toInt(),
      pagoId: map['pagoId'] as String? ?? '',
      socioId: map['socioId'] as String? ?? '',
      numeroSocio: (map['numeroSocio'] as num? ?? 0).toInt(),
      nombreSocio: map['nombreSocio'] as String? ?? '',
      monto: (map['monto'] as num? ?? 0).toDouble(),
      fechaPago: ts(map['fechaPago']),
      metodoPago: map['metodoPago'] as String? ?? '',
      usuarioId: map['usuarioId'] as String? ?? '',
      creadoEn: ts(map['creadoEn']),
    );
  }
}
