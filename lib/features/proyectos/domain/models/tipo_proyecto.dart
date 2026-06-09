class TipoProyecto {
  final String id;
  final String nombre;
  final int orden;
  final bool activo;

  const TipoProyecto({
    required this.id,
    required this.nombre,
    required this.orden,
    required this.activo,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'orden': orden,
        'activo': activo,
      };

  factory TipoProyecto.fromMap(Map<String, dynamic> map, String id) =>
      TipoProyecto(
        id: id,
        nombre: map['nombre'] as String? ?? '',
        orden: (map['orden'] as num? ?? 0).toInt(),
        activo: map['activo'] as bool? ?? true,
      );
}
