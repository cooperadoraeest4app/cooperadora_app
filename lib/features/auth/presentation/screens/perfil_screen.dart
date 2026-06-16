import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  String _nombreOrig = '';
  String _apellidoOrig = '';
  String _telefonoOrig = '';
  String _direccionOrig = '';

  String? _cargoNombre;
  bool _subiendo = false;
  bool _guardando = false;
  bool _initialized = false;

  bool get _hayCambios =>
      _nombreCtrl.text.trim() != _nombreOrig ||
      _apellidoCtrl.text.trim() != _apellidoOrig ||
      _telefonoCtrl.text.trim() != _telefonoOrig ||
      _direccionCtrl.text.trim() != _direccionOrig;

  @override
  void initState() {
    super.initState();
    for (final c in [_nombreCtrl, _apellidoCtrl, _telefonoCtrl, _direccionCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final persona = context.read<AuthProvider>().datosPersona;
      if (persona != null) {
        _poblarCampos(persona);
        _initialized = true;
      }
    }
  }

  void _poblarCampos(Map<String, dynamic> persona) {
    _nombreOrig = persona['nombre'] as String? ?? '';
    _apellidoOrig = persona['apellido'] as String? ?? '';
    _telefonoOrig = persona['telefono'] as String? ?? '';
    _direccionOrig = persona['direccion'] as String? ?? '';

    _nombreCtrl.text = _nombreOrig;
    _apellidoCtrl.text = _apellidoOrig;
    _telefonoCtrl.text = _telefonoOrig;
    _direccionCtrl.text = _direccionOrig;

    final cargoId = persona['cargoId'] as String?;
    if (cargoId != null && cargoId.isNotEmpty) {
      _cargarCargo(cargoId);
    }
  }

  Future<void> _cargarCargo(String cargoId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('cargos').doc(cargoId).get();
      if (doc.exists && mounted) {
        setState(() => _cargoNombre = doc.data()?['nombre'] as String? ?? cargoId);
      }
    } catch (_) {
      if (mounted) setState(() => _cargoNombre = cargoId);
    }
  }

  Future<void> _cambiarFoto() async {
    final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    if (!mounted) return;
    setState(() => _subiendo = true);
    try {
      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser!.uid;
      final ext = file.extension ?? 'jpg';
      final ref = FirebaseStorage.instance.ref('perfiles/$uid/foto.$ext');
      await ref.putData(file.bytes!);
      final url = await ref.getDownloadURL();
      await auth.actualizarPerfil(fotoUrl: url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e'), backgroundColor: AppTheme.rojoGasto),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _cambiarContrasena() async {
    final email = context.read<AuthProvider>().currentUser?.email;
    if (email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Te enviamos un email para cambiar tu contraseña')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.rojoGasto),
        );
      }
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await context.read<AuthProvider>().actualizarPerfil(
            nombre: _nombreCtrl.text.trim(),
            apellido: _apellidoCtrl.text.trim(),
            telefono: _telefonoCtrl.text.trim(),
            direccion: _direccionCtrl.text.trim(),
          );
      _nombreOrig = _nombreCtrl.text.trim();
      _apellidoOrig = _apellidoCtrl.text.trim();
      _telefonoOrig = _telefonoCtrl.text.trim();
      _direccionOrig = _direccionCtrl.text.trim();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado'),
            backgroundColor: AppTheme.verdeTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppTheme.rojoGasto),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Initialize once persona loads (in case it wasn't ready during didChangeDependencies)
    if (!_initialized && auth.datosPersona != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_initialized && mounted) {
          _poblarCampos(auth.datosPersona!);
          setState(() => _initialized = true);
        }
      });
    }

    final persona = auth.datosPersona;
    final email = auth.currentUser?.email ?? '';
    final inicial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final fotoUrl = persona?['fotoUrl'] as String?;
    final rol = auth.rol ?? '';

    final (chipColor, chipLabel) = switch (rol) {
      'admin' => (AppTheme.azulOscuro, 'Administrador'),
      'editor' => (AppTheme.verdeTeal, 'Editor'),
      'auditor' => (AppTheme.amarilloAlerta, 'Auditor'),
      'solo_lectura' => (AppTheme.textoSecundario, 'Solo lectura'),
      'consultante' => (AppTheme.azulMedio, 'Consultante'),
      _ => (AppTheme.textoSecundario, 'Sin rol'),
    };

    final cargoId = persona?['cargoId'] as String?;
    final cargoTexto = _cargoNombre ?? cargoId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
        title: const Text('Mi perfil'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
            children: [
              // Foto de perfil
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.celesteAccento,
                          backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                          child: fotoUrl == null
                              ? Text(
                                  inicial,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.azulOscuro,
                                  ),
                                )
                              : null,
                        ),
                        if (_subiendo)
                          const Positioned.fill(
                            child: CircleAvatar(
                              backgroundColor: Colors.black38,
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Cambiar foto'),
                      onPressed: _subiendo ? null : _cambiarFoto,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Datos personales
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Datos personales',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _apellidoCtrl,
                        decoration: const InputDecoration(labelText: 'Apellido'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telefonoCtrl,
                        decoration: const InputDecoration(labelText: 'Teléfono'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _direccionCtrl,
                        decoration: const InputDecoration(labelText: 'Dirección'),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: email,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          helperText: 'No editable',
                        ),
                        style: const TextStyle(color: AppTheme.textoSecundario),
                      ),
                      if (cargoTexto != null && cargoTexto.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: cargoTexto,
                          readOnly: true,
                          decoration: const InputDecoration(labelText: 'Cargo institucional'),
                          style: const TextStyle(color: AppTheme.textoSecundario),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Rol:',
                            style: TextStyle(color: AppTheme.textoSecundario, fontSize: 13),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: chipColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              chipLabel,
                              style: TextStyle(
                                color: chipColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Seguridad
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seguridad',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.lock_outline, size: 18),
                          label: const Text('Cambiar contraseña'),
                          onPressed: _cambiarContrasena,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Botón fijo inferior — solo visible cuando hay cambios
          if (_hayCambios)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.verdeTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Guardar cambios',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
