import 'package:flutter/foundation.dart';
import '../../data/repositories/cargo_repository.dart';

class CargoProvider extends ChangeNotifier {
  final _repo = CargoRepository();

  List<Map<String, dynamic>> cargos = [];
  bool isLoading = true;

  // Stream cacheado: se crea una sola vez. Si fuera un getter sin late final,
  // cada rebuild crearía un objeto Stream distinto y el StreamBuilder reiniciaría.
  late final Stream<List<Map<String, dynamic>>> cargoStream =
      _repo.obtenerTodos();

  CargoProvider() {
    // Solo escucha el stream. NO llama a inicializarDatosDefault() aquí
    // porque el provider se crea antes de que Firebase Auth esté listo,
    // por lo que la escritura fallará con permission-denied.
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

  // Llamar desde pantallas donde el usuario YA está autenticado como admin.
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
