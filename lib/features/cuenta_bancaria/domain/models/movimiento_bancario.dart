import 'package:cloud_firestore/cloud_firestore.dart';

const _unsetMov = Object();

class MovimientoBancario {
  final String id;
  final String tipo;
  final double? saldoAnterior;
  final double? saldoNuevo;
  final String? periodo;
  final String? archivo;
  final String? observaciones;
  final String usuarioId;
  final DateTime fechaCreacion;
  final String? tipoOrigen;
  final bool? confirmado;
  final String? usuarioConfirmacionId;
  final DateTime? fechaConfirmacion;

  const MovimientoBancario({
    required this.id,
    required this.tipo,
    this.saldoAnterior,
    this.saldoNuevo,
    this.periodo,
    this.archivo,
    this.observaciones,
    required this.usuarioId,
    required this.fechaCreacion,
    this.tipoOrigen,
    this.confirmado,
    this.usuarioConfirmacionId,
    this.fechaConfirmacion,
  });

  Map<String, dynamic> toMap() => {
        'tipo': tipo,
        'saldoAnterior': saldoAnterior,
        'saldoNuevo': saldoNuevo,
        'periodo': periodo,
        'archivo': archivo,
        'observaciones': observaciones,
        'usuarioId': usuarioId,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      };

  factory MovimientoBancario.fromMap(Map<String, dynamic> map, String id) =>
      MovimientoBancario(
        id: id,
        tipo: map['tipo'] as String? ?? '',
        saldoAnterior: (map['saldoAnterior'] as num?)?.toDouble(),
        saldoNuevo: (map['saldoNuevo'] as num?)?.toDouble(),
        periodo: map['periodo'] as String?,
        archivo: map['archivo'] as String?,
        observaciones: map['observaciones'] as String?,
        usuarioId: map['usuarioId'] as String? ?? '',
        fechaCreacion: map['fechaCreacion'] != null
            ? (map['fechaCreacion'] as Timestamp).toDate()
            : DateTime.now(),
        tipoOrigen: map['tipo_origen'] as String?,
        confirmado: map['confirmado'] as bool?,
        usuarioConfirmacionId: map['usuarioConfirmacionId'] as String?,
        fechaConfirmacion: map['fechaConfirmacion'] != null
            ? (map['fechaConfirmacion'] as Timestamp).toDate()
            : null,
      );

  MovimientoBancario copyWith({
    String? tipo,
    Object? saldoAnterior = _unsetMov,
    Object? saldoNuevo = _unsetMov,
    Object? periodo = _unsetMov,
    Object? archivo = _unsetMov,
    Object? observaciones = _unsetMov,
    String? usuarioId,
    DateTime? fechaCreacion,
    Object? tipoOrigen = _unsetMov,
    Object? confirmado = _unsetMov,
    Object? usuarioConfirmacionId = _unsetMov,
    Object? fechaConfirmacion = _unsetMov,
  }) =>
      MovimientoBancario(
        id: id,
        tipo: tipo ?? this.tipo,
        saldoAnterior: saldoAnterior == _unsetMov
            ? this.saldoAnterior
            : saldoAnterior as double?,
        saldoNuevo:
            saldoNuevo == _unsetMov ? this.saldoNuevo : saldoNuevo as double?,
        periodo: periodo == _unsetMov ? this.periodo : periodo as String?,
        archivo: archivo == _unsetMov ? this.archivo : archivo as String?,
        observaciones: observaciones == _unsetMov
            ? this.observaciones
            : observaciones as String?,
        usuarioId: usuarioId ?? this.usuarioId,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
        tipoOrigen:
            tipoOrigen == _unsetMov ? this.tipoOrigen : tipoOrigen as String?,
        confirmado:
            confirmado == _unsetMov ? this.confirmado : confirmado as bool?,
        usuarioConfirmacionId: usuarioConfirmacionId == _unsetMov
            ? this.usuarioConfirmacionId
            : usuarioConfirmacionId as String?,
        fechaConfirmacion: fechaConfirmacion == _unsetMov
            ? this.fechaConfirmacion
            : fechaConfirmacion as DateTime?,
      );
}
