import 'package:cloud_firestore/cloud_firestore.dart';

class CargoRepository {
  final _col = FirebaseFirestore.instance.collection('cargos');

  static const _defaults = [
    {'nombre': 'Presidente', 'orden': 1},
    {'nombre': 'Secretaria', 'orden': 2},
    {'nombre': 'Tesorera', 'orden': 3},
    {'nombre': 'Vocal 1', 'orden': 4},
    {'nombre': 'Vocal 2', 'orden': 5},
    {'nombre': 'Vocal 3', 'orden': 6},
    {'nombre': 'Vocal 1 Suplente', 'orden': 7},
    {'nombre': 'Vocal 2 Suplente', 'orden': 8},
    {'nombre': 'Revisora de Cuenta', 'orden': 9},
    {'nombre': 'Profesora Revisora de Cuenta', 'orden': 10},
    {'nombre': 'Revisora de Cuenta Suplente', 'orden': 11},
  ];

  Stream<List<Map<String, dynamic>>> obtenerTodos() => _col
      .orderBy('orden')
      .snapshots()
      .map((s) => s.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList());

  Future<void> asignarPersona(String cargoId, String? personaId) =>
      _col.doc(cargoId).update({'personaId': personaId});

  Future<void> inicializarDatosDefault() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final cargo in _defaults) {
      batch.set(_col.doc(), {...cargo, 'personaId': null});
    }
    await batch.commit();
  }
}
