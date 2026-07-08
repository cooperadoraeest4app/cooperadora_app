import 'package:flutter/foundation.dart';
import '../../data/repositories/cargo_repository.dart';

class CargoProvider extends ChangeNotifier {
  final _repo = CargoRepository();

  // Lista mantenida por suscripción interna — usada por pantallas que
  // hacen context.watch<CargoProvider>().cargos (ej. perfil_screen).
  List<Map<String, dynamic>> cargos = [];
  bool isLoading = true;

  // Getter: crea un Stream fresco en cada acceso. El StreamBuilder que lo
  // reciba reiniciará la suscripción si el widget se reconstruye, lo que
  // permite el patrón "retry via setState()" sin estado adicional.
  Stream<List<Map<String, dynamic>>> get cargosStream => _repo.obtenerTodos();

  CargoProvider() {
    _repo.obtenerTodos().listen(
      (lista) {
        cargos = lista;
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
