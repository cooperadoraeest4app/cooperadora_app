import 'package:cloud_firestore/cloud_firestore.dart';

class Invitacion {
  static const _unset = Object();

  final String id;
  final String codigo;
  final String tipo; // 'individual' / 'generica'
  final String rolAsignado;
  final String? nombreDestino;
  final String? apellidoDestino;
  final String? emailDestino;
  final String? telefonoDestino;
  final bool usada;
  final int usos;
  final int? limiteUsos;
  final DateTime? fechaVencimiento;
  final String creadaPor;
  final DateTime fechaCreacion;
  final bool esSocio;
  final String? tipoSocio; // 'activo' / 'adherente' / 'honorario'

  const Invitacion({
    required this.id,
    required this.codigo,
    required this.tipo,
    required this.rolAsignado,
    this.nombreDestino,
    this.apellidoDestino,
    this.emailDestino,
    this.telefonoDestino,
    required this.usada,
    required this.usos,
    this.limiteUsos,
    this.fechaVencimiento,
    required this.creadaPor,
    required this.fechaCreacion,
    this.esSocio = false,
    this.tipoSocio,
  });

  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'tipo': tipo,
        'rolAsignado': rolAsignado,
        if (nombreDestino != null) 'nombreDestino': nombreDestino,
        if (apellidoDestino != null) 'apellidoDestino': apellidoDestino,
        if (emailDestino != null) 'emailDestino': emailDestino,
        if (telefonoDestino != null) 'telefonoDestino': telefonoDestino,
        'usada': usada,
        'usos': usos,
        if (limiteUsos != null) 'limiteUsos': limiteUsos,
        if (fechaVencimiento != null)
          'fechaVencimiento': Timestamp.fromDate(fechaVencimiento!),
        'creadaPor': creadaPor,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
        'esSocio': esSocio,
        if (tipoSocio != null) 'tipoSocio': tipoSocio,
      };

  factory Invitacion.fromMap(Map<String, dynamic> map, String id) {
    DateTime? tsN(dynamic v) => v is Timestamp ? v.toDate() : null;
    return Invitacion(
      id: id,
      codigo: map['codigo'] as String? ?? '',
      tipo: map['tipo'] as String? ?? 'individual',
      rolAsignado: map['rolAsignado'] as String? ?? 'solo_lectura',
      nombreDestino: map['nombreDestino'] as String?,
      apellidoDestino: map['apellidoDestino'] as String?,
      emailDestino: map['emailDestino'] as String?,
      telefonoDestino: map['telefonoDestino'] as String?,
      usada: map['usada'] as bool? ?? false,
      usos: (map['usos'] as num? ?? 0).toInt(),
      limiteUsos: (map['limiteUsos'] as num?)?.toInt(),
      fechaVencimiento: tsN(map['fechaVencimiento']),
      creadaPor: map['creadaPor'] as String? ?? '',
      fechaCreacion: tsN(map['fechaCreacion']) ?? DateTime.now(),
      esSocio: map['esSocio'] as bool? ?? false,
      tipoSocio: map['tipoSocio'] as String?,
    );
  }

  Invitacion copyWith({
    String? codigo,
    String? tipo,
    String? rolAsignado,
    Object? nombreDestino = _unset,
    Object? apellidoDestino = _unset,
    Object? emailDestino = _unset,
    Object? telefonoDestino = _unset,
    bool? usada,
    int? usos,
    Object? limiteUsos = _unset,
    Object? fechaVencimiento = _unset,
    String? creadaPor,
    DateTime? fechaCreacion,
    bool? esSocio,
    Object? tipoSocio = _unset,
  }) {
    return Invitacion(
      id: id,
      codigo: codigo ?? this.codigo,
      tipo: tipo ?? this.tipo,
      rolAsignado: rolAsignado ?? this.rolAsignado,
      nombreDestino: nombreDestino == _unset
          ? this.nombreDestino
          : nombreDestino as String?,
      apellidoDestino: apellidoDestino == _unset
          ? this.apellidoDestino
          : apellidoDestino as String?,
      emailDestino:
          emailDestino == _unset ? this.emailDestino : emailDestino as String?,
      telefonoDestino: telefonoDestino == _unset
          ? this.telefonoDestino
          : telefonoDestino as String?,
      usada: usada ?? this.usada,
      usos: usos ?? this.usos,
      limiteUsos:
          limiteUsos == _unset ? this.limiteUsos : limiteUsos as int?,
      fechaVencimiento: fechaVencimiento == _unset
          ? this.fechaVencimiento
          : fechaVencimiento as DateTime?,
      creadaPor: creadaPor ?? this.creadaPor,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      esSocio: esSocio ?? this.esSocio,
      tipoSocio:
          tipoSocio == _unset ? this.tipoSocio : tipoSocio as String?,
    );
  }
}
