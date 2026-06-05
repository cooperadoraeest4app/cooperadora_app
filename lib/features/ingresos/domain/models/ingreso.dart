import 'package:cloud_firestore/cloud_firestore.dart';

const _unset = Object();

class Ingreso {
  final String id;
  final double monto;
  final String moneda;
  final DateTime fecha;
  final String? descripcion;
  final String metodoPagoId;
  final String? donante;
  final String? donanteEmail;
  final String? donanteTelefono;
  final String? donanteUsuarioId;
  final String categoriaId;
  final String? proyectoId;
  final String? itemProyectoId;
  final bool recurrente;
  final String? frecuenciaId;
  final DateTime? proximaFecha;
  final String usuarioId;
  final String? comprobante;
  final DateTime fechaCreacion;

  const Ingreso({
    required this.id,
    required this.monto,
    this.moneda = 'ARS',
    required this.fecha,
    this.descripcion,
    required this.metodoPagoId,
    this.donante,
    this.donanteEmail,
    this.donanteTelefono,
    this.donanteUsuarioId,
    required this.categoriaId,
    this.proyectoId,
    this.itemProyectoId,
    this.recurrente = false,
    this.frecuenciaId,
    this.proximaFecha,
    required this.usuarioId,
    this.comprobante,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'monto': monto,
      'moneda': moneda,
      'fecha': Timestamp.fromDate(fecha),
      'descripcion': descripcion,
      'metodoPagoId': metodoPagoId,
      'donante': donante,
      'donanteEmail': donanteEmail,
      'donanteTelefono': donanteTelefono,
      'donanteUsuarioId': donanteUsuarioId,
      'categoriaId': categoriaId,
      'proyectoId': proyectoId,
      'itemProyectoId': itemProyectoId,
      'recurrente': recurrente,
      'frecuenciaId': frecuenciaId,
      'proximaFecha':
          proximaFecha != null ? Timestamp.fromDate(proximaFecha!) : null,
      'usuarioId': usuarioId,
      'comprobante': comprobante,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
    };
  }

  factory Ingreso.fromMap(Map<String, dynamic> map, String id) {
    return Ingreso(
      id: id,
      monto: (map['monto'] as num).toDouble(),
      moneda: map['moneda'] as String? ?? 'ARS',
      fecha: (map['fecha'] as Timestamp).toDate(),
      descripcion: map['descripcion'] as String?,
      metodoPagoId: map['metodoPagoId'] as String,
      donante: map['donante'] as String?,
      donanteEmail: map['donanteEmail'] as String?,
      donanteTelefono: map['donanteTelefono'] as String?,
      donanteUsuarioId: map['donanteUsuarioId'] as String?,
      categoriaId: map['categoriaId'] as String,
      proyectoId: map['proyectoId'] as String?,
      itemProyectoId: map['itemProyectoId'] as String?,
      recurrente: map['recurrente'] as bool? ?? false,
      frecuenciaId: map['frecuenciaId'] as String?,
      proximaFecha: map['proximaFecha'] != null
          ? (map['proximaFecha'] as Timestamp).toDate()
          : null,
      usuarioId: map['usuarioId'] as String,
      comprobante: map['comprobante'] as String?,
      fechaCreacion: (map['fechaCreacion'] as Timestamp).toDate(),
    );
  }

  Ingreso copyWith({
    String? id,
    double? monto,
    String? moneda,
    DateTime? fecha,
    Object? descripcion = _unset,
    String? metodoPagoId,
    Object? donante = _unset,
    Object? donanteEmail = _unset,
    Object? donanteTelefono = _unset,
    Object? donanteUsuarioId = _unset,
    String? categoriaId,
    Object? proyectoId = _unset,
    Object? itemProyectoId = _unset,
    bool? recurrente,
    Object? frecuenciaId = _unset,
    Object? proximaFecha = _unset,
    String? usuarioId,
    Object? comprobante = _unset,
    DateTime? fechaCreacion,
  }) {
    return Ingreso(
      id: id ?? this.id,
      monto: monto ?? this.monto,
      moneda: moneda ?? this.moneda,
      fecha: fecha ?? this.fecha,
      descripcion:
          descripcion == _unset ? this.descripcion : descripcion as String?,
      metodoPagoId: metodoPagoId ?? this.metodoPagoId,
      donante: donante == _unset ? this.donante : donante as String?,
      donanteEmail:
          donanteEmail == _unset ? this.donanteEmail : donanteEmail as String?,
      donanteTelefono: donanteTelefono == _unset
          ? this.donanteTelefono
          : donanteTelefono as String?,
      donanteUsuarioId: donanteUsuarioId == _unset
          ? this.donanteUsuarioId
          : donanteUsuarioId as String?,
      categoriaId: categoriaId ?? this.categoriaId,
      proyectoId:
          proyectoId == _unset ? this.proyectoId : proyectoId as String?,
      itemProyectoId: itemProyectoId == _unset
          ? this.itemProyectoId
          : itemProyectoId as String?,
      recurrente: recurrente ?? this.recurrente,
      frecuenciaId:
          frecuenciaId == _unset ? this.frecuenciaId : frecuenciaId as String?,
      proximaFecha: proximaFecha == _unset
          ? this.proximaFecha
          : proximaFecha as DateTime?,
      usuarioId: usuarioId ?? this.usuarioId,
      comprobante:
          comprobante == _unset ? this.comprobante : comprobante as String?,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }
}
