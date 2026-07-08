import 'package:cloud_firestore/cloud_firestore.dart';

class BalanceSnapshot {
  final String id;
  final DateTime fechaDesde;
  final DateTime fechaHasta;
  final String tipo; // 'mensual' | 'anual' | 'libre'
  final int version;
  final double totalEntradas;
  final double totalSalidas;
  final double saldoEjercicioAnterior;
  final double totalGeneral;
  final double saldoProximoEjercicio;
  final double? saldoCajaChica;
  final double? saldoBanco;
  final DateTime? fechaSaldoBanco;
  final bool saldoBancoExacto;
  final String usuarioId;
  final DateTime fechaCierre;
  // Si hubo advertencia de banco: {'fechaDatoUsado': ..., 'fechaCierreSolicitada': ...}
  final Map<String, dynamic>? advertenciaSaldoBanco;

  const BalanceSnapshot({
    required this.id,
    required this.fechaDesde,
    required this.fechaHasta,
    required this.tipo,
    required this.version,
    required this.totalEntradas,
    required this.totalSalidas,
    required this.saldoEjercicioAnterior,
    required this.totalGeneral,
    required this.saldoProximoEjercicio,
    this.saldoCajaChica,
    this.saldoBanco,
    this.fechaSaldoBanco,
    this.saldoBancoExacto = true,
    required this.usuarioId,
    required this.fechaCierre,
    this.advertenciaSaldoBanco,
  });

  bool get esConfiable => advertenciaSaldoBanco == null;

  Map<String, dynamic> toMap() => {
        'fechaDesde': Timestamp.fromDate(fechaDesde),
        'fechaHasta': Timestamp.fromDate(fechaHasta),
        'tipo': tipo,
        'version': version,
        'totalEntradas': totalEntradas,
        'totalSalidas': totalSalidas,
        'saldoEjercicioAnterior': saldoEjercicioAnterior,
        'totalGeneral': totalGeneral,
        'saldoProximoEjercicio': saldoProximoEjercicio,
        if (saldoCajaChica != null) 'saldoCajaChica': saldoCajaChica,
        if (saldoBanco != null) 'saldoBanco': saldoBanco,
        if (fechaSaldoBanco != null)
          'fechaSaldoBanco': Timestamp.fromDate(fechaSaldoBanco!),
        'saldoBancoExacto': saldoBancoExacto,
        'usuarioId': usuarioId,
        'fechaCierre': Timestamp.fromDate(fechaCierre),
        if (advertenciaSaldoBanco != null)
          'advertenciaSaldoBanco': advertenciaSaldoBanco,
      };

  factory BalanceSnapshot.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
    DateTime? tsN(dynamic v) => v is Timestamp ? v.toDate() : null;
    return BalanceSnapshot(
      id: id,
      fechaDesde: ts(map['fechaDesde']),
      fechaHasta: ts(map['fechaHasta']),
      tipo: map['tipo'] as String? ?? 'libre',
      version: map['version'] as int? ?? 1,
      totalEntradas: (map['totalEntradas'] as num? ?? 0).toDouble(),
      totalSalidas: (map['totalSalidas'] as num? ?? 0).toDouble(),
      saldoEjercicioAnterior:
          (map['saldoEjercicioAnterior'] as num? ?? 0).toDouble(),
      totalGeneral: (map['totalGeneral'] as num? ?? 0).toDouble(),
      saldoProximoEjercicio:
          (map['saldoProximoEjercicio'] as num? ?? 0).toDouble(),
      saldoCajaChica: (map['saldoCajaChica'] as num?)?.toDouble(),
      saldoBanco: (map['saldoBanco'] as num?)?.toDouble(),
      fechaSaldoBanco: tsN(map['fechaSaldoBanco']),
      saldoBancoExacto: map['saldoBancoExacto'] as bool? ?? true,
      usuarioId: map['usuarioId'] as String? ?? '',
      fechaCierre: ts(map['fechaCierre']),
      advertenciaSaldoBanco:
          map['advertenciaSaldoBanco'] as Map<String, dynamic>?,
    );
  }
}
