import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FrecuenciaRecurrencia {
  final String id;
  final String nombre;
  final int diasIntervalo;

  const FrecuenciaRecurrencia({
    required this.id,
    required this.nombre,
    required this.diasIntervalo,
  });

  factory FrecuenciaRecurrencia.fromMap(Map<String, dynamic> map, String id) =>
      FrecuenciaRecurrencia(
        id: id,
        nombre: map['nombre'] as String? ?? '',
        diasIntervalo: (map['diasIntervalo'] as num? ?? 30).toInt(),
      );
}

class FrecuenciaProvider extends ChangeNotifier {
  final _col =
      FirebaseFirestore.instance.collection('frecuencias_recurrencia');
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  List<FrecuenciaRecurrencia> _frecuencias = [];

  List<FrecuenciaRecurrencia> get frecuencias => _frecuencias;

  FrecuenciaProvider() {
    _init();
  }

  Future<void> _init() async {
    await _inicializarDefaults();
    _sub = _col.orderBy('orden').snapshots().listen((snap) {
      _frecuencias = snap.docs
          .map((d) => FrecuenciaRecurrencia.fromMap(d.data(), d.id))
          .toList();
      notifyListeners();
    });
  }

  Future<void> _inicializarDefaults() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    const defaults = [
      {'nombre': 'Semanal', 'diasIntervalo': 7, 'orden': 1},
      {'nombre': 'Quincenal', 'diasIntervalo': 15, 'orden': 2},
      {'nombre': 'Mensual', 'diasIntervalo': 30, 'orden': 3},
      {'nombre': 'Bimestral', 'diasIntervalo': 60, 'orden': 4},
      {'nombre': 'Trimestral', 'diasIntervalo': 90, 'orden': 5},
      {'nombre': 'Anual', 'diasIntervalo': 365, 'orden': 6},
    ];

    final batch = FirebaseFirestore.instance.batch();
    for (final d in defaults) {
      batch.set(_col.doc(), d);
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
