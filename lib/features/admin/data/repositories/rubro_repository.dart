import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/rubro.dart';

class RubroRepository {
  final _col = FirebaseFirestore.instance.collection('rubros');

  Stream<List<Rubro>> obtenerTodos() {
    return _col.orderBy('orden').snapshots().map(
          (s) => s.docs.map((d) => Rubro.fromMap(d.data(), d.id)).toList(),
        );
  }

  Future<List<Rubro>> obtenerTodosUnaVez() async {
    final s = await _col.orderBy('orden').get();
    return s.docs.map((d) => Rubro.fromMap(d.data(), d.id)).toList();
  }

  Future<void> crear(Map<String, dynamic> datos) =>
      _col.add({...datos, 'fechaCreacion': FieldValue.serverTimestamp()});

  Future<void> actualizar(String id, Map<String, dynamic> datos) =>
      _col.doc(id).update(datos);

  Future<void> activarDesactivar(String id, bool activo) =>
      _col.doc(id).update({'activo': activo});

  Future<bool> estaVacia() async => (await _col.limit(1).get()).docs.isEmpty;

  Future<bool> tieneCategorias(String rubroId) async {
    final snap = await FirebaseFirestore.instance
        .collection('categorias')
        .where('rubroId', isEqualTo: rubroId)
        .where('activa', isEqualTo: true)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> inicializarDatosDefault() async {
    if (!(await estaVacia())) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final rubro in _kDefaultRubros) {
      batch.set(
        _col.doc(rubro['id'] as String),
        {
          ...rubro,
          'fechaCreacion': Timestamp.now(),
        }..remove('id'),
      );
    }
    await batch.commit();
  }

  // IDs fijos para que las categorías puedan referenciarlos de forma determinista
  static const _kDefaultRubros = <Map<String, dynamic>>[
    {
      'id': 'rubro_recursos_propios',
      'nombre': 'Recursos Propios',
      'tipo': 'ingreso',
      'orden': 1,
      'activo': true,
      'esPredeterminado': true,
    },
    {
      'id': 'rubro_recursos_oficiales',
      'nombre': 'Recursos Oficiales',
      'tipo': 'ingreso',
      'orden': 2,
      'activo': true,
      'esPredeterminado': true,
    },
    {
      'id': 'rubro_otros_ingresos',
      'nombre': 'Otros ingresos/subsidios',
      'tipo': 'ingreso',
      'orden': 3,
      'activo': true,
      'esPredeterminado': true,
    },
    {
      'id': 'rubro_gastos_alumnos',
      'nombre': 'Gastos para el/la alumno/a',
      'tipo': 'gasto',
      'orden': 1,
      'activo': true,
      'esPredeterminado': true,
    },
    {
      'id': 'rubro_gastos_escuela',
      'nombre': 'Gastos para la escuela',
      'tipo': 'gasto',
      'orden': 2,
      'activo': true,
      'esPredeterminado': true,
    },
    {
      'id': 'rubro_gastos_entidad',
      'nombre': 'Gastos propios de la entidad',
      'tipo': 'gasto',
      'orden': 3,
      'activo': true,
      'esPredeterminado': true,
    },
  ];
}
