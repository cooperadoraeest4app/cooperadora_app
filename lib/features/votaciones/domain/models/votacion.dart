import 'package:cloud_firestore/cloud_firestore.dart';

class Votacion {
  final String id;
  final String tipo;
  final String objetoId;
  final String titulo;
  final String? descripcion;
  final String estado; // en_curso / aprobada / rechazada
  final DateTime fechaInicio;
  final DateTime? fechaLimite;
  final int totalSociosActivos;
  final int totalMiembrosCD;
  final int quorumRequerido;
  final double mayoriaRequerida;
  final String usuarioId;
  final DateTime fechaCreacion;
  final DateTime? fechaCierre;
  final String? presupuestoAprobadoId;

  const Votacion({
    required this.id,
    required this.tipo,
    required this.objetoId,
    required this.titulo,
    this.descripcion,
    required this.estado,
    required this.fechaInicio,
    this.fechaLimite,
    required this.totalSociosActivos,
    required this.totalMiembrosCD,
    required this.quorumRequerido,
    this.mayoriaRequerida = 66.67,
    required this.usuarioId,
    required this.fechaCreacion,
    this.fechaCierre,
    this.presupuestoAprobadoId,
  });

  Map<String, dynamic> toMap() => {
        'tipo': tipo,
        'objetoId': objetoId,
        'titulo': titulo,
        if (descripcion != null) 'descripcion': descripcion,
        'estado': estado,
        'fechaInicio': Timestamp.fromDate(fechaInicio),
        if (fechaLimite != null) 'fechaLimite': Timestamp.fromDate(fechaLimite!),
        'totalSociosActivos': totalSociosActivos,
        'totalMiembrosCD': totalMiembrosCD,
        'quorumRequerido': quorumRequerido,
        'mayoriaRequerida': mayoriaRequerida,
        'usuarioId': usuarioId,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
        if (fechaCierre != null) 'fechaCierre': Timestamp.fromDate(fechaCierre!),
        if (presupuestoAprobadoId != null) 'presupuestoAprobadoId': presupuestoAprobadoId,
      };

  factory Votacion.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();
    DateTime? tsN(dynamic v) => v is Timestamp ? v.toDate() : null;
    return Votacion(
      id: id,
      tipo: map['tipo'] as String? ?? 'presupuesto',
      objetoId: map['objetoId'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      descripcion: map['descripcion'] as String?,
      estado: map['estado'] as String? ?? 'en_curso',
      fechaInicio: ts(map['fechaInicio']),
      fechaLimite: tsN(map['fechaLimite']),
      totalSociosActivos: (map['totalSociosActivos'] as num? ?? 0).toInt(),
      totalMiembrosCD: (map['totalMiembrosCD'] as num? ?? 0).toInt(),
      quorumRequerido: (map['quorumRequerido'] as num? ?? 15).toInt(),
      mayoriaRequerida: (map['mayoriaRequerida'] as num? ?? 66.67).toDouble(),
      usuarioId: map['usuarioId'] as String? ?? '',
      fechaCreacion: ts(map['fechaCreacion']),
      fechaCierre: tsN(map['fechaCierre']),
      presupuestoAprobadoId: map['presupuestoAprobadoId'] as String?,
    );
  }

  Votacion copyWith({
    String? id,
    String? estado,
    DateTime? fechaCierre,
    String? presupuestoAprobadoId,
  }) =>
      Votacion(
        id: id ?? this.id,
        tipo: tipo,
        objetoId: objetoId,
        titulo: titulo,
        descripcion: descripcion,
        estado: estado ?? this.estado,
        fechaInicio: fechaInicio,
        fechaLimite: fechaLimite,
        totalSociosActivos: totalSociosActivos,
        totalMiembrosCD: totalMiembrosCD,
        quorumRequerido: quorumRequerido,
        mayoriaRequerida: mayoriaRequerida,
        usuarioId: usuarioId,
        fechaCreacion: fechaCreacion,
        fechaCierre: fechaCierre ?? this.fechaCierre,
        presupuestoAprobadoId: presupuestoAprobadoId ?? this.presupuestoAprobadoId,
      );
}
