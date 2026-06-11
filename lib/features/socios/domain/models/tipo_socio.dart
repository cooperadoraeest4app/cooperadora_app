class TipoSocio {
  final String id;
  final String nombre;
  final bool tieneVoto;
  final bool tieneVozConsultiva;
  final bool requiereCuota;
  final int orden;
  final bool activo;

  const TipoSocio({
    required this.id,
    required this.nombre,
    required this.tieneVoto,
    required this.tieneVozConsultiva,
    required this.requiereCuota,
    required this.orden,
    required this.activo,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'tieneVoto': tieneVoto,
        'tieneVozConsultiva': tieneVozConsultiva,
        'requiereCuota': requiereCuota,
        'orden': orden,
        'activo': activo,
      };

  factory TipoSocio.fromMap(Map<String, dynamic> map, String id) =>
      TipoSocio(
        id: id,
        nombre: map['nombre'] as String? ?? '',
        tieneVoto: map['tieneVoto'] as bool? ?? false,
        tieneVozConsultiva: map['tieneVozConsultiva'] as bool? ?? false,
        requiereCuota: map['requiereCuota'] as bool? ?? false,
        orden: (map['orden'] as num? ?? 0).toInt(),
        activo: map['activo'] as bool? ?? true,
      );
}
