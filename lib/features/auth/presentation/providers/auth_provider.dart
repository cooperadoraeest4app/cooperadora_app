import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../home/presentation/screens/home_screen.dart';

class AuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;

  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _logoutPendiente = false;
  String? rol;
  Map<String, dynamic>? datosUsuario;
  Map<String, dynamic>? datosPersona;

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
        datosPersona = null;
        notifyListeners();
        if (_logoutPendiente) {
          _logoutPendiente = false;
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    });
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get esAdmin => rol == 'admin';
  bool get esEditor => rol == 'editor' || rol == 'admin';
  bool get esAuditor => rol == 'auditor' || rol == 'admin';
  bool get esSoloLectura => rol == 'solo_lectura';
  bool get esConsultante => rol == 'consultante';

  String? get socioId => datosUsuario?['socioId'] as String?;
  String? get personaId => datosUsuario?['personaId'] as String?;

  Future<void> _cargarDatosUsuario(String uid) async {
    final firestore = FirebaseFirestore.instance;
    try {
      // 1. Primary: document with auth uid as ID (correct path for Firestore rules)
      final byId = await firestore.collection('usuarios').doc(uid).get();
      if (byId.exists) {
        datosUsuario = {...byId.data()!, 'id': byId.id};
        rol = datosUsuario!['rol'] as String?;
        await _cargarPersona(firestore);
        notifyListeners();
        return;
      }

      // 2. Legacy: document has authUid field but wrong document ID — auto-migrate
      Map<String, dynamic>? datos;
      final byAuthUid = await firestore
          .collection('usuarios')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (byAuthUid.docs.isNotEmpty) {
        datos = byAuthUid.docs.first.data();
      }

      // 3. Last resort: any active user with no authUid set (initial manual setup)
      if (datos == null) {
        final fallback = await firestore
            .collection('usuarios')
            .where('activo', isEqualTo: true)
            .limit(1)
            .get();
        if (fallback.docs.isNotEmpty) {
          final d = fallback.docs.first.data();
          final existingAuthUid = d['authUid'] as String?;
          // Only use if authUid is unset or matches — avoids cross-user collision
          if (existingAuthUid == null || existingAuthUid == uid) {
            datos = d;
          }
        }
      }

      if (datos != null) {
        // Auto-migrate: create document at correct path so Firestore rules work
        try {
          await firestore.collection('usuarios').doc(uid).set({
            ...datos,
            'authUid': uid,
          });
          // Reload from the now-correct path
          final migrated =
              await firestore.collection('usuarios').doc(uid).get();
          if (migrated.exists) {
            datosUsuario = {...migrated.data()!, 'id': migrated.id};
            rol = datosUsuario!['rol'] as String?;
            await _cargarPersona(firestore);
            notifyListeners();
            return;
          }
        } catch (_) {
          // Migration write failed (permissions) — use in-memory data
        }
        datosUsuario = {...datos, 'id': uid};
        rol = datosUsuario!['rol'] as String?;
        await _cargarPersona(firestore);
      }
    } catch (_) {
      // Error loading role — no permissions assigned
    }
    notifyListeners();
  }

  Future<void> _cargarPersona(FirebaseFirestore firestore) async {
    final personaId = datosUsuario?['personaId'] as String?;
    if (personaId == null) return;
    try {
      final doc = await firestore.collection('personas').doc(personaId).get();
      if (doc.exists) {
        datosPersona = {...doc.data()!, 'id': doc.id};
      }
    } catch (_) {
      // No permissions or persona not found
    }
  }

  Future<void> actualizarPerfil({
    String? nombre,
    String? apellido,
    String? dni,
    DateTime? fechaNacimiento,
    String? razonSocial,
    String? cuit,
    String? telefono,
    String? direccion,
    String? fotoUrl,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final firestore = FirebaseFirestore.instance;
    String? personaId = datosUsuario?['personaId'] as String?;

    final updates = <String, dynamic>{};
    if (nombre != null) updates['nombre'] = nombre;
    if (apellido != null) updates['apellido'] = apellido;
    if (dni != null) updates['dni'] = dni;
    if (fechaNacimiento != null) {
      updates['fechaNacimiento'] = Timestamp.fromDate(fechaNacimiento);
    }
    if (razonSocial != null) updates['razonSocial'] = razonSocial;
    if (cuit != null) updates['cuit'] = cuit;
    if (telefono != null) updates['telefono'] = telefono;
    if (direccion != null) updates['direccion'] = direccion;
    if (fotoUrl != null) updates['fotoUrl'] = fotoUrl;

    if (updates.isEmpty) return;

    if (personaId == null || personaId.isEmpty) {
      final personaRef = firestore.collection('personas').doc();
      await personaRef.set({
        'nombre': nombre ?? '',
        'apellido': apellido ?? '',
        'dni': dni ?? '',
        'telefono': telefono ?? '',
        'direccion': direccion ?? '',
        'razonSocial': razonSocial ?? '',
        'cuit': cuit ?? '',
        'email': currentUser?.email ?? '',
        'activo': true,
        'fechaCreacion': FieldValue.serverTimestamp(),
      });
      await firestore
          .collection('usuarios')
          .doc(uid)
          .update({'personaId': personaRef.id});
      personaId = personaRef.id;
      datosUsuario = {...?datosUsuario, 'personaId': personaId};
    } else {
      await firestore.collection('personas').doc(personaId).update(updates);
    }

    datosPersona = {...?datosPersona, ...updates};
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

  Future<void> recargarRol() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    await _cargarDatosUsuario(uid);
  }

  Future<void> logout() async {
    _logoutPendiente = true;
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
