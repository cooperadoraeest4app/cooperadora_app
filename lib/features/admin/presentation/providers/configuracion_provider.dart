import 'package:flutter/foundation.dart';
import '../../data/repositories/configuracion_repository.dart';

class ConfiguracionProvider extends ChangeNotifier {
  final _repo = ConfiguracionRepository();

  String nombreCooperadora = '';
  String nombreEscuela = '';
  String emailContacto = '';
  String telefonoContacto = '';
  int anioLectivo = DateTime.now().year;
  int quorumMinimo = 30;
  int porcentajeAprobacion = 50;

  Map<String, bool> seccionesPublicas = {
    'ingresos': true,
    'proyectos': true,
    'cuentaBancaria': true,
    'resumenesBancarios': true,
    'socios': false,
  };

  bool isLoading = false;
  bool isSaving = false;
  String? error;

  Future<void> cargar() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final datos = await _repo.obtener();
      if (datos != null) {
        nombreCooperadora = datos['nombreCooperadora'] as String? ?? '';
        nombreEscuela = datos['nombreEscuela'] as String? ?? '';
        emailContacto = datos['emailContacto'] as String? ?? '';
        telefonoContacto = datos['telefonoContacto'] as String? ?? '';
        anioLectivo =
            datos['anioLectivo'] as int? ?? DateTime.now().year;
        quorumMinimo = datos['quorumMinimo'] as int? ?? 30;
        porcentajeAprobacion =
            datos['porcentajeAprobacion'] as int? ?? 50;

        final secciones =
            datos['seccionesPublicas'] as Map<String, dynamic>?;
        if (secciones != null) {
          for (final key in seccionesPublicas.keys) {
            if (secciones.containsKey(key)) {
              seccionesPublicas[key] = secciones[key] as bool;
            }
          }
        }
      }
    } catch (e) {
      error = 'Error al cargar la configuración.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> guardar({
    required String nombreCooperadora,
    required String nombreEscuela,
    required String emailContacto,
    required String telefonoContacto,
    required int anioLectivo,
    required int quorumMinimo,
    required int porcentajeAprobacion,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      this.nombreCooperadora = nombreCooperadora;
      this.nombreEscuela = nombreEscuela;
      this.emailContacto = emailContacto;
      this.telefonoContacto = telefonoContacto;
      this.anioLectivo = anioLectivo;
      this.quorumMinimo = quorumMinimo;
      this.porcentajeAprobacion = porcentajeAprobacion;

      await _repo.guardar({
        'nombreCooperadora': nombreCooperadora,
        'nombreEscuela': nombreEscuela,
        'emailContacto': emailContacto,
        'telefonoContacto': telefonoContacto,
        'anioLectivo': anioLectivo,
        'quorumMinimo': quorumMinimo,
        'porcentajeAprobacion': porcentajeAprobacion,
        'seccionesPublicas': seccionesPublicas,
      });
    } catch (e) {
      error = 'Error al guardar la configuración.';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void actualizarSeccion(String key, bool valor) {
    seccionesPublicas = {...seccionesPublicas, key: valor};
    notifyListeners();
  }
}
