import 'package:cloud_firestore/cloud_firestore.dart';

const _unset = Object();

class Gasto {
  final String id;
  final double monto;
  final String moneda;
  final DateTime fecha;
  final String? descripcion;
  final String metodoPagoId;
  final String categoriaId;
  final String? proyectoId;
  final String? itemProyectoId;
  final bool recurrente;
  final String? frecuenciaId;
  final DateTime? proximaFecha;
  final String usuarioId;
  final String? comprobante;
  final String? nroComprobante;
  final String? nroCheque;
  final String? presupuestoProyectoId;
  final DateTime fechaCreacion;
  final String? ultimaModificacionPor;
  final DateTime? ultimaModificacionFecha;

  const Gasto({
    required this.id,
    required this.monto,
    this.moneda = 'ARS',
    required this.fecha,
    this.descripcion,
    required this.metodoPagoId,
    required this.categoriaId,
    this.proyectoId,
    this.itemProyectoId,
    this.recurrente = false,
    this.frecuenciaId,
    this.proximaFecha,
    required this.usuarioId,
    this.comprobante,
    this.nroComprobante,
    this.nroCheque,
    this.presupuestoProyectoId,
    required this.fechaCreacion,
    this.ultimaModificacionPor,
    this.ultimaModificacionFecha,
  });

  Map<String, dynamic> toMap() {
    return {
      'monto': monto,
      'moneda': moneda,
      'fecha': Timestamp.fromDate(fecha),
      'descripcion': descripcion,
      'metodoPagoId': metodoPagoId,
      'categoriaId': categoriaId,
      'proyectoId': proyectoId,
      'itemProyectoId': itemProyectoId,
      'recurrente': recurrente,
      'frecuenciaId': frecuenciaId,
      'proximaFecha':
          proximaFecha != null ? Timestamp.fromDate(proximaFecha!) : null,
      'usuarioId': usuarioId,
      'comprobante': comprobante,
      'nroComprobante': nroComprobante,
      'nroCheque': nroCheque,
      'presupuestoProyectoId': presupuestoProyectoId,
      'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      'ultimaModificacionPor': ultimaModificacionPor,
      'ultimaModificacionFecha': ultimaModificacionFecha != null
          ? Timestamp.fromDate(ultimaModificacionFecha!)
          : null,
    };
  }

  factory Gasto.fromMap(Map<String, dynamic> map, String id) {
    return Gasto(
      id: id,
      monto: (map['monto'] as num).toDouble(),
      moneda: map['moneda'] as String? ?? 'ARS',
      fecha: (map['fecha'] as Timestamp).toDate(),
      descripcion: map['descripcion'] as String?,
      metodoPagoId: map['metodoPagoId'] as String,
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
      nroComprobante: map['nroComprobante'] as String?,
      nroCheque: map['nroCheque'] as String?,
      presupuestoProyectoId: map['presupuestoProyectoId'] as String?,
      fechaCreacion: (map['fechaCreacion'] as Timestamp).toDate(),
      ultimaModificacionPor: map['ultimaModificacionPor'] as String?,
      ultimaModificacionFecha: map['ultimaModificacionFecha'] != null
          ? (map['ultimaModificacionFecha'] as Timestamp).toDate()
          : null,
    );
  }

  Gasto copyWith({
    String? id,
    double? monto,
    String? moneda,
    DateTime? fecha,
    Object? descripcion = _unset,
    String? metodoPagoId,
    String? categoriaId,
    Object? proyectoId = _unset,
    Object? itemProyectoId = _unset,
    bool? recurrente,
    Object? frecuenciaId = _unset,
    Object? proximaFecha = _unset,
    String? usuarioId,
    Object? comprobante = _unset,
    Object? nroComprobante = _unset,
    Object? nroCheque = _unset,
    Object? presupuestoProyectoId = _unset,
    DateTime? fechaCreacion,
    Object? ultimaModificacionPor = _unset,
    Object? ultimaModificacionFecha = _unset,
  }) {
    return Gasto(
      id: id ?? this.id,
      monto: monto ?? this.monto,
      moneda: moneda ?? this.moneda,
      fecha: fecha ?? this.fecha,
      descripcion:
          descripcion == _unset ? this.descripcion : descripcion as String?,
      metodoPagoId: metodoPagoId ?? this.metodoPagoId,
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
      nroComprobante: nroComprobante == _unset
          ? this.nroComprobante
          : nroComprobante as String?,
      nroCheque: nroCheque == _unset ? this.nroCheque : nroCheque as String?,
      presupuestoProyectoId: presupuestoProyectoId == _unset
          ? this.presupuestoProyectoId
          : presupuestoProyectoId as String?,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      ultimaModificacionPor: ultimaModificacionPor == _unset
          ? this.ultimaModificacionPor
          : ultimaModificacionPor as String?,
      ultimaModificacionFecha: ultimaModificacionFecha == _unset
          ? this.ultimaModificacionFecha
          : ultimaModificacionFecha as DateTime?,
    );
  }
}
