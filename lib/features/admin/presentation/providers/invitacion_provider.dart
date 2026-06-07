import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/invitacion_repository.dart';

class InvitacionProvider extends ChangeNotifier {
  final _repo = InvitacionRepository();

  bool isLoading = false;
  bool isSaving = false;
  String? error;

  Stream<List<Map<String, dynamic>>> get invitaciones => _repo.obtenerTodas();

  Future<String> crearInvitacion({
    required String tipo,
    required String rolAsignado,
    String? emailDestino,
    String? nombreDestino,
    String? apellidoDestino,
    String? telefonoDestino,
    DateTime? fechaVencimiento,
    int? limiteUsos,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      final codigo = _generarCodigo();
      final datos = <String, dynamic>{
        'codigo': codigo,
        'tipo': tipo,
        'rolAsignado': rolAsignado,
        'usada': false,
        'usos': 0,
        'fechaCreacion': Timestamp.now(),
      };
      if (emailDestino?.isNotEmpty ?? false) datos['emailDestino'] = emailDestino;
      if (nombreDestino?.isNotEmpty ?? false) datos['nombreDestino'] = nombreDestino;
      if (apellidoDestino?.isNotEmpty ?? false) datos['apellidoDestino'] = apellidoDestino;
      if (telefonoDestino?.isNotEmpty ?? false) datos['telefonoDestino'] = telefonoDestino;
      if (fechaVencimiento != null) {
        datos['fechaVencimiento'] = Timestamp.fromDate(fechaVencimiento);
      }
      if (limiteUsos != null) datos['limiteUsos'] = limiteUsos;
      await _repo.crear(datos);
      return codigo;
    } catch (e) {
      error = 'Error al crear la invitación.';
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> eliminar(String id) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _repo.eliminar(id);
    } catch (e) {
      error = 'Error al eliminar la invitación.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  static String _generarCodigo() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
