import 'package:cloud_firestore/cloud_firestore.dart';

class Voto {
  final String id;
  final String votacionId;
  final String objetoId; // presupuesto.id
  final String socioId;
  final String tipoSocio; // activo / honorario / adherente
  final String valor;     // 'a_favor' | 'en_contra' | 'abstencion'
  final DateTime fecha;

  const Voto({
    required this.id,
    required this.votacionId,
    required this.objetoId,
    required this.socioId,
    required this.tipoSocio,
    required this.valor,
    required this.fecha,
  });

  Map<String, dynamic> toMap() => {
        'votacionId': votacionId,
        'objetoId': objetoId,
        'socioId': socioId,
        'tipoSocio': tipoSocio,
        'valor': valor,
        'fecha': Timestamp.fromDate(fecha),
      };

  factory Voto.fromMap(Map<String, dynamic> map, String id) => Voto(
        id: id,
        votacionId: map['votacionId'] as String? ?? '',
        objetoId: map['objetoId'] as String? ?? '',
        socioId: map['socioId'] as String? ?? '',
        tipoSocio: map['tipoSocio'] as String? ?? 'activo',
        valor: map['valor'] as String? ?? '',
        fecha: map['fecha'] is Timestamp
            ? (map['fecha'] as Timestamp).toDate()
            : DateTime.now(),
      );
}
