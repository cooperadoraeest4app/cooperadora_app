import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/persona_repository.dart';
import '../../domain/models/persona.dart';

class PersonaProvider extends ChangeNotifier {
  final _repo = PersonaRepository();
  StreamSubscription<List<Persona>>? _sub;

  List<Persona> todas = [];
  bool isLoading = false;
  bool isSaving = false;
  String? error;

  void iniciarSiNecesario() {
    if (_sub != null) return;
    isLoading = true;
    _sub = _repo.obtenerTodas().listen(
      (list) {
        todas = list;
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        error = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );
  }

  void limpiar() {
    _sub?.cancel();
    _sub = null;
    todas = [];
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Persona? porId(String id) {
    try {
      return todas.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  String nombreCompleto(String personaId) {
    if (personaId.isEmpty) return '(sin persona)';
    final p = porId(personaId);
    if (p == null) return isLoading ? '...' : '(no encontrado)';
    return p.nombreCompleto;
  }

  List<Persona> buscar(String query, {String? soloTipo}) {
    Iterable<Persona> base = todas;
    if (soloTipo != null) {
      base = base.where((p) => p.tipoPersona == soloTipo);
    }
    if (query.trim().isEmpty) return base.take(8).toList();
    final q = query.toLowerCase();
    return base.where((p) {
      final nombre = p.nombreCompleto.toLowerCase();
      final dni = p.dni?.toLowerCase() ?? '';
      return nombre.contains(q) || dni.contains(q);
    }).toList();
  }

  Future<String> agregar(Persona persona) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      final id = await _repo.agregar(persona);
      return id;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> actualizar(Persona persona) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      await _repo.actualizar(persona);
    } catch (e) {
      error = e.toString();
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
