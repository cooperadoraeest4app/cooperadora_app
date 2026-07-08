class Rubro {
  final String id;
  final String nombre;
  final String tipo; // 'ingreso' | 'gasto'
  final int orden;
  final bool activo;
  final bool esPredeterminado;

  const Rubro({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.orden = 0,
    this.activo = true,
    this.esPredeterminado = false,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'tipo': tipo,
        'orden': orden,
        'activo': activo,
        'esPredeterminado': esPredeterminado,
      };

  factory Rubro.fromMap(Map<String, dynamic> map, String id) => Rubro(
        id: id,
        nombre: map['nombre'] as String? ?? '',
        tipo: map['tipo'] as String? ?? 'ingreso',
        orden: map['orden'] as int? ?? 0,
        activo: map['activo'] as bool? ?? true,
        esPredeterminado: map['esPredeterminado'] as bool? ?? false,
      );
}
