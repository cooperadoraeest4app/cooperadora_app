import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/votacion_repository.dart';
import '../../domain/models/votacion.dart';
import '../../domain/models/voto.dart';

class VotacionProvider extends ChangeNotifier {
  final _repo = VotacionRepository();

  Votacion? _votacionActual;
  Votacion? get votacionActual => _votacionActual;

  StreamSubscription<Votacion?>? _sub;
  String? _objetoIdActual;

  void cargar(String objetoId, String tipo) {
    if (_objetoIdActual == objetoId) return;
    _objetoIdActual = objetoId;
    _votacionActual = null;
    _sub?.cancel();
    _sub = _repo
        .obtenerPorObjeto(objetoId, tipo)
        .handleError((e) => debugPrint('[VotacionStream] ERROR: $e'))
        .listen((v) {
      _votacionActual = v;
      notifyListeners();
    });
  }

  Future<String> crear(Votacion votacion) => _repo.crear(votacion);

  Future<void> emitirVoto(Voto voto, Votacion votacion) =>
      _repo.emitirVoto(voto, votacion);

  Future<Votacion?> obtenerPorObjetoFuture(String objetoId, String tipo) =>
      _repo.obtenerPorObjetoFuture(objetoId, tipo);

  Future<Voto?> obtenerMiVoto(String votacionId, String socioId) =>
      _repo.obtenerMiVoto(votacionId, socioId);

  Future<Voto?> obtenerMiVotoPorObjeto(String objetoId, String socioId) =>
      _repo.obtenerMiVotoPorObjeto(objetoId, socioId);

  Future<int> calcularQuorum() => _repo.calcularQuorum();

  Future<double> calcularMayoriaRequerida() => _repo.calcularMayoriaRequerida();

  Stream<List<Voto>> obtenerVotos(String votacionId) =>
      _repo.obtenerVotos(votacionId);

  void limpiar() {
    _sub?.cancel();
    _sub = null;
    _objetoIdActual = null;
    _votacionActual = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
