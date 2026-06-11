import 'package:cloud_firestore/cloud_firestore.dart';

class TarifaCuota {
  final String id;
  final String tipoCuotaId;
  final double monto;
  final String moneda;
  final DateTime vigenciaDesde;
  final String usuarioId;

  const TarifaCuota({
    required this.id,
    required this.tipoCuotaId,
    required this.monto,
    required this.moneda,
    required this.vigenciaDesde,
    required this.usuarioId,
  });

  Map<String, dynamic> toMap() => {
        'tipoCuotaId': tipoCuotaId,
        'monto': monto,
        'moneda': moneda,
        'vigenciaDesde': Timestamp.fromDate(vigenciaDesde),
        'usuarioId': usuarioId,
      };

  factory TarifaCuota.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();
    return TarifaCuota(
      id: id,
      tipoCuotaId: map['tipoCuotaId'] as String? ?? '',
      monto: (map['monto'] as num? ?? 0).toDouble(),
      moneda: map['moneda'] as String? ?? 'ARS',
      vigenciaDesde: ts(map['vigenciaDesde']),
      usuarioId: map['usuarioId'] as String? ?? '',
    );
  }
}
