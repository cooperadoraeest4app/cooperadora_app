import 'package:cloud_firestore/cloud_firestore.dart';

class BienInventario {
  static const _unset = Object();

  final String id;
  final String codigo; // INV-{año}-{correlativo 3 dígitos}
  final String descripcion;
  final String estado; // bueno / regular / malo / dado_de_baja
  final String tipoAlta; // compra / donacion
  final DateTime fechaAlta;
  final String nroActa;
  final int cantidad;
  final double? valor;
  final String? ubicacion;
  final String? categoriaInventario;
  final String? gastoId;
  final String? ingresoId;
  // Baja
  final DateTime? fechaBaja;
  final String? nroActaBaja;
  final int? cantidadBaja;
  final String? motivoBaja; // venta/deterioro/rotura/robo/donacion/permuta/otro
  final double? valorBaja;
  // Auditoría
  final String usuarioId;
  final DateTime fechaCreacion;
  final String? ultimaModificacionPor;
  final DateTime? ultimaModificacionFecha;

  const BienInventario({
    required this.id,
    required this.codigo,
    required this.descripcion,
    required this.estado,
    required this.tipoAlta,
    required this.fechaAlta,
    required this.nroActa,
    required this.cantidad,
    this.valor,
    this.ubicacion,
    this.categoriaInventario,
    this.gastoId,
    this.ingresoId,
    this.fechaBaja,
    this.nroActaBaja,
    this.cantidadBaja,
    this.motivoBaja,
    this.valorBaja,
    required this.usuarioId,
    required this.fechaCreacion,
    this.ultimaModificacionPor,
    this.ultimaModificacionFecha,
  });

  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'descripcion': descripcion,
        'estado': estado,
        'tipoAlta': tipoAlta,
        'fechaAlta': Timestamp.fromDate(fechaAlta),
        'nroActa': nroActa,
        'cantidad': cantidad,
        if (valor != null) 'valor': valor,
        if (ubicacion != null) 'ubicacion': ubicacion,
        if (categoriaInventario != null)
          'categoriaInventario': categoriaInventario,
        if (gastoId != null) 'gastoId': gastoId,
        if (ingresoId != null) 'ingresoId': ingresoId,
        if (fechaBaja != null) 'fechaBaja': Timestamp.fromDate(fechaBaja!),
        if (nroActaBaja != null) 'nroActaBaja': nroActaBaja,
        if (cantidadBaja != null) 'cantidadBaja': cantidadBaja,
        if (motivoBaja != null) 'motivoBaja': motivoBaja,
        if (valorBaja != null) 'valorBaja': valorBaja,
        'usuarioId': usuarioId,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
        if (ultimaModificacionPor != null)
          'ultimaModificacionPor': ultimaModificacionPor,
        if (ultimaModificacionFecha != null)
          'ultimaModificacionFecha':
              Timestamp.fromDate(ultimaModificacionFecha!),
      };

  factory BienInventario.fromMap(Map<String, dynamic> map, String id) {
    DateTime ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();
    DateTime? tsN(dynamic v) => v is Timestamp ? v.toDate() : null;
    return BienInventario(
      id: id,
      codigo: map['codigo'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      estado: map['estado'] as String? ?? 'bueno',
      tipoAlta: map['tipoAlta'] as String? ?? 'compra',
      fechaAlta: ts(map['fechaAlta']),
      nroActa: map['nroActa'] as String? ?? '',
      cantidad: (map['cantidad'] as num? ?? 1).toInt(),
      valor: (map['valor'] as num?)?.toDouble(),
      ubicacion: map['ubicacion'] as String?,
      categoriaInventario: map['categoriaInventario'] as String?,
      gastoId: map['gastoId'] as String?,
      ingresoId: map['ingresoId'] as String?,
      fechaBaja: tsN(map['fechaBaja']),
      nroActaBaja: map['nroActaBaja'] as String?,
      cantidadBaja: (map['cantidadBaja'] as num?)?.toInt(),
      motivoBaja: map['motivoBaja'] as String?,
      valorBaja: (map['valorBaja'] as num?)?.toDouble(),
      usuarioId: map['usuarioId'] as String? ?? '',
      fechaCreacion: ts(map['fechaCreacion']),
      ultimaModificacionPor: map['ultimaModificacionPor'] as String?,
      ultimaModificacionFecha: tsN(map['ultimaModificacionFecha']),
    );
  }

  BienInventario copyWith({
    String? id,
    String? codigo,
    String? descripcion,
    String? estado,
    String? tipoAlta,
    DateTime? fechaAlta,
    String? nroActa,
    int? cantidad,
    Object? valor = _unset,
    Object? ubicacion = _unset,
    Object? categoriaInventario = _unset,
    Object? gastoId = _unset,
    Object? ingresoId = _unset,
    Object? fechaBaja = _unset,
    Object? nroActaBaja = _unset,
    Object? cantidadBaja = _unset,
    Object? motivoBaja = _unset,
    Object? valorBaja = _unset,
    String? usuarioId,
    DateTime? fechaCreacion,
    Object? ultimaModificacionPor = _unset,
    Object? ultimaModificacionFecha = _unset,
  }) {
    return BienInventario(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      tipoAlta: tipoAlta ?? this.tipoAlta,
      fechaAlta: fechaAlta ?? this.fechaAlta,
      nroActa: nroActa ?? this.nroActa,
      cantidad: cantidad ?? this.cantidad,
      valor: valor == _unset ? this.valor : valor as double?,
      ubicacion: ubicacion == _unset ? this.ubicacion : ubicacion as String?,
      categoriaInventario: categoriaInventario == _unset
          ? this.categoriaInventario
          : categoriaInventario as String?,
      gastoId: gastoId == _unset ? this.gastoId : gastoId as String?,
      ingresoId: ingresoId == _unset ? this.ingresoId : ingresoId as String?,
      fechaBaja: fechaBaja == _unset ? this.fechaBaja : fechaBaja as DateTime?,
      nroActaBaja:
          nroActaBaja == _unset ? this.nroActaBaja : nroActaBaja as String?,
      cantidadBaja: cantidadBaja == _unset
          ? this.cantidadBaja
          : cantidadBaja as int?,
      motivoBaja:
          motivoBaja == _unset ? this.motivoBaja : motivoBaja as String?,
      valorBaja: valorBaja == _unset ? this.valorBaja : valorBaja as double?,
      usuarioId: usuarioId ?? this.usuarioId,
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
