import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/curso.dart';

class CursoRepository {
  final _col = FirebaseFirestore.instance.collection('cursos');

  Stream<List<Curso>> obtenerTodos() {
    return _col.orderBy('orden').snapshots().map(
        (s) => s.docs.map((d) => Curso.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<Curso>> obtenerActivos() {
    return _col
        .where('activo', isEqualTo: true)
        .orderBy('orden')
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Curso.fromMap(d.data(), d.id)).toList());
  }

  Future<void> activarDesactivar(String id, bool activo) =>
      _col.doc(id).update({'activo': activo});

  Future<void> actualizar(Curso curso) =>
      _col.doc(curso.id).update(curso.toMap());

  Future<void> inicializarDatosDefault() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final numero in ['1', '2', '3', '4', '5', '6']) {
      for (final turno in ['manana', 'tarde']) {
        final curso = Curso.crear(numero: numero, turno: turno);
        final ref = _col.doc();
        batch.set(ref, curso.toMap());
      }
    }
    await batch.commit();
  }
}
