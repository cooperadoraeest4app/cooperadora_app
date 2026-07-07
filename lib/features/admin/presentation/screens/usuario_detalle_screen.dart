import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../admin/domain/models/persona.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../socios/domain/models/socio.dart';
import '../../../socios/presentation/screens/socio_detalle_screen.dart';
import '../../../../shared/widgets/app_drawer.dart';

class UsuarioDetalleScreen extends StatefulWidget {
  const UsuarioDetalleScreen({super.key, required this.usuarioId});
  final String usuarioId;

  @override
  State<UsuarioDetalleScreen> createState() => _UsuarioDetalleScreenState();
}

class _UsuarioDetalleScreenState extends State<UsuarioDetalleScreen> {
  StreamSubscription? _sub;
  Map<String, dynamic>? _usuario;
  Persona? _persona;
  Socio? _socio;
  bool _cargandoPersona = false;
  bool _actualizando = false;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.usuarioId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (!snap.exists) return;
      final data = {...snap.data()!, 'id': snap.id};
      setState(() => _usuario = data);
      final personaId = data['personaId'] as String?;
      if (personaId != null && personaId.isNotEmpty && _persona == null) {
        _cargarPersona(personaId);
      }
    });
  }

  Future<void> _cargarPersona(String personaId) async {
    setState(() => _cargandoPersona = true);
    try {
      final personaDoc = await FirebaseFirestore.instance
          .collection('personas')
          .doc(personaId)
          .get();
      final socioQuery = await FirebaseFirestore.instance
          .collection('socios')
          .where('personaId', isEqualTo: personaId)
          .limit(1)
          .get();
      if (!mounted) return;
      setState(() {
        if (personaDoc.exists && personaDoc.data() != null) {
          _persona = Persona.fromMap(personaDoc.data()!, personaDoc.id);
        }
        if (socioQuery.docs.isNotEmpty) {
          _socio = Socio.fromMap(
              socioQuery.docs.first.data(), socioQuery.docs.first.id);
        }
        _cargandoPersona = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoPersona = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _actualizarRol(String nuevoRol) async {
    setState(() => _actualizando = true);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.usuarioId)
          .update({'rol': nuevoRol});
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  Future<void> _toggleActivo(bool activo) async {
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(widget.usuarioId)
        .update({'activo': activo});
  }

  Future<void> _enviarResetPassword() async {
    final email = _persona?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin email registrado para esta persona')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      messenger.showSnackBar(SnackBar(
        content: Text('Email de cambio de contraseña enviado a $email'),
        backgroundColor: AppTheme.verdeTeal,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppTheme.rojoGasto,
      ));
    }
  }

  void _mostrarSelectorRol() {
    final rolActual = _usuario?['rol'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SelectorRolSheet(
        rolActual: rolActual,
        onSeleccionar: (nuevoRol) {
          Navigator.pop(context);
          _actualizarRol(nuevoRol);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final esAdmin = auth.esAdmin;
    final esPropioUsuario = auth.currentUser?.uid == widget.usuarioId;

    if (_usuario == null) {
      return Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: AppTheme.azulOscuro,
          foregroundColor: Colors.white,
          title: const Text('Usuario'),
          actions: const [AccionAuthWidget()],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final rol = _usuario!['rol'] as String? ?? '';
    final activo = _usuario!['activo'] as bool? ?? false;
    final nombre = _persona?.nombreCompleto ?? widget.usuarioId;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
        title: Text(nombre),
        actions: const [AccionAuthWidget()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Datos personales
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 18, color: AppTheme.azulMedio),
                      SizedBox(width: 8),
                      Text(
                        'Datos personales',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.textoPrincipal,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (_cargandoPersona)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_persona == null)
                    const Text(
                      'Sin persona vinculada',
                      style: TextStyle(color: AppTheme.textoSecundario),
                    )
                  else ...[
                    Center(
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: AppTheme.celesteAccento,
                        backgroundImage: _persona!.fotoUrl != null
                            ? NetworkImage(_persona!.fotoUrl!)
                            : null,
                        child: _persona!.fotoUrl == null
                            ? Text(
                                _persona!.nombreCompleto.isNotEmpty
                                    ? _persona!.nombreCompleto[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 32,
                                  color: AppTheme.azulOscuro,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PersonaInfoTiles(persona: _persona!),
                  ],
                  if (_socio != null) ...[
                    const Divider(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.badge_outlined,
                          color: AppTheme.azulMedio),
                      title: const Text('Ver como socio'),
                      subtitle:
                          Text('Nº ${_socio!.numeroSocio} · ${_socio!.tipoSocio}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SocioDetalleScreen(socio: _socio!),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Acceso a la app
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_open_outlined,
                          size: 18, color: AppTheme.verdeTeal),
                      SizedBox(width: 8),
                      Text(
                        'Acceso a la app',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.textoPrincipal,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  // Rol
                  Row(
                    children: [
                      const Text(
                        'Rol: ',
                        style: TextStyle(color: AppTheme.textoSecundario),
                      ),
                      _RolChip(rol: rol),
                      const Spacer(),
                      if (esAdmin && !esPropioUsuario)
                        _actualizando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : TextButton.icon(
                                onPressed: _mostrarSelectorRol,
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Cambiar'),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.azulMedio),
                              ),
                    ],
                  ),
                  // Email
                  if (_persona?.email != null && _persona!.email!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined,
                            size: 16, color: AppTheme.textoSecundario),
                        const SizedBox(width: 8),
                        Text(
                          _persona!.email!,
                          style: const TextStyle(
                              color: AppTheme.textoSecundario, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  // Activo (solo admin, no propio)
                  if (esAdmin && !esPropioUsuario) ...[
                    const Divider(height: 20),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Usuario habilitado',
                          style: TextStyle(fontSize: 14)),
                      value: activo,
                      activeThumbColor: AppTheme.verdeTeal,
                      onChanged: _toggleActivo,
                    ),
                  ],
                  // Cambiar contraseña
                  if (esAdmin || esPropioUsuario) ...[
                    const Divider(height: 20),
                    OutlinedButton.icon(
                      onPressed: _enviarResetPassword,
                      icon: const Icon(Icons.lock_reset, size: 16),
                      label: const Text('Enviar email de cambio de contraseña'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.azulMedio,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _PersonaInfoTiles ──────────────────────────────────────────────────────────

class _PersonaInfoTiles extends StatelessWidget {
  const _PersonaInfoTiles({required this.persona});
  final Persona persona;

  @override
  Widget build(BuildContext context) {
    final esFiscal = persona.tipoPersona == 'fiscal';
    return Column(
      children: [
        if (esFiscal) ...[
          _InfoRow(label: 'Razón social', value: persona.razonSocial),
          _InfoRow(label: 'CUIT', value: persona.cuit),
        ] else ...[
          _InfoRow(label: 'Nombre', value: persona.nombre),
          _InfoRow(label: 'Apellido', value: persona.apellido),
          _InfoRow(label: 'DNI', value: persona.dni),
          if (persona.fechaNacimiento != null)
            _InfoRow(
              label: 'Fecha de nacimiento',
              value:
                  '${persona.fechaNacimiento!.day.toString().padLeft(2, '0')}/${persona.fechaNacimiento!.month.toString().padLeft(2, '0')}/${persona.fechaNacimiento!.year}',
            ),
          _InfoRow(label: 'Dirección', value: persona.direccion),
        ],
        _InfoRow(label: 'Teléfono', value: persona.telefono),
        _InfoRow(label: 'Email', value: persona.email),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textoSecundario,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _RolChip ─────────────────────────────────────────────────────────────────

class _RolChip extends StatelessWidget {
  const _RolChip({required this.rol});
  final String rol;

  static (Color bg, Color fg) _colores(String rol) => switch (rol) {
        'admin' => (AppTheme.azulOscuro, Colors.white),
        'editor' => (AppTheme.verdeTeal, Colors.white),
        'auditor' => (AppTheme.azulMedio, Colors.white),
        'solo_lectura' => (const Color(0xFFE0E0E0), AppTheme.textoSecundario),
        'consultante' => (const Color(0xFFFFE0B2), const Color(0xFFE65100)),
        _ => (const Color(0xFFE0E0E0), AppTheme.textoSecundario),
      };

  static String _label(String rol) => switch (rol) {
        'admin' => 'Admin',
        'editor' => 'Editor',
        'auditor' => 'Auditor',
        'solo_lectura' => 'Solo lectura',
        'consultante' => 'Consultante',
        _ => rol,
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colores(rol);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        _label(rol),
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── _SelectorRolSheet ─────────────────────────────────────────────────────────

class _SelectorRolSheet extends StatelessWidget {
  const _SelectorRolSheet({
    required this.rolActual,
    required this.onSeleccionar,
  });

  final String rolActual;
  final ValueChanged<String> onSeleccionar;

  static const _roles = [
    ('admin', 'Admin', Icons.admin_panel_settings,
        'Acceso completo a todas las funciones'),
    ('editor', 'Editor', Icons.edit_note, 'Puede cargar y editar movimientos'),
    ('auditor', 'Auditor', Icons.history,
        'Puede ver el log de cambios y toda la información'),
    ('solo_lectura', 'Solo lectura', Icons.visibility,
        'Puede ver todo pero no modificar'),
    ('consultante', 'Consultante', Icons.person_outline,
        'Acceso solo a secciones públicas'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cambiar rol',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textoPrincipal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._roles.map(
            (r) => ListTile(
              leading: Icon(r.$3, color: AppTheme.azulMedio),
              title: Text(r.$2,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(r.$4,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textoSecundario)),
              trailing: rolActual == r.$1
                  ? const Icon(Icons.check_circle, color: AppTheme.verdeTeal)
                  : null,
              onTap: () => onSeleccionar(r.$1),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
