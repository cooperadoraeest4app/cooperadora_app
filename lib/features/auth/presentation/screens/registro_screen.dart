import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/data/repositories/invitacion_repository.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../providers/auth_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _repo = InvitacionRepository();

  int _paso = 0;
  Map<String, dynamic>? _invitacion;
  bool _isLoading = false;

  final _codigoCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _verPassword = false;
  bool _verConfirm = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.rojoGasto),
    );
  }

  Future<void> _verificarCodigo() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      debugPrint('[registro] Verificando código: $codigo');
      final inv = await _repo.obtenerPorCodigo(codigo);
      debugPrint('[registro] Invitación encontrada: $inv');
      if (!mounted) return;

      if (inv == null) {
        _mostrarError('Código inválido o expirado');
        return;
      }

      if (inv['tipo'] == 'individual' && (inv['usada'] as bool? ?? false)) {
        _mostrarError('Este código ya fue utilizado');
        return;
      }

      final fechaVenc = inv['fechaVencimiento'];
      if (fechaVenc is Timestamp &&
          fechaVenc.toDate().isBefore(DateTime.now())) {
        _mostrarError('Este código ha expirado');
        return;
      }

      if (inv['tipo'] == 'generica') {
        final usos = inv['usos'] as int? ?? 0;
        final limite = inv['limiteUsos'] as int?;
        if (limite != null && usos >= limite) {
          _mostrarError('Este código ha alcanzado el límite de usos');
          return;
        }
      }

      _nombreCtrl.text = inv['nombreDestino'] as String? ?? '';
      _apellidoCtrl.text = inv['apellidoDestino'] as String? ?? '';
      _emailCtrl.text = inv['emailDestino'] as String? ?? '';

      setState(() {
        _invitacion = inv;
        _paso = 1;
      });
    } catch (e, st) {
      debugPrint('[registro] ERROR al verificar código: $e\n$st');
      if (!mounted) return;
      _mostrarError('Error al verificar el código');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _crearCuenta() async {
    if (!_formKey.currentState!.validate()) return;

    final inv = _invitacion!;
    final nombreFijo = inv['nombreDestino'] as String?;
    final apellidoFijo = inv['apellidoDestino'] as String?;
    final emailFijo = inv['emailDestino'] as String?;

    final nombre =
        (nombreFijo?.isNotEmpty ?? false) ? nombreFijo! : _nombreCtrl.text.trim();
    final apellido = (apellidoFijo?.isNotEmpty ?? false)
        ? apellidoFijo!
        : _apellidoCtrl.text.trim();
    final email =
        (emailFijo?.isNotEmpty ?? false) ? emailFijo! : _emailCtrl.text.trim();
    final rol = inv['rolAsignado'] as String? ?? 'solo_lectura';
    final invId = inv['id'] as String? ?? '';

    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordCtrl.text,
      );
      final uid = cred.user!.uid;
      final firestore = FirebaseFirestore.instance;

      final personaRef = await firestore.collection('personas').add({
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        if ((inv['telefonoDestino'] as String?)?.isNotEmpty ?? false)
          'telefono': inv['telefonoDestino'],
        'activo': true,
        'fechaCreacion': Timestamp.now(),
      });

      await firestore.collection('usuarios').doc(uid).set({
        'personaId': personaRef.id,
        'email': email,
        'rol': rol,
        'activo': true,
        'authUid': uid,
        'fechaCreacion': Timestamp.now(),
      });

      if (inv['tipo'] == 'individual') {
        await firestore
            .collection('invitaciones')
            .doc(invId)
            .update({'usada': true});
      } else {
        await firestore
            .collection('invitaciones')
            .doc(invId)
            .update({'usos': FieldValue.increment(1)});
      }

      if (!mounted) return;
      await context.read<AuthProvider>().recargarRol();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[registro] FirebaseAuthException: ${e.code} — ${e.message}');
      if (!mounted) return;
      _mostrarError(_traducirError(e.code));
    } catch (e, st) {
      debugPrint('[registro] ERROR REAL al crear cuenta: $e');
      debugPrint('[registro] Stack: $st');
      if (!mounted) return;
      _mostrarError('Error al crear la cuenta. Intentá nuevamente.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _traducirError(String code) => switch (code) {
        'email-already-in-use' => 'Este email ya tiene una cuenta registrada',
        'invalid-email' => 'El email no es válido',
        'weak-password' => 'La contraseña es muy débil',
        'network-request-failed' =>
          'Error de conexión. Verificá tu internet',
        _ => 'Error al crear la cuenta',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: AppTheme.blanco,
        iconTheme: const IconThemeData(color: AppTheme.blanco),
        titleTextStyle: const TextStyle(
          color: AppTheme.blanco,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: Text(_paso == 0 ? 'Registrarse' : 'Completar registro'),
        leading: _paso == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _paso = 0),
              )
            : null,
      ),
      body: _paso == 0 ? _buildPaso1() : _buildPaso2(),
    );
  }

  // ── Paso 1: código ────────────────────────────────────────────────────────

  Widget _buildPaso1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.mail_outline, size: 80, color: AppTheme.azulOscuro),
          const SizedBox(height: 24),
          Text(
            'Código de invitación',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textoPrincipal,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresá el código de invitación que recibiste',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textoSecundario),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _codigoCtrl,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              color: AppTheme.azulOscuro,
            ),
            decoration: InputDecoration(
              labelText: 'Código de invitación',
              hintText: 'XXXXXXXX',
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 6,
                fontSize: 24,
                color: AppTheme.textoSecundario.withAlpha(80),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              _UpperCaseFormatter(),
            ],
            onSubmitted: (_) => _verificarCodigo(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.azulOscuro,
              foregroundColor: AppTheme.blanco,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            onPressed: _isLoading ? null : _verificarCodigo,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.blanco,
                    ),
                  )
                : const Text(
                    'Verificar código',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Paso 2: datos ─────────────────────────────────────────────────────────

  Widget _buildPaso2() {
    final inv = _invitacion!;
    final nombreFijo = inv['nombreDestino'] as String?;
    final apellidoFijo = inv['apellidoDestino'] as String?;
    final emailFijo = inv['emailDestino'] as String?;
    final rol = inv['rolAsignado'] as String? ?? 'solo_lectura';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _RolInfoChip(rol: rol),
            const SizedBox(height: 24),

            // Nombre
            if (nombreFijo?.isNotEmpty ?? false)
              _CampoFijo(label: 'Nombre', valor: nombreFijo!)
            else
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
              ),
            const SizedBox(height: 12),

            // Apellido
            if (apellidoFijo?.isNotEmpty ?? false)
              _CampoFijo(label: 'Apellido', valor: apellidoFijo!)
            else
              TextFormField(
                controller: _apellidoCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Apellido *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
              ),
            const SizedBox(height: 12),

            // Email
            if (emailFijo?.isNotEmpty ?? false)
              _CampoFijo(label: 'Email', valor: emailFijo!)
            else
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El email es obligatorio';
                  }
                  if (!v.contains('@')) return 'Email inválido';
                  return null;
                },
              ),
            const SizedBox(height: 12),

            // Contraseña
            TextFormField(
              controller: _passwordCtrl,
              obscureText: !_verPassword,
              decoration: InputDecoration(
                labelText: 'Contraseña *',
                suffixIcon: IconButton(
                  icon: Icon(_verPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _verPassword = !_verPassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
                if (v.length < 8) return 'Mínimo 8 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Confirmar contraseña
            TextFormField(
              controller: _confirmCtrl,
              obscureText: !_verConfirm,
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña *',
                suffixIcon: IconButton(
                  icon: Icon(_verConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _verConfirm = !_verConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo obligatorio';
                if (v != _passwordCtrl.text) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.verdeTeal,
                foregroundColor: AppTheme.blanco,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              onPressed: _isLoading ? null : _crearCuenta,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.blanco,
                      ),
                    )
                  : const Text(
                      'Crear cuenta',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _RolInfoChip extends StatelessWidget {
  const _RolInfoChip({required this.rol});
  final String rol;

  static (Color bg, Color fg) _colores(String rol) => switch (rol) {
        'admin' => (AppTheme.azulOscuro, AppTheme.blanco),
        'editor' => (AppTheme.verdeTeal, AppTheme.blanco),
        'solo_lectura' =>
          (const Color(0xFFE0E0E0), AppTheme.textoSecundario),
        'consultante' => (const Color(0xFFFFE0B2), const Color(0xFFE65100)),
        _ => (const Color(0xFFE0E0E0), AppTheme.textoSecundario),
      };

  static String _label(String rol) => switch (rol) {
        'admin' => 'Admin',
        'editor' => 'Editor',
        'solo_lectura' => 'Solo lectura',
        'consultante' => 'Consultante',
        _ => rol,
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colores(rol);
    return Row(
      children: [
        const Text(
          'Tu rol será: ',
          style: TextStyle(color: AppTheme.textoSecundario),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          child: Text(
            _label(rol),
            style: TextStyle(
                color: fg, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _CampoFijo extends StatelessWidget {
  const _CampoFijo({required this.label, required this.valor});
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textoSecundario,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.celesteFondo,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            border: Border.all(color: AppTheme.celesteBorde),
          ),
          child: Text(
            valor,
            style: const TextStyle(
              color: AppTheme.textoPrincipal,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
