import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;

  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  String? rol;
  Map<String, dynamic>? datosUsuario;

  AuthProvider() {
    _currentUser = _auth.currentUser;
    _auth.authStateChanges().listen((user) {
      _currentUser = user;
      if (user != null) {
        notifyListeners();
        _cargarDatosUsuario(user.uid);
      } else {
        rol = null;
        datosUsuario = null;
        notifyListeners();
      }
    });
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get esAdmin => rol == 'admin';
  bool get esEditor => rol == 'editor' || rol == 'admin';
  bool get esSoloLectura => rol == 'solo_lectura';
  bool get esConsultante => rol == 'consultante';

  Future<void> _cargarDatosUsuario(String uid) async {
    final firestore = FirebaseFirestore.instance;
    try {
      // 1. Primary: document with auth uid as ID (new registrations)
      final byId = await firestore.collection('usuarios').doc(uid).get();
      if (byId.exists) {
        datosUsuario = {
          ...byId.data()!,
          'id': byId.id,
        };
        rol = datosUsuario!['rol'] as String?;
        notifyListeners();
        return;
      }

      // 2. By authUid field
      final byAuthUid = await firestore
          .collection('usuarios')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (byAuthUid.docs.isNotEmpty) {
        final doc = byAuthUid.docs.first;
        datosUsuario = {...doc.data(), 'id': doc.id};
        rol = datosUsuario!['rol'] as String?;
        notifyListeners();
        return;
      }

      // 3. Fallback: any active user (temporary during migration)
      final fallback = await firestore
          .collection('usuarios')
          .where('activo', isEqualTo: true)
          .limit(1)
          .get();
      if (fallback.docs.isNotEmpty) {
        final doc = fallback.docs.first;
        datosUsuario = {...doc.data(), 'id': doc.id};
        rol = datosUsuario!['rol'] as String?;
      }
    } catch (_) {
      // Error loading role — no permissions assigned
    }
    notifyListeners();
  }

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
