import 'package:cloud_firestore/cloud_firestore.dart';

class Integrante {
  final String id;
  final String personaId;
  final String nombre;
  final String socioId;
  final String tipo; // padre / madre / tutor / alumno / otro
  final String? grado;
  final DateTime fechaCreacion;

  const Integrante({
    required this.id,
    this.personaId = '',
    required this.nombre,
    required this.socioId,
    required this.tipo,
    this.grado,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() => {
        'personaId': personaId,
        'nombre': nombre,
        'socioId': socioId,
        'tipo': tipo,
        'grado': grado,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      };

  factory Integrante.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();
    return Integrante(
      id: id,
      personaId: map['personaId'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      socioId: map['socioId'] as String? ?? '',
      tipo: map['tipo'] as String? ?? 'otro',
      grado: map['grado'] as String?,
      fechaCreacion: ts(map['fechaCreacion']),
    );
  }
}
