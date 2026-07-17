import 'dart:math' show max;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/votacion.dart';
import '../../domain/models/voto.dart';

class VotacionRepository {
  final _col = FirebaseFirestore.instance.collection('votaciones');
  final _colVotos = FirebaseFirestore.instance.collection('votos');

  /// Stream de la votación más reciente para un objeto (sin índice compuesto).
  Stream<Votacion?> obtenerPorObjeto(String objetoId, String tipo) {
    return _col
        .where('objetoId', isEqualTo: objetoId)
        .where('tipo', isEqualTo: tipo)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final sorted = snap.docs.toList()
        ..sort((a, b) {
          final ta = a.data()['fechaCreacion'];
          final tb = b.data()['fechaCreacion'];
          if (ta == null || tb == null) return 0;
          return (tb as Timestamp).compareTo(ta as Timestamp);
        });
      return Votacion.fromMap(sorted.first.data(), sorted.first.id);
    });
  }

  /// Fetch puntual de la votación más reciente para un objeto.
  Future<Votacion?> obtenerPorObjetoFuture(String objetoId, String tipo) async {
    final snap = await _col
        .where('objetoId', isEqualTo: objetoId)
        .where('tipo', isEqualTo: tipo)
        .get();
    if (snap.docs.isEmpty) return null;
    final sorted = snap.docs.toList()
      ..sort((a, b) {
        final ta = a.data()['fechaCreacion'];
        final tb = b.data()['fechaCreacion'];
        if (ta == null || tb == null) return 0;
        return (tb as Timestamp).compareTo(ta as Timestamp);
      });
    return Votacion.fromMap(sorted.first.data(), sorted.first.id);
  }

  Future<String> crear(Votacion votacion) async {
    final ref = await _col.add(votacion.toMap());
    return ref.id;
  }

  /// Guarda el voto y recalcula el estado de la votación.
  /// valor esperado: 'a_favor' | 'en_contra' | 'abstencion'
  Future<void> emitirVoto(Voto voto, Votacion votacion) async {
    await _colVotos.add(voto.toMap());

    final snap = await _colVotos
        .where('votacionId', isEqualTo: votacion.id)
        .get();
    final todos = snap.docs.map((d) => Voto.fromMap(d.data(), d.id)).toList();
    final activos = todos.where((v) => v.tipoSocio == 'activo').toList();

    final quorumRequerido = await calcularQuorum();
    final mayoriaRequerida = await calcularMayoriaRequerida();

    debugPrint('[Votacion] quorumRequerido (config): $quorumRequerido');
    debugPrint('[Votacion] mayoriaRequerida (config): $mayoriaRequerida');
    debugPrint('[Votacion] votosActivos (tipoSocio==activo): ${activos.length}');
    debugPrint('[Votacion] todos los votos de esta votacion: ${todos.length}');
    debugPrint('[Votacion] tiposSocio encontrados: ${todos.map((v) => v.tipoSocio).toList()}');

    if (activos.length < quorumRequerido) {
      debugPrint('[Votacion] quorum NO alcanzado — se necesitan $quorumRequerido, hay ${activos.length}');
      return;
    }

    final aFavor = activos.where((v) => v.valor == 'a_favor').length;
    final enContra = activos.where((v) => v.valor == 'en_contra').length;
    final efectivos = aFavor + enContra;

    debugPrint('[Votacion] aFavor: $aFavor  enContra: $enContra  abstenciones: ${activos.length - efectivos}');

    if (efectivos == 0) {
      debugPrint('[Votacion] efectivos == 0, no se calcula resultado');
      return;
    }

    final porcentaje = aFavor / efectivos * 100;
    final estado = porcentaje >= mayoriaRequerida ? 'aprobada' : 'rechazada';
    debugPrint('[Votacion] porcentajeAFavor: ${porcentaje.toStringAsFixed(1)}%  mayoriaRequerida: $mayoriaRequerida%  estadoCalculado: $estado');

    await _col.doc(votacion.id).update({
      'estado': estado,
      'fechaCierre': FieldValue.serverTimestamp(),
    });

    if (estado == 'aprobada' && votacion.tipo == 'presupuesto') {
      await _actualizarItemsAlAprobar(presupuestoId: votacion.objetoId);
    }
  }

  Stream<List<Voto>> obtenerVotos(String votacionId) {
    return _colVotos
        .where('votacionId', isEqualTo: votacionId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Voto.fromMap(d.data(), d.id)).toList());
  }

  Future<Voto?> obtenerMiVoto(String votacionId, String socioId) async {
    final snap = await _colVotos
        .where('votacionId', isEqualTo: votacionId)
        .where('socioId', isEqualTo: socioId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Voto.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  /// Busca el voto de un socio por presupuesto (objetoId), sin necesitar votacionId.
  Future<Voto?> obtenerMiVotoPorObjeto(String objetoId, String socioId) async {
    final snap = await _colVotos
        .where('objetoId', isEqualTo: objetoId)
        .where('socioId', isEqualTo: socioId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Voto.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  /// Recalcula el estado de una votación según los votos actuales y los umbrales dados.
  Future<String> calcularEstadoDinamico({
    required String votacionId,
    required int quorumRequerido,
    required double mayoriaRequerida,
  }) async {
    final snap = await _colVotos
        .where('votacionId', isEqualTo: votacionId)
        .get();
    final votos = snap.docs.map((d) => Voto.fromMap(d.data(), d.id)).toList();
    final votosActivos = votos.where((v) => v.tipoSocio == 'activo').toList();

    if (votosActivos.length < quorumRequerido) return 'en_curso';

    final aFavor = votosActivos.where((v) => v.valor == 'a_favor').length;
    final porcentaje = aFavor / votosActivos.length * 100;
    return porcentaje >= mayoriaRequerida ? 'aprobada' : 'rechazada';
  }

  /// Calcula el quórum requerido leyendo la configuración de Firestore.
  /// En modo testing devuelve 1.
  Future<int> calcularQuorum() async {
    final snap = await FirebaseFirestore.instance
        .collection('configuracion')
        .doc('config')
        .get();
    final data = snap.data() ?? {};
    if (data['modoTesting'] as bool? ?? false) return 1;

    final porcentajeCD = ((data['quorumPorcentajeCD'] as num?) ?? 30) / 100;
    final multiplicador = ((data['quorumMultiplicadorSocios'] as num?) ?? 3).toInt();
    final piso = ((data['quorumPisoSociosDirecta'] as num?) ?? 15).toInt();

    final totalCD = await _contarMiembrosCD();
    final miembrosCD = (totalCD * porcentajeCD).ceil();
    return max(piso, miembrosCD * multiplicador);
  }

  /// Devuelve el porcentaje de mayoría requerida. En modo testing devuelve 50.0.
  Future<double> calcularMayoriaRequerida() async {
    final snap = await FirebaseFirestore.instance
        .collection('configuracion')
        .doc('config')
        .get();
    final data = snap.data() ?? {};
    if (data['modoTesting'] as bool? ?? false) return 50.0;
    return ((data['mayoriaRequerida'] as num?) ?? 66.67).toDouble();
  }

  Future<void> _actualizarItemsAlAprobar({required String presupuestoId}) async {
    final presSnap = await FirebaseFirestore.instance
        .collection('presupuestos_proyecto')
        .doc(presupuestoId)
        .get();
    final proyectoId = presSnap.data()?['proyectoId'] as String?;
    if (proyectoId == null) return;

    final itemsSnap = await FirebaseFirestore.instance
        .collection('items_proyecto')
        .where('proyectoId', isEqualTo: proyectoId)
        .where('presupuestosIds', arrayContains: presupuestoId)
        .get();
    if (itemsSnap.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in itemsSnap.docs) {
      final estadoActual = doc.data()['estado'] as String? ?? 'pendiente';
      if (estadoActual == 'comprado') continue;
      batch.update(doc.reference, {
        'estado': 'presupuestos_aprobados',
        'estadoAnterior': estadoActual,
        'presupuestoAprobadoId': presupuestoId,
      });
    }
    await batch.commit();
  }

  Future<int> _contarMiembrosCD() async {
    final snap = await FirebaseFirestore.instance
        .collection('cargos')
        .where('personaId', isNotEqualTo: null)
        .get();
    return snap.docs
        .where((d) => (d.data()['personaId'] as String?)?.isNotEmpty == true)
        .length;
  }
}
