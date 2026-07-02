import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/curso.dart';

class CursoRepository {
  final _col = FirebaseFirestore.instance.collection('cursos');

  Stream<List<Curso>> obtenerTodos() {
    return _col.snapshots().map((s) {
      final list = s.docs.map((d) => Curso.fromMap(d.data(), d.id)).toList()
        ..sort((a, b) {
          if (a.orden != null && b.orden != null) {
            return a.orden!.compareTo(b.orden!);
          }
          if (a.orden != null) return -1;
          if (b.orden != null) return 1;
          return a.nombre.compareTo(b.nombre);
        });
      return list;
    });
  }

  Stream<List<Curso>> obtenerActivos() {
    return _col.where('activo', isEqualTo: true).snapshots().map((s) {
      final list = s.docs.map((d) => Curso.fromMap(d.data(), d.id)).toList()
        ..sort((a, b) {
          if (a.orden != null && b.orden != null) {
            return a.orden!.compareTo(b.orden!);
          }
          if (a.orden != null) return -1;
          if (b.orden != null) return 1;
          return a.nombre.compareTo(b.nombre);
        });
      return list;
    });
  }

  Future<void> agregar(Curso curso) => _col.add(curso.toMap());

  Future<void> actualizar(Curso curso) =>
      _col.doc(curso.id).update(curso.toMap());

  Future<void> activarDesactivar(String id, bool activo) =>
      _col.doc(id).update({'activo': activo});
}
