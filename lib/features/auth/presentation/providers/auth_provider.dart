import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;

  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  AuthProvider() {
    _currentUser = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      _error = _traducirError(e.code);
    } catch (_) {
      _error = 'Ocurrió un error inesperado. Intentá de nuevo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  String _traducirError(String code) {
    return switch (code) {
      'invalid-email' => 'El email no tiene un formato válido.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Email o contraseña incorrectos.',
      'user-disabled' => 'Esta cuenta fue deshabilitada.',
      'too-many-requests' =>
        'Demasiados intentos fallidos. Intentá más tarde.',
      'network-request-failed' => 'Sin conexión a internet.',
      _ => 'Ocurrió un error. Intentá de nuevo.',
    };
  }
}
