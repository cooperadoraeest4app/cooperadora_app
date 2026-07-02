import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/persona.dart';

class PersonaRepository {
  final _col = FirebaseFirestore.instance.collection('personas');

  Stream<List<Persona>> obtenerTodas() {
    return _col.snapshots().map(
          (s) => s.docs.map((d) => Persona.fromMap(d.data(), d.id)).toList(),
        );
  }

  Future<Persona?> obtenerPorId(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Persona.fromMap(doc.data()!, doc.id);
  }

  Future<String> agregar(Persona persona) async {
    final ref = await _col.add(persona.toMap());
    return ref.id;
  }

  Future<void> actualizar(Persona persona) =>
      _col.doc(persona.id).update(persona.toMap());
}
