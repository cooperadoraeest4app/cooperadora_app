import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../../../home/presentation/screens/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../../admin/presentation/providers/cargo_provider.dart';
import '../../../socios/data/repositories/socio_repository.dart';
import '../../../socios/domain/models/socio.dart';
import '../../../socios/domain/services/cuota_calculo_service.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/seccion_hijos_widget.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  // Persona física
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  // Persona fiscal
  final _razonSocialCtrl = TextEditingController();
  final _cuitCtrl = TextEditingController();
  // Ambos tipos
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  // Originales para detección de cambios
  String _nombreOrig = '';
  String _apellidoOrig = '';
  String _dniOrig = '';
  String _razonSocialOrig = '';
  String _cuitOrig = '';
  String _telefonoOrig = '';
  String _direccionOrig = '';
  DateTime? _fechaNacimientoOrig;

  DateTime? _fechaNacimiento;
  bool _esFiscal = false;
  String? _subtipo;
  bool _subiendo = false;
  bool _guardando = false;
  bool _initialized = false;

  late final Future<CuotaEstado?> _cuotaEstadoFuture;
  String? _socioIdResuelto;

  static bool _sameDia(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool get _hayCambios {
    if (_esFiscal) {
      return _razonSocialCtrl.text.trim() != _razonSocialOrig ||
          _cuitCtrl.text.trim() != _cuitOrig ||
          _telefonoCtrl.text.trim() != _telefonoOrig ||
          _direccionCtrl.text.trim() != _direccionOrig;
    }
    return _nombreCtrl.text.trim() != _nombreOrig ||
        _apellidoCtrl.text.trim() != _apellidoOrig ||
        _dniCtrl.text.trim() != _dniOrig ||
        !_sameDia(_fechaNacimiento, _fechaNacimientoOrig) ||
        _telefonoCtrl.text.trim() != _telefonoOrig ||
        _direccionCtrl.text.trim() != _direccionOrig;
  }

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nombreCtrl, _apellidoCtrl, _dniCtrl,
      _razonSocialCtrl, _cuitCtrl,
      _telefonoCtrl, _direccionCtrl,
    ]) {
      c.addListener(() => setState(() {}));
    }
    _cuotaEstadoFuture = _fetchCuotaEstado();
  }

  Future<CuotaEstado?> _fetchCuotaEstado() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    print('[Perfil] authUid: $uid');
    if (uid == null) return null;
    final userDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .get();
    print('[Perfil] userDoc.exists: ${userDoc.exists}, data: ${userDoc.data()}');
    String? socioId = userDoc.data()?['socioId'] as String?;
    print('[Perfil] socioId del usuario: $socioId');

    if (socioId == null) {
      final personaId = userDoc.data()?['personaId'] as String?;
      if (personaId != null) {
        final socioSnap = await FirebaseFirestore.instance
            .collection('socios')
            .where('personaId', isEqualTo: personaId)
            .limit(1)
            .get();
        if (socioSnap.docs.isNotEmpty) {
          socioId = socioSnap.docs.first.id;
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .update({'socioId': socioId});
        }
      }
    }
    print('[Perfil] socioId resuelto: $socioId');
    if (mounted) setState(() => _socioIdResuelto = socioId);
    if (socioId == null) return null;
    final socioDoc = await FirebaseFirestore.instance
        .collection('socios')
        .doc(socioId)
        .get();
    print('[Perfil] socioDoc.exists: ${socioDoc.exists}');
    if (!socioDoc.exists) return null;
    final socio = Socio.fromMap(socioDoc.data()!, socioDoc.id);
    try {
      final estado = await CuotaCalculoService().calcularEstado(
        socioId: socioId,
        fechaIngreso: socio.fechaIngreso,
      );
      print('[Perfil] calcularEstado OK: totalPagado=${estado.totalPagado}, estaAlDia=${estado.estaAlDia}');
      return estado;
    } catch (e, st) {
      print('[Perfil] ERROR en calcularEstado: $e\n$st');
      return null;
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
    _esFiscal = persona['tipoPersona'] == 'fiscal';
    _subtipo = persona['subtipo'] as String?;

    _nombreOrig = persona['nombre'] as String? ?? '';
    _apellidoOrig = persona['apellido'] as String? ?? '';
    _dniOrig = persona['dni'] as String? ?? '';
    _razonSocialOrig = persona['razonSocial'] as String? ?? '';
    _cuitOrig = persona['cuit'] as String? ?? '';
    _telefonoOrig = persona['telefono'] as String? ?? '';
    _direccionOrig = persona['direccion'] as String? ?? '';

    final rawFecha = persona['fechaNacimiento'];
    _fechaNacimientoOrig =
        rawFecha is Timestamp ? rawFecha.toDate() : null;
    _fechaNacimiento = _fechaNacimientoOrig;

    _nombreCtrl.text = _nombreOrig;
    _apellidoCtrl.text = _apellidoOrig;
    _dniCtrl.text = _dniOrig;
    _razonSocialCtrl.text = _razonSocialOrig;
    _cuitCtrl.text = _cuitOrig;
    _telefonoCtrl.text = _telefonoOrig;
    _direccionCtrl.text = _direccionOrig;

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
          SnackBar(
              content: Text('Error al subir foto: $e'),
              backgroundColor: AppTheme.rojoGasto),
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
          const SnackBar(
              content: Text('Te enviamos un email para cambiar tu contraseña')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.rojoGasto),
        );
      }
    }
  }

  Future<void> _guardar() async {
    if (!_esFiscal && _dniCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El DNI es obligatorio'),
          backgroundColor: AppTheme.rojoGasto,
        ),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      await context.read<AuthProvider>().actualizarPerfil(
            nombre: _esFiscal ? null : _nombreCtrl.text.trim(),
            apellido: _esFiscal ? null : _apellidoCtrl.text.trim(),
            dni: _esFiscal ? null : _dniCtrl.text.trim(),
            fechaNacimiento: _esFiscal ? null : _fechaNacimiento,
            razonSocial: _esFiscal ? _razonSocialCtrl.text.trim() : null,
            cuit: _esFiscal ? _cuitCtrl.text.trim() : null,
            telefono: _telefonoCtrl.text.trim(),
            direccion: _direccionCtrl.text.trim(),
          );
      if (_esFiscal) {
        _razonSocialOrig = _razonSocialCtrl.text.trim();
        _cuitOrig = _cuitCtrl.text.trim();
      } else {
        _nombreOrig = _nombreCtrl.text.trim();
        _apellidoOrig = _apellidoCtrl.text.trim();
        _dniOrig = _dniCtrl.text.trim();
        _fechaNacimientoOrig = _fechaNacimiento;
      }
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
          SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: AppTheme.rojoGasto),
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
    _dniCtrl.dispose();
    _razonSocialCtrl.dispose();
    _cuitCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  static String _formatMonto(double m) =>
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2)
          .format(m);

  void _verHistorialCompleto(CuotaEstado estado) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textoSecundario.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Historial completo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: estado.mesesCubiertos.reversed.map((mes) {
                  final (color, icono) = switch (mes.estado) {
                    'cubierto' => (AppTheme.verdeIngreso, Icons.check_circle_outline),
                    'parcial' => (AppTheme.amarilloAlerta, Icons.warning_amber_outlined),
                    'sin_tarifa' => (AppTheme.textoSecundario, Icons.help_outline),
                    _ => (AppTheme.rojoGasto, Icons.cancel_outlined),
                  };
                  final label = switch (mes.estado) {
                    'cubierto' => 'Al día',
                    'parcial' => 'Parcial',
                    'sin_tarifa' => 'Sin tarifa',
                    _ => 'Sin cubrir',
                  };
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(icono, color: color, size: 18),
                    title: Text(
                      DateFormat('MMMM yyyy', 'es').format(mes.mes),
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Text(label,
                        style: TextStyle(fontSize: 12, color: color)),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _nombreRol(String rol) => switch (rol) {
        'admin' => 'Administrador',
        'editor' => 'Editor',
        'auditor' => 'Auditor',
        'solo_lectura' => 'Solo lectura',
        'consultante' => 'Consultante',
        _ => 'Sin rol',
      };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!_initialized && auth.datosPersona != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_initialized && mounted) {
          _poblarCampos(auth.datosPersona!);
          setState(() => _initialized = true);
        }
      });
    }

    final email = auth.currentUser?.email ?? '';
    final inicial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final fotoUrl = auth.datosPersona?['fotoUrl'] as String?;
    final rol = auth.rol ?? '';
    final personaId = auth.datosPersona?['id'] as String? ?? '';

    return PopScope(
      canPop: !_hayCambios,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final accion = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cambios sin guardar'),
            content:
                const Text('Tenés cambios sin guardar. ¿Qué querés hacer?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancelar'),
                child: const Text('Seguir editando'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'descartar'),
                child: const Text('Descartar',
                    style: TextStyle(color: AppTheme.rojoGasto)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'guardar'),
                child: const Text('Guardar y salir'),
              ),
            ],
          ),
        );
        if (accion == 'guardar') await _guardar();
        if (accion != 'cancelar' && accion != null && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: AppTheme.azulOscuro,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          titleSpacing: 0,
          title: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.3)),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: Icon(Icons.home, color: Colors.white.withValues(alpha: 0.8), size: 20),
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  ),
                ),
              ),
              Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mi perfil',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [AccionAuthWidget()],
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
                            backgroundImage:
                                fotoUrl != null ? NetworkImage(fotoUrl) : null,
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

                // Mis datos
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mis datos',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        if (_esFiscal) ...[
                          TextFormField(
                            controller: _razonSocialCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Razón social'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _cuitCtrl,
                            decoration: const InputDecoration(labelText: 'CUIT'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _nombreCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Nombre'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _apellidoCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Apellido'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _dniCtrl,
                            decoration: const InputDecoration(labelText: 'DNI *'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                          const SizedBox(height: 12),
                          _CampoFecha(
                            label: 'Fecha de nacimiento',
                            fecha: _fechaNacimiento,
                            onChanged: (f) =>
                                setState(() => _fechaNacimiento = f),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefonoCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Teléfono'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _direccionCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Dirección'),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 12),
                        _CampoSoloLectura(label: 'Email', valor: email),
                        if (_subtipo != null && _subtipo!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _CampoSoloLectura(label: 'Tipo', valor: _subtipo!),
                        ],
                        const SizedBox(height: 12),
                        Builder(
                          builder: (ctx) {
                            final cargoProvider = ctx.watch<CargoProvider>();
                            if (!cargoProvider.cargado) {
                              return InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Cargo institucional',
                                  helperText: 'No editable',
                                ),
                                child: const SizedBox(
                                  height: 14,
                                  child: LinearProgressIndicator(
                                    color: AppTheme.celesteAccento,
                                    backgroundColor: AppTheme.celesteFondo,
                                  ),
                                ),
                              );
                            }
                            final nombre = cargoProvider.nombreCargoDePersona(personaId);
                            return _CampoSoloLectura(
                              label: 'Cargo institucional',
                              valor: nombre.isNotEmpty ? nombre : 'Sin cargo institucional',
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _CampoSoloLectura(
                            label: 'Rol en la app',
                            valor: _nombreRol(rol)),
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
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
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

                // Hijos/as en la institución (solo si tiene persona vinculada, no alumno ni fiscal)
                Builder(builder: (context) {
                  final auth = context.watch<AuthProvider>();
                  final personaId = auth.personaId;
                  final tipoPersona =
                      auth.datosPersona?['tipoPersona'] as String?;
                  final subtipo = auth.datosPersona?['subtipo'] as String?;
                  if (personaId == null ||
                      tipoPersona == 'fiscal' ||
                      subtipo == 'alumno') {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SeccionHijosWidget(
                      personaId: personaId,
                      puedeEditar: true,
                    ),
                  );
                }),

                // Membresía (solo si tiene socio vinculado)
                if (_socioIdResuelto != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FutureBuilder<Socio?>(
                      future: SocioRepository().obtenerPorId(_socioIdResuelto!),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final socio = snap.data!;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.celesteFondo,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.celesteBorde),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.badge,
                                      color: AppTheme.azulMedio),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Mi membresía',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.azulOscuro),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: AppTheme.azulOscuro),
                                    ),
                                    child: Text(
                                      'N° ${socio.numeroSocio.toString().padLeft(3, '0')}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.azulOscuro),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _filaDato('Tipo de socio',
                                  _nombreTipoSocio(socio.tipoSocio)),
                              _filaDato(
                                'Fecha de ingreso',
                                DateFormat('dd/MM/yyyy')
                                    .format(socio.fechaIngreso),
                              ),
                              _filaDato(
                                'Estado',
                                socio.activo ? 'Activo' : 'Inactivo',
                                color: socio.activo
                                    ? AppTheme.verdeIngreso
                                    : AppTheme.rojoGasto,
                              ),
                              if (socio.observaciones != null &&
                                  socio.observaciones!.isNotEmpty)
                                _filaDato(
                                    'Observaciones', socio.observaciones!),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // Historial de cuotas (solo si tiene socio vinculado)
                FutureBuilder<CuotaEstado?>(
                  future: _cuotaEstadoFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      );
                    }
                    final estado = snap.data;
                    if (estado == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mi historial de cuotas',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),

                              // Chip de estado
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: estado.estaAlDia
                                      ? AppTheme.verdeIngreso.withValues(alpha: 0.08)
                                      : AppTheme.rojoGasto.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: estado.estaAlDia
                                        ? AppTheme.verdeIngreso
                                        : AppTheme.rojoGasto,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      estado.estaAlDia
                                          ? Icons.check_circle_outline
                                          : Icons.warning_amber_outlined,
                                      color: estado.estaAlDia
                                          ? AppTheme.verdeIngreso
                                          : AppTheme.rojoGasto,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            estado.estaAlDia
                                                ? 'Estás al día'
                                                : 'Tenés deuda pendiente',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: estado.estaAlDia
                                                  ? AppTheme.verdeIngreso
                                                  : AppTheme.rojoGasto,
                                            ),
                                          ),
                                          if (estado.deuda > 0)
                                            Text(
                                              'Deuda: ${_formatMonto(estado.deuda)}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.rojoGasto),
                                            ),
                                          if (estado.creditoAFavor > 0)
                                            Text(
                                              'Crédito a favor: ${_formatMonto(estado.creditoAFavor)}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.verdeIngreso),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Pagos realizados
                              if (estado.pagos.isNotEmpty) ...[
                                const Text(
                                  'Pagos realizados',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textoSecundario),
                                ),
                                const SizedBox(height: 4),
                                ...estado.pagos.map((pago) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      leading: const Icon(
                                          Icons.payments_outlined,
                                          color: AppTheme.verdeIngreso,
                                          size: 20),
                                      title: Text(
                                        _formatMonto(pago.monto),
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        DateFormat('dd/MM/yyyy')
                                            .format(pago.fechaPago),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    )),
                                const SizedBox(height: 10),
                              ],

                              // Cobertura mensual (últimos 6)
                              const Text(
                                'Cobertura mensual',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textoSecundario),
                              ),
                              const SizedBox(height: 4),
                              ...estado.mesesCubiertos.reversed
                                  .take(6)
                                  .map((mes) {
                                final (color, icono) = switch (mes.estado) {
                                  'cubierto' => (
                                      AppTheme.verdeIngreso,
                                      Icons.check_circle_outline
                                    ),
                                  'parcial' => (
                                      AppTheme.amarilloAlerta,
                                      Icons.warning_amber_outlined
                                    ),
                                  'sin_tarifa' => (
                                      AppTheme.textoSecundario,
                                      Icons.help_outline
                                    ),
                                  _ => (
                                      AppTheme.rojoGasto,
                                      Icons.cancel_outlined
                                    ),
                                };
                                final label = switch (mes.estado) {
                                  'cubierto' => 'Al día',
                                  'parcial' => 'Parcial',
                                  'sin_tarifa' => 'Sin tarifa',
                                  _ => 'Sin cubrir',
                                };
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: Icon(icono, color: color, size: 18),
                                  title: Text(
                                    DateFormat('MMMM yyyy', 'es')
                                        .format(mes.mes),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: Text(label,
                                      style: TextStyle(
                                          fontSize: 11, color: color)),
                                );
                              }),

                              if (estado.mesesCubiertos.length > 6)
                                TextButton(
                                  onPressed: () =>
                                      _verHistorialCompleto(estado),
                                  child: Text(
                                    'Ver historial completo (${estado.mesesCubiertos.length} meses)',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Botón fijo inferior
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
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

Widget _filaDato(String label, String valor, {Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
              fontSize: 13, color: AppTheme.textoSecundario),
        ),
        Flexible(
          child: Text(
            valor,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color ?? AppTheme.textoPrincipal),
          ),
        ),
      ],
    ),
  );
}

String _nombreTipoSocio(String tipo) => switch (tipo) {
      'activo' => 'Socio Activo',
      'adherente' => 'Socio Adherente',
      'honorario' => 'Socio Honorario',
      _ => tipo,
    };

class _CampoSoloLectura extends StatelessWidget {
  const _CampoSoloLectura({required this.label, required this.valor});
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: valor,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: 'No editable',
      ),
      style: const TextStyle(color: AppTheme.textoSecundario),
    );
  }
}

class _CampoFecha extends StatelessWidget {
  const _CampoFecha({
    required this.label,
    required this.fecha,
    required this.onChanged,
  });
  final String label;
  final DateTime? fecha;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final texto = fecha != null
        ? '${fecha!.day.toString().padLeft(2, '0')}/'
            '${fecha!.month.toString().padLeft(2, '0')}/'
            '${fecha!.year}'
        : '';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: fecha ?? DateTime(2000),
          firstDate: DateTime(1920),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              texto.isEmpty ? 'Seleccionar' : texto,
              style: TextStyle(
                color: texto.isEmpty
                    ? AppTheme.textoSecundario
                    : AppTheme.textoPrincipal,
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppTheme.azulMedio),
          ],
        ),
      ),
    );
  }
}
