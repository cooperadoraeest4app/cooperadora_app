class Curso {
  final String id;
  final String numero; // '1' al '6'
  final String turno; // 'manana' / 'tarde'
  final String nombre; // '1° 1 (Mañana)' — generado automáticamente
  final int orden; // (numero * 10) + turno offset
  final bool activo;

  const Curso({
    required this.id,
    required this.numero,
    required this.turno,
    required this.nombre,
    required this.orden,
    required this.activo,
  });

  factory Curso.crear({
    required String numero,
    required String turno,
    bool activo = true,
  }) {
    final turnoNombre = turno == 'manana' ? 'Mañana' : 'Tarde';
    final turnoNum = turno == 'manana' ? '1' : '2';
    final nombreGenerado = '$numero° $turnoNum ($turnoNombre)';
    final ordenCalculado =
        (int.parse(numero) * 10) + (turno == 'manana' ? 1 : 2);
    return Curso(
      id: '',
      numero: numero,
      turno: turno,
      nombre: nombreGenerado,
      orden: ordenCalculado,
      activo: activo,
    );
  }

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'turno': turno,
        'nombre': nombre,
        'orden': orden,
        'activo': activo,
      };

  factory Curso.fromMap(Map<String, dynamic> map, String id) => Curso(
        id: id,
        numero: map['numero'] as String? ?? '',
        turno: map['turno'] as String? ?? 'manana',
        nombre: map['nombre'] as String? ?? '',
        orden: (map['orden'] as num? ?? 0).toInt(),
        activo: map['activo'] as bool? ?? true,
      );

  Curso copyWith({
    String? numero,
    String? turno,
    String? nombre,
    int? orden,
    bool? activo,
  }) =>
      Curso(
        id: id,
        numero: numero ?? this.numero,
        turno: turno ?? this.turno,
        nombre: nombre ?? this.nombre,
        orden: orden ?? this.orden,
        activo: activo ?? this.activo,
      );
}
