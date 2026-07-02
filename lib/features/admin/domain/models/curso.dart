class Curso {
  static const _unset = Object();

  final String id;
  final String nombre;
  final String? nivel;
  final int? orden;
  final bool activo;

  const Curso({
    required this.id,
    required this.nombre,
    this.nivel,
    this.orden,
    required this.activo,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        if (nivel != null) 'nivel': nivel,
        if (orden != null) 'orden': orden,
        'activo': activo,
      };

  factory Curso.fromMap(Map<String, dynamic> map, String id) => Curso(
        id: id,
        nombre: map['nombre'] as String? ?? '',
        nivel: map['nivel'] as String?,
        orden: (map['orden'] as num?)?.toInt(),
        activo: map['activo'] as bool? ?? true,
      );

  Curso copyWith({
    String? nombre,
    Object? nivel = _unset,
    Object? orden = _unset,
    bool? activo,
  }) {
    return Curso(
      id: id,
      nombre: nombre ?? this.nombre,
      nivel: nivel == _unset ? this.nivel : nivel as String?,
      orden: orden == _unset ? this.orden : orden as int?,
      activo: activo ?? this.activo,
    );
  }
}
