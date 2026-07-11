import 'package:cloud_firestore/cloud_firestore.dart';

class PresupuestoProyecto {
  final String id;
  final String proyectoId;
  final String descripcion;
  final String? proveedor;
  final double? monto;
  final List<String> archivos;
  final String usuarioId;
  final DateTime fechaCreacion;
  final String? ultimaModificacionPor;
  final DateTime? ultimaModificacionFecha;

  const PresupuestoProyecto({
    required this.id,
    required this.proyectoId,
    required this.descripcion,
    this.proveedor,
    this.monto,
    required this.archivos,
    required this.usuarioId,
    required this.fechaCreacion,
    this.ultimaModificacionPor,
    this.ultimaModificacionFecha,
  });

  Map<String, dynamic> toMap() => {
        'proyectoId': proyectoId,
        'descripcion': descripcion,
        if (proveedor != null) 'proveedor': proveedor,
        if (monto != null) 'monto': monto,
        'archivos': archivos,
        'usuarioId': usuarioId,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
        if (ultimaModificacionPor != null)
          'ultimaModificacionPor': ultimaModificacionPor,
        if (ultimaModificacionFecha != null)
          'ultimaModificacionFecha':
              Timestamp.fromDate(ultimaModificacionFecha!),
      };

  factory PresupuestoProyecto.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();
    return PresupuestoProyecto(
      id: id,
      proyectoId: map['proyectoId'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      proveedor: map['proveedor'] as String?,
      monto: (map['monto'] as num?)?.toDouble(),
      archivos: (map['archivos'] as List<dynamic>?)?.cast<String>() ?? [],
      usuarioId: map['usuarioId'] as String? ?? '',
      fechaCreacion: ts(map['fechaCreacion']),
      ultimaModificacionPor: map['ultimaModificacionPor'] as String?,
      ultimaModificacionFecha: map['ultimaModificacionFecha'] != null
          ? ts(map['ultimaModificacionFecha'])
          : null,
    );
  }

  PresupuestoProyecto copyWith({
    String? proyectoId,
    String? descripcion,
    String? proveedor,
    bool clearProveedor = false,
    double? monto,
    bool clearMonto = false,
    List<String>? archivos,
    String? usuarioId,
    String? ultimaModificacionPor,
    DateTime? ultimaModificacionFecha,
  }) =>
      PresupuestoProyecto(
        id: id,
        proyectoId: proyectoId ?? this.proyectoId,
        descripcion: descripcion ?? this.descripcion,
        proveedor: clearProveedor ? null : (proveedor ?? this.proveedor),
        monto: clearMonto ? null : (monto ?? this.monto),
        archivos: archivos ?? this.archivos,
        usuarioId: usuarioId ?? this.usuarioId,
        fechaCreacion: fechaCreacion,
        ultimaModificacionPor:
            ultimaModificacionPor ?? this.ultimaModificacionPor,
        ultimaModificacionFecha:
            ultimaModificacionFecha ?? this.ultimaModificacionFecha,
      );
}
