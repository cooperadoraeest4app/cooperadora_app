import 'package:cloud_firestore/cloud_firestore.dart';

class Proyecto {
  final String id;
  final String nombre;
  final String? descripcion;
  final String tipoProyectoId;
  final double presupuestoActual;
  final DateTime fechaInicio;
  final DateTime? fechaFinEstimada;
  final DateTime? fechaFinReal;
  final String estado;
  final List<String> responsables;
  final bool publico;
  final String? votacionId;
  final DateTime fechaCreacion;
  final String usuarioId;
  final String? ultimaModificacionPor;
  final DateTime? ultimaModificacionFecha;

  const Proyecto({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.tipoProyectoId,
    required this.presupuestoActual,
    required this.fechaInicio,
    this.fechaFinEstimada,
    this.fechaFinReal,
    required this.estado,
    required this.responsables,
    required this.publico,
    this.votacionId,
    required this.fechaCreacion,
    this.usuarioId = '',
    this.ultimaModificacionPor,
    this.ultimaModificacionFecha,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'tipoProyectoId': tipoProyectoId,
        'presupuestoActual': presupuestoActual,
        'fechaInicio': Timestamp.fromDate(fechaInicio),
        'fechaFinEstimada':
            fechaFinEstimada != null ? Timestamp.fromDate(fechaFinEstimada!) : null,
        'fechaFinReal':
            fechaFinReal != null ? Timestamp.fromDate(fechaFinReal!) : null,
        'estado': estado,
        'responsables': responsables,
        'publico': publico,
        'votacionId': votacionId,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
        'usuarioId': usuarioId,
        'ultimaModificacionPor': ultimaModificacionPor,
        'ultimaModificacionFecha': ultimaModificacionFecha != null
            ? Timestamp.fromDate(ultimaModificacionFecha!)
            : null,
      };

  factory Proyecto.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();
    DateTime? tsOpt(dynamic v) => v is Timestamp ? v.toDate() : null;

    return Proyecto(
      id: id,
      nombre: map['nombre'] as String? ?? '',
      descripcion: map['descripcion'] as String?,
      tipoProyectoId: map['tipoProyectoId'] as String? ?? '',
      presupuestoActual: (map['presupuestoActual'] as num? ?? 0).toDouble(),
      fechaInicio: ts(map['fechaInicio']),
      fechaFinEstimada: tsOpt(map['fechaFinEstimada']),
      fechaFinReal: tsOpt(map['fechaFinReal']),
      estado: map['estado'] as String? ?? 'planificado',
      responsables:
          (map['responsables'] as List<dynamic>?)?.cast<String>() ?? [],
      publico: map['publico'] as bool? ?? true,
      votacionId: map['votacionId'] as String?,
      fechaCreacion: ts(map['fechaCreacion']),
      usuarioId: map['usuarioId'] as String? ?? '',
      ultimaModificacionPor: map['ultimaModificacionPor'] as String?,
      ultimaModificacionFecha: tsOpt(map['ultimaModificacionFecha']),
    );
  }

  Proyecto copyWith({
    String? nombre,
    String? descripcion,
    bool clearDescripcion = false,
    String? tipoProyectoId,
    double? presupuestoActual,
    DateTime? fechaInicio,
    DateTime? fechaFinEstimada,
    bool clearFechaFinEstimada = false,
    DateTime? fechaFinReal,
    bool clearFechaFinReal = false,
    String? estado,
    List<String>? responsables,
    bool? publico,
    String? votacionId,
    String? ultimaModificacionPor,
    DateTime? ultimaModificacionFecha,
  }) =>
      Proyecto(
        id: id,
        nombre: nombre ?? this.nombre,
        descripcion:
            clearDescripcion ? null : (descripcion ?? this.descripcion),
        tipoProyectoId: tipoProyectoId ?? this.tipoProyectoId,
        presupuestoActual: presupuestoActual ?? this.presupuestoActual,
        fechaInicio: fechaInicio ?? this.fechaInicio,
        fechaFinEstimada: clearFechaFinEstimada
            ? null
            : (fechaFinEstimada ?? this.fechaFinEstimada),
        fechaFinReal:
            clearFechaFinReal ? null : (fechaFinReal ?? this.fechaFinReal),
        estado: estado ?? this.estado,
        responsables: responsables ?? this.responsables,
        publico: publico ?? this.publico,
        votacionId: votacionId ?? this.votacionId,
        fechaCreacion: fechaCreacion,
        usuarioId: usuarioId,
        ultimaModificacionPor:
            ultimaModificacionPor ?? this.ultimaModificacionPor,
        ultimaModificacionFecha:
            ultimaModificacionFecha ?? this.ultimaModificacionFecha,
      );
}
