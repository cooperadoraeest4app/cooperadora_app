import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/proyecto.dart';
import '../../domain/models/tipo_proyecto.dart';

class ProyectoRepository {
  final _col = FirebaseFirestore.instance.collection('proyectos');
  final _tiposCol = FirebaseFirestore.instance.collection('tipos_proyecto');

  Stream<List<Proyecto>> obtenerPorEstado(String estado) {
    return _col
        .where('estado', isEqualTo: estado)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => Proyecto.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
          return list;
        });
  }

  Future<void> agregar(Proyecto p) => _col.add(p.toMap());

  Future<void> actualizar(Proyecto p) => _col.doc(p.id).update(p.toMap());

  Future<void> eliminar(String id) => _col.doc(id).delete();

  Stream<List<TipoProyecto>> obtenerTipos() {
    return _tiposCol
        .orderBy('orden')
        .snapshots()
        .map((s) => s.docs
            .map((d) => TipoProyecto.fromMap(d.data(), d.id))
            .where((t) => t.activo)
            .toList());
  }

  Future<void> inicializarTiposDefault() async {
    final snap = await _tiposCol.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final defaults = [
      {'nombre': 'Evento', 'orden': 1, 'activo': true},
      {'nombre': 'Infraestructura', 'orden': 2, 'activo': true},
      {'nombre': 'Viaje de Estudios', 'orden': 3, 'activo': true},
      {'nombre': 'Equipamiento', 'orden': 4, 'activo': true},
      {'nombre': 'Otros', 'orden': 5, 'activo': true},
    ];
    for (final d in defaults) {
      batch.set(_tiposCol.doc(), d);
    }
    await batch.commit();
  }
}
