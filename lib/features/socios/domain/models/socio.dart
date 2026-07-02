import 'package:cloud_firestore/cloud_firestore.dart';

class Socio {
  static const _unset = Object();

  final String id;
  final int numeroSocio;
  final String personaId;
  final String tipoSocio; // activo / honorario / adherente
  final bool activo;
  final DateTime fechaIngreso;
  final String? observaciones;
  final String? usuarioId;
  final String? ultimaModificacionPor;
  final DateTime? ultimaModificacionFecha;

  const Socio({
    required this.id,
    required this.numeroSocio,
    required this.personaId,
    required this.tipoSocio,
    required this.activo,
    required this.fechaIngreso,
    this.observaciones,
    this.usuarioId,
    this.ultimaModificacionPor,
    this.ultimaModificacionFecha,
  });

  Map<String, dynamic> toMap() => {
        'numeroSocio': numeroSocio,
        'personaId': personaId,
        'tipoSocio': tipoSocio,
        'activo': activo,
        'fechaIngreso': Timestamp.fromDate(fechaIngreso),
        if (observaciones != null) 'observaciones': observaciones,
        if (usuarioId != null) 'usuarioId': usuarioId,
        if (ultimaModificacionPor != null)
          'ultimaModificacionPor': ultimaModificacionPor,
        if (ultimaModificacionFecha != null)
          'ultimaModificacionFecha':
              Timestamp.fromDate(ultimaModificacionFecha!),
      };

  factory Socio.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
    DateTime? tsN(dynamic v) => v is Timestamp ? v.toDate() : null;
    return Socio(
      id: id,
      numeroSocio: (map['numeroSocio'] as num? ?? 0).toInt(),
      personaId: map['personaId'] as String? ?? '',
      tipoSocio: map['tipoSocio'] as String? ?? 'activo',
      activo: map['activo'] as bool? ?? true,
      fechaIngreso: ts(map['fechaIngreso']),
      observaciones: map['observaciones'] as String?,
      usuarioId: map['usuarioId'] as String?,
      ultimaModificacionPor: map['ultimaModificacionPor'] as String?,
      ultimaModificacionFecha: tsN(map['ultimaModificacionFecha']),
    );
  }

  Socio copyWith({
    int? numeroSocio,
    String? personaId,
    String? tipoSocio,
    bool? activo,
    DateTime? fechaIngreso,
    Object? observaciones = _unset,
    Object? usuarioId = _unset,
    Object? ultimaModificacionPor = _unset,
    Object? ultimaModificacionFecha = _unset,
  }) {
    return Socio(
      id: id,
      numeroSocio: numeroSocio ?? this.numeroSocio,
      personaId: personaId ?? this.personaId,
      tipoSocio: tipoSocio ?? this.tipoSocio,
      activo: activo ?? this.activo,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      observaciones: observaciones == _unset
          ? this.observaciones
          : observaciones as String?,
      usuarioId: usuarioId == _unset ? this.usuarioId : usuarioId as String?,
      ultimaModificacionPor: ultimaModificacionPor == _unset
          ? this.ultimaModificacionPor
          : ultimaModificacionPor as String?,
      ultimaModificacionFecha: ultimaModificacionFecha == _unset
          ? this.ultimaModificacionFecha
          : ultimaModificacionFecha as DateTime?,
    );
  }
}
