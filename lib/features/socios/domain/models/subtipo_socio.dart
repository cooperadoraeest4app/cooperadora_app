class SubtipoSocio {
  final String id;
  final String nombre;
  final List<String> aplicaA; // lista de tipoSocioId
  final int orden;
  final bool activo;

  const SubtipoSocio({
    required this.id,
    required this.nombre,
    required this.aplicaA,
    required this.orden,
    required this.activo,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'aplicaA': aplicaA,
        'orden': orden,
        'activo': activo,
      };

  factory SubtipoSocio.fromMap(Map<String, dynamic> map, String id) =>
      SubtipoSocio(
        id: id,
        nombre: map['nombre'] as String? ?? '',
        aplicaA: (map['aplicaA'] as List<dynamic>?)?.cast<String>() ?? [],
        orden: (map['orden'] as num? ?? 0).toInt(),
        activo: map['activo'] as bool? ?? true,
      );
}
