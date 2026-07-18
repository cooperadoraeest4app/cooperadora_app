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
    final snap = await _col.get();
    // Build set of existing (numero_turno) combinations to avoid duplicates
    final existentes = <String>{
      for (final doc in snap.docs)
        '${doc.data()['numero']}_${doc.data()['turno']}',
    };

    final batch = FirebaseFirestore.instance.batch();
    var hayNuevos = false;
    for (final numero in ['1', '2', '3', '4', '5', '6']) {
      for (final turno in ['manana', 'tarde']) {
        if (existentes.contains('${numero}_$turno')) continue;
        final curso = Curso.crear(numero: numero, turno: turno);
        // Use fixed ID so future calls remain idempotent
        batch.set(_col.doc('${numero}_$turno'), curso.toMap());
        hayNuevos = true;
      }
    }
    if (hayNuevos) await batch.commit();
  }
}
