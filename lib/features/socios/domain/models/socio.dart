import 'package:cloud_firestore/cloud_firestore.dart';

class Socio {
  final String id;
  final String tipoSocioId;
  final String subtipoSocioId;
  final String? apellidoFamilia;
  final String? razonSocial;
  final String? cuit;
  final String? personaContactoId;
  final bool activo;
  final DateTime fechaIngreso;
  final String? observaciones;
  final DateTime fechaCreacion;

  const Socio({
    required this.id,
    required this.tipoSocioId,
    required this.subtipoSocioId,
    this.apellidoFamilia,
    this.razonSocial,
    this.cuit,
    this.personaContactoId,
    required this.activo,
    required this.fechaIngreso,
    this.observaciones,
    required this.fechaCreacion,
  });

  String get nombreDisplay =>
      apellidoFamilia?.isNotEmpty == true
          ? apellidoFamilia!
          : (razonSocial ?? '(sin nombre)');

  Map<String, dynamic> toMap() => {
        'tipoSocioId': tipoSocioId,
        'subtipoSocioId': subtipoSocioId,
        'apellidoFamilia': apellidoFamilia,
        'razonSocial': razonSocial,
        'cuit': cuit,
        'personaContactoId': personaContactoId,
        'activo': activo,
        'fechaIngreso': Timestamp.fromDate(fechaIngreso),
        'observaciones': observaciones,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      };

  factory Socio.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();
    return Socio(
      id: id,
      tipoSocioId: map['tipoSocioId'] as String? ?? '',
      subtipoSocioId: map['subtipoSocioId'] as String? ?? '',
      apellidoFamilia: map['apellidoFamilia'] as String?,
      razonSocial: map['razonSocial'] as String?,
      cuit: map['cuit'] as String?,
      personaContactoId: map['personaContactoId'] as String?,
      activo: map['activo'] as bool? ?? true,
      fechaIngreso: ts(map['fechaIngreso']),
      observaciones: map['observaciones'] as String?,
      fechaCreacion: ts(map['fechaCreacion']),
    );
  }

  Socio copyWith({
    String? tipoSocioId,
    String? subtipoSocioId,
    String? apellidoFamilia,
    bool clearApellidoFamilia = false,
    String? razonSocial,
    bool clearRazonSocial = false,
    String? cuit,
    bool clearCuit = false,
    String? personaContactoId,
    bool clearPersonaContactoId = false,
    bool? activo,
    DateTime? fechaIngreso,
    String? observaciones,
    bool clearObservaciones = false,
  }) =>
      Socio(
        id: id,
        tipoSocioId: tipoSocioId ?? this.tipoSocioId,
        subtipoSocioId: subtipoSocioId ?? this.subtipoSocioId,
        apellidoFamilia: clearApellidoFamilia
            ? null
            : (apellidoFamilia ?? this.apellidoFamilia),
        razonSocial:
            clearRazonSocial ? null : (razonSocial ?? this.razonSocial),
        cuit: clearCuit ? null : (cuit ?? this.cuit),
        personaContactoId: clearPersonaContactoId
            ? null
            : (personaContactoId ?? this.personaContactoId),
        activo: activo ?? this.activo,
        fechaIngreso: fechaIngreso ?? this.fechaIngreso,
        observaciones: clearObservaciones
            ? null
            : (observaciones ?? this.observaciones),
        fechaCreacion: fechaCreacion,
      );
}
