import 'package:cloud_firestore/cloud_firestore.dart';

class ItemProyecto {
  final String id;
  final String proyectoId;
  final String descripcion;
  final double? cantidad;
  final String? unidad;
  final double montoEstimado;
  final String estado;
  final List<String> responsables;
  final DateTime fechaCreacion;

  const ItemProyecto({
    required this.id,
    required this.proyectoId,
    required this.descripcion,
    this.cantidad,
    this.unidad,
    required this.montoEstimado,
    required this.estado,
    required this.responsables,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() => {
        'proyectoId': proyectoId,
        'descripcion': descripcion,
        'cantidad': cantidad,
        'unidad': unidad,
        'montoEstimado': montoEstimado,
        'estado': estado,
        'responsables': responsables,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      };

  factory ItemProyecto.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

    return ItemProyecto(
      id: id,
      proyectoId: map['proyectoId'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      cantidad: (map['cantidad'] as num?)?.toDouble(),
      unidad: map['unidad'] as String?,
      montoEstimado: (map['montoEstimado'] as num? ?? 0).toDouble(),
      estado: map['estado'] as String? ?? 'pendiente',
      responsables:
          (map['responsables'] as List<dynamic>?)?.cast<String>() ?? [],
      fechaCreacion: ts(map['fechaCreacion']),
    );
  }

  ItemProyecto copyWith({
    String? proyectoId,
    String? descripcion,
    double? cantidad,
    bool clearCantidad = false,
    String? unidad,
    bool clearUnidad = false,
    double? montoEstimado,
    String? estado,
    List<String>? responsables,
  }) =>
      ItemProyecto(
        id: id,
        proyectoId: proyectoId ?? this.proyectoId,
        descripcion: descripcion ?? this.descripcion,
        cantidad: clearCantidad ? null : (cantidad ?? this.cantidad),
        unidad: clearUnidad ? null : (unidad ?? this.unidad),
        montoEstimado: montoEstimado ?? this.montoEstimado,
        estado: estado ?? this.estado,
        responsables: responsables ?? this.responsables,
        fechaCreacion: fechaCreacion,
      );
}
