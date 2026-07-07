import 'package:cloud_firestore/cloud_firestore.dart';

class Persona {
  static const _unset = Object();

  final String id;
  final String tipoPersona; // fisica / fiscal
  final String nombre;
  final String apellido;
  final String? dni;
  final DateTime? fechaNacimiento;
  final String? telefono;
  final String? email;
  final String? direccion;
  final String? fotoUrl;
  final List<String> habilidades;
  final String? razonSocial;
  final String? cuit;
  final String? personaContactoId;
  final String? subtipo;
  final String? cursoId;
  final List<String> hijosIds;
  final bool activo;
  final DateTime fechaCreacion;

  const Persona({
    required this.id,
    this.tipoPersona = 'fisica',
    this.nombre = '',
    this.apellido = '',
    this.dni,
    this.fechaNacimiento,
    this.telefono,
    this.email,
    this.direccion,
    this.fotoUrl,
    this.habilidades = const [],
    this.razonSocial,
    this.cuit,
    this.personaContactoId,
    this.subtipo,
    this.cursoId,
    this.hijosIds = const [],
    required this.activo,
    required this.fechaCreacion,
  });

  String get nombreCompleto => tipoPersona == 'fiscal'
      ? (razonSocial ?? '(sin nombre)')
      : '$nombre $apellido'.trim();

  Map<String, dynamic> toMap() => {
        'tipoPersona': tipoPersona,
        'nombre': nombre,
        'apellido': apellido,
        if (dni != null) 'dni': dni,
        if (fechaNacimiento != null)
          'fechaNacimiento': Timestamp.fromDate(fechaNacimiento!),
        if (telefono != null) 'telefono': telefono,
        if (email != null) 'email': email,
        if (direccion != null) 'direccion': direccion,
        if (fotoUrl != null) 'fotoUrl': fotoUrl,
        'habilidades': habilidades,
        if (razonSocial != null) 'razonSocial': razonSocial,
        if (cuit != null) 'cuit': cuit,
        if (personaContactoId != null) 'personaContactoId': personaContactoId,
        if (subtipo != null) 'subtipo': subtipo,
        if (cursoId != null) 'cursoId': cursoId,
        'hijosIds': hijosIds,
        'activo': activo,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      };

  factory Persona.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
    DateTime? tsN(dynamic v) => v is Timestamp ? v.toDate() : null;
    return Persona(
      id: id,
      tipoPersona: map['tipoPersona'] as String? ?? 'fisica',
      nombre: map['nombre'] as String? ?? '',
      apellido: map['apellido'] as String? ?? '',
      dni: map['dni'] as String?,
      fechaNacimiento: tsN(map['fechaNacimiento']),
      telefono: map['telefono'] as String?,
      email: map['email'] as String?,
      direccion: map['direccion'] as String?,
      fotoUrl: map['fotoUrl'] as String?,
      habilidades:
          (map['habilidades'] as List<dynamic>?)?.cast<String>() ?? [],
      razonSocial: map['razonSocial'] as String?,
      cuit: map['cuit'] as String?,
      personaContactoId: map['personaContactoId'] as String?,
      subtipo: map['subtipo'] as String?,
      cursoId: map['cursoId'] as String?,
      hijosIds: (map['hijosIds'] as List<dynamic>?)?.cast<String>() ?? [],
      activo: map['activo'] as bool? ?? true,
      fechaCreacion: ts(map['fechaCreacion']),
    );
  }

  Persona copyWith({
    String? tipoPersona,
    String? nombre,
    String? apellido,
    Object? dni = _unset,
    Object? fechaNacimiento = _unset,
    Object? telefono = _unset,
    Object? email = _unset,
    Object? direccion = _unset,
    Object? fotoUrl = _unset,
    List<String>? habilidades,
    Object? razonSocial = _unset,
    Object? cuit = _unset,
    Object? personaContactoId = _unset,
    Object? subtipo = _unset,
    Object? cursoId = _unset,
    List<String>? hijosIds,
    bool? activo,
    DateTime? fechaCreacion,
  }) {
    return Persona(
      id: id,
      tipoPersona: tipoPersona ?? this.tipoPersona,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      dni: dni == _unset ? this.dni : dni as String?,
      fechaNacimiento: fechaNacimiento == _unset
          ? this.fechaNacimiento
          : fechaNacimiento as DateTime?,
      telefono: telefono == _unset ? this.telefono : telefono as String?,
      email: email == _unset ? this.email : email as String?,
      direccion: direccion == _unset ? this.direccion : direccion as String?,
      fotoUrl: fotoUrl == _unset ? this.fotoUrl : fotoUrl as String?,
      habilidades: habilidades ?? this.habilidades,
      razonSocial:
          razonSocial == _unset ? this.razonSocial : razonSocial as String?,
      cuit: cuit == _unset ? this.cuit : cuit as String?,
      personaContactoId: personaContactoId == _unset
          ? this.personaContactoId
          : personaContactoId as String?,
      subtipo: subtipo == _unset ? this.subtipo : subtipo as String?,
      cursoId: cursoId == _unset ? this.cursoId : cursoId as String?,
      hijosIds: hijosIds ?? this.hijosIds,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }
}
