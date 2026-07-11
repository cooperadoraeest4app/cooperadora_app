import 'package:flutter/foundation.dart';
import '../../data/repositories/cargo_repository.dart';

class CargoProvider extends ChangeNotifier {
  final _repo = CargoRepository();

  List<Map<String, dynamic>> cargos = [];
  bool isLoading = true;
  bool _cargado = false;
  bool get cargado => _cargado;

  CargoProvider() {
    _repo.obtenerTodos().listen(
      (lista) {
        cargos = lista;
        _cargado = true;
        isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> inicializarSiVacio() async {
    try {
      await _repo.inicializarDatosDefault();
    } catch (e) {
      debugPrint('[CargoProvider] inicializarSiVacio error: $e');
    }
  }

  Future<void> asignarPersona(String cargoId, String? personaId) =>
      _repo.asignarPersona(cargoId, personaId);
}
