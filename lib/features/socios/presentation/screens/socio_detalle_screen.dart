import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../shared/utils/metodo_pago_icon.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/data/repositories/persona_repository.dart';
import '../../../admin/domain/models/persona.dart';
import '../../../admin/presentation/providers/metodo_pago_provider.dart';
import '../../../admin/presentation/providers/persona_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/nombre_usuario_widget.dart';
import '../../data/repositories/cuota_repository.dart';
import '../../data/repositories/socio_repository.dart';
import '../../domain/models/cuota.dart';
import '../../domain/models/socio.dart';
import '../../domain/models/subtipo_socio.dart';
import '../../domain/models/tipo_socio.dart';
import '../providers/cuota_provider.dart';
import '../providers/socio_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtFecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtMonto(double m) =>
    NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 2)
        .format(m);

// ── SocioDetalleScreen ────────────────────────────────────────────────────────

class SocioDetalleScreen extends StatefulWidget {
  const SocioDetalleScreen({super.key, required this.socio});
  final Socio socio;

  @override
  State<SocioDetalleScreen> createState() => _SocioDetalleScreenState();
}

class _SocioDetalleScreenState extends State<SocioDetalleScreen> {
  final _socioRepo = SocioRepository();
  final _personaRepo = PersonaRepository();

  late Socio _original;
  late Future<Persona?> _personaFuture;
  Persona? _personaOriginal;
  bool _personaInicializada = false;

  String? _tipoSocio;
  String? _subtipoId;

  late TextEditingController _nombreCtrl;
  late TextEditingController _apellidoCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _direccionCtrl;
  late TextEditingController _razonSocialCtrl;
  late TextEditingController _cuitCtrl;
  late TextEditingController _observacionesCtrl;
  DateTime? _fechaNacimiento;
  late DateTime _fechaIngreso;

  List<SubtipoSocio> _subtipos = [];
  StreamSubscription<List<SubtipoSocio>>? _subtiposSub;

  bool _saving = false;

  bool get _esFiscal => _personaOriginal?.tipoPersona == 'fiscal';

  bool get _hayCambios {
    if (!_personaInicializada) return false;
    final s = _original;
    final p = _personaOriginal!;
    if (_tipoSocio != s.tipoSocio) return true;
    if (_observacionesCtrl.text.trim() != (s.observaciones ?? '')) {
      return true;
    }
    final fi = _fechaIngreso;
    final orig = s.fechaIngreso;
    if (fi.year != orig.year || fi.month != orig.month || fi.day != orig.day) {
      return true;
    }
    if (_esFiscal) {
      if (_razonSocialCtrl.text.trim() != (p.razonSocial ?? '')) return true;
      if (_cuitCtrl.text.trim() != (p.cuit ?? '')) return true;
    } else {
      if (_nombreCtrl.text.trim() != p.nombre) return true;
      if (_apellidoCtrl.text.trim() != p.apellido) return true;
      if (_dniCtrl.text.trim() != (p.dni ?? '')) return true;
      final origSubtipo = p.subtipo;
      if (_subtipoId != origSubtipo) return true;
      final fn = _fechaNacimiento;
      final origFn = p.fechaNacimiento;
      if ((fn == null) != (origFn == null)) return true;
      if (fn != null &&
          origFn != null &&
          (fn.year != origFn.year ||
              fn.month != origFn.month ||
              fn.day != origFn.day)) {
        return true;
      }
    }
    if (_telefonoCtrl.text.trim() != (p.telefono ?? '')) return true;
    if (_emailCtrl.text.trim() != (p.email ?? '')) return true;
    if (!_esFiscal && _direccionCtrl.text.trim() != (p.direccion ?? '')) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _original = widget.socio;
    _tipoSocio = widget.socio.tipoSocio;
    _fechaIngreso = widget.socio.fechaIngreso;

    _nombreCtrl = TextEditingController();
    _apellidoCtrl = TextEditingController();
    _dniCtrl = TextEditingController();
    _telefonoCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _direccionCtrl = TextEditingController();
    _razonSocialCtrl = TextEditingController();
    _cuitCtrl = TextEditingController();
    _observacionesCtrl =
        TextEditingController(text: widget.socio.observaciones ?? '');

    _personaFuture = _personaRepo.obtenerPorId(widget.socio.personaId);
    _cargarSubtipos(widget.socio.tipoSocio);
  }

  void _initPersona(Persona p) {
    if (_personaInicializada) return;
    _personaInicializada = true;
    _personaOriginal = p;
    _nombreCtrl.text = p.nombre;
    _apellidoCtrl.text = p.apellido;
    _dniCtrl.text = p.dni ?? '';
    _telefonoCtrl.text = p.telefono ?? '';
    _emailCtrl.text = p.email ?? '';
    _direccionCtrl.text = p.direccion ?? '';
    _razonSocialCtrl.text = p.razonSocial ?? '';
    _cuitCtrl.text = p.cuit ?? '';
    _fechaNacimiento = p.fechaNacimiento;
    _subtipoId = p.subtipo;
  }

  void _cargarSubtipos(String tipoSocio) {
    _subtiposSub?.cancel();
    _subtiposSub = _socioRepo.obtenerSubtipos(tipoSocio).listen((list) {
      if (!mounted) return;
      setState(() {
        _subtipos = list;
        if (_subtipoId != null && !list.any((s) => s.id == _subtipoId)) {
          _subtipoId = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _subtiposSub?.cancel();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _dniCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _direccionCtrl.dispose();
    _razonSocialCtrl.dispose();
    _cuitCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _saving = true);
    try {
      final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
      final personaProvider = context.read<PersonaProvider>();
      final socioProvider = context.read<SocioProvider>();
      final p = _personaOriginal!;

      final personaActualizada = p.copyWith(
        nombre: _esFiscal ? p.nombre : _nombreCtrl.text.trim(),
        apellido: _esFiscal ? p.apellido : _apellidoCtrl.text.trim(),
        dni: _esFiscal
            ? p.dni
            : (_dniCtrl.text.trim().isEmpty ? null : _dniCtrl.text.trim()),
        fechaNacimiento: _esFiscal ? p.fechaNacimiento : _fechaNacimiento,
        telefono: _telefonoCtrl.text.trim().isEmpty
            ? null
            : _telefonoCtrl.text.trim(),
        email:
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        direccion: _esFiscal
            ? p.direccion
            : (_direccionCtrl.text.trim().isEmpty
                ? null
                : _direccionCtrl.text.trim()),
        razonSocial: _esFiscal ? _razonSocialCtrl.text.trim() : p.razonSocial,
        cuit: _esFiscal
            ? (_cuitCtrl.text.trim().isEmpty ? null : _cuitCtrl.text.trim())
            : p.cuit,
        subtipo: _esFiscal ? p.subtipo : _subtipoId,
      );
      await personaProvider.actualizar(personaActualizada);

      final socioActualizado = _original.copyWith(
        tipoSocio: _tipoSocio!,
        observaciones: _observacionesCtrl.text.trim().isEmpty
            ? null
            : _observacionesCtrl.text.trim(),
        fechaIngreso: _fechaIngreso,
      );
      await socioProvider.actualizar(socioActualizado, uid);

      if (mounted) {
        setState(() {
          _original = socioActualizado;
          _personaOriginal = personaActualizada;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados'),
            backgroundColor: AppTheme.verdeTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppTheme.rojoGasto),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveSocio = context.select<SocioProvider, Socio?>((p) {
          try {
            return p.todos.firstWhere((e) => e.id == widget.socio.id);
          } catch (_) {
            return null;
          }
        }) ??
        _original;

    final auth = context.watch<AuthProvider>();
    final puedeGestionar = auth.esAdmin || auth.esEditor;
    final tipos = context.watch<SocioProvider>().tipos;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
        title: Text(_personaOriginal?.nombreCompleto ?? 'Socio'),
      ),
      body: FutureBuilder<Persona?>(
        future: _personaFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final persona = snap.data;
          if (persona == null) {
            return const Center(
              child: Text('No se encontró la persona vinculada a este socio.'),
            );
          }
          _initPersona(persona);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  _PersonaCard(
                    esFiscal: _esFiscal,
                    nombreCtrl: _nombreCtrl,
                    apellidoCtrl: _apellidoCtrl,
                    dniCtrl: _dniCtrl,
                    telefonoCtrl: _telefonoCtrl,
                    emailCtrl: _emailCtrl,
                    direccionCtrl: _direccionCtrl,
                    razonSocialCtrl: _razonSocialCtrl,
                    cuitCtrl: _cuitCtrl,
                    fechaNacimiento: _fechaNacimiento,
                    puedeGestionar: puedeGestionar,
                    onFieldChanged: () => setState(() {}),
                    onFechaNacimientoChanged: (d) =>
                        setState(() => _fechaNacimiento = d),
                  ),
                  const SizedBox(height: 12),
                  _EditCard(
                    tipos: tipos,
                    tipoSocio: _tipoSocio,
                    subtipoId: _subtipoId,
                    subtipos: _subtipos,
                    esFiscal: _esFiscal,
                    observacionesCtrl: _observacionesCtrl,
                    fechaIngreso: _fechaIngreso,
                    puedeGestionar: puedeGestionar,
                    socioActivo: liveSocio.activo,
                    onTipoChanged: puedeGestionar
                        ? (v) {
                            setState(() {
                              _tipoSocio = v;
                              _subtipoId = null;
                              _subtipos = [];
                            });
                            if (v != null) _cargarSubtipos(v);
                          }
                        : null,
                    onSubtipoChanged: puedeGestionar
                        ? (v) => setState(() => _subtipoId = v)
                        : null,
                    onFechaChanged: (d) => setState(() => _fechaIngreso = d),
                    onFieldChanged: () => setState(() {}),
                    onActivoChanged: (v) => context
                        .read<SocioProvider>()
                        .activarDesactivar(widget.socio.id, v),
                  ),
                  const SizedBox(height: 12),
                  _CuotasCard(
                      socioId: widget.socio.id,
                      puedeGestionar: puedeGestionar),
                  if (_hayCambios && puedeGestionar) const SizedBox(height: 72),
                  const SizedBox(height: 20),
                ],
              ),
              if (_hayCambios && puedeGestionar)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.verdeTeal,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _saving ? null : _guardar,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Guardar cambios'),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── _PersonaCard ──────────────────────────────────────────────────────────────

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.esFiscal,
    required this.nombreCtrl,
    required this.apellidoCtrl,
    required this.dniCtrl,
    required this.telefonoCtrl,
    required this.emailCtrl,
    required this.direccionCtrl,
    required this.razonSocialCtrl,
    required this.cuitCtrl,
    required this.fechaNacimiento,
    required this.puedeGestionar,
    required this.onFieldChanged,
    required this.onFechaNacimientoChanged,
  });

  final bool esFiscal;
  final TextEditingController nombreCtrl;
  final TextEditingController apellidoCtrl;
  final TextEditingController dniCtrl;
  final TextEditingController telefonoCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController direccionCtrl;
  final TextEditingController razonSocialCtrl;
  final TextEditingController cuitCtrl;
  final DateTime? fechaNacimiento;
  final bool puedeGestionar;
  final VoidCallback onFieldChanged;
  final ValueChanged<DateTime> onFechaNacimientoChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 18, color: AppTheme.azulMedio),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    esFiscal ? 'Datos de la entidad' : 'Datos personales',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textoPrincipal,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (esFiscal) ...[
              TextFormField(
                controller: razonSocialCtrl,
                decoration:
                    const InputDecoration(labelText: 'Razón social'),
                textCapitalization: TextCapitalization.words,
                readOnly: !puedeGestionar,
                onChanged: (_) => onFieldChanged(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: cuitCtrl,
                decoration: const InputDecoration(labelText: 'CUIT'),
                keyboardType: TextInputType.number,
                readOnly: !puedeGestionar,
                onChanged: (_) => onFieldChanged(),
              ),
            ] else ...[
              TextFormField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.words,
                readOnly: !puedeGestionar,
                onChanged: (_) => onFieldChanged(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: apellidoCtrl,
                decoration: const InputDecoration(labelText: 'Apellido'),
                textCapitalization: TextCapitalization.words,
                readOnly: !puedeGestionar,
                onChanged: (_) => onFieldChanged(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: dniCtrl,
                decoration: const InputDecoration(labelText: 'DNI'),
                keyboardType: TextInputType.number,
                readOnly: !puedeGestionar,
                onChanged: (_) => onFieldChanged(),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: puedeGestionar
                    ? () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: fechaNacimiento ?? DateTime(2000),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) onFechaNacimientoChanged(d);
                      }
                    : null,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Fecha de nacimiento'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(fechaNacimiento == null
                          ? '—'
                          : _fmtFecha(fechaNacimiento!)),
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppTheme.azulMedio),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: direccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
                readOnly: !puedeGestionar,
                onChanged: (_) => onFieldChanged(),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: telefonoCtrl,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              keyboardType: TextInputType.phone,
              readOnly: !puedeGestionar,
              onChanged: (_) => onFieldChanged(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              readOnly: !puedeGestionar,
              onChanged: (_) => onFieldChanged(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _EditCard ─────────────────────────────────────────────────────────────────

class _EditCard extends StatelessWidget {
  const _EditCard({
    required this.tipos,
    required this.tipoSocio,
    required this.subtipoId,
    required this.subtipos,
    required this.esFiscal,
    required this.observacionesCtrl,
    required this.fechaIngreso,
    required this.puedeGestionar,
    required this.socioActivo,
    required this.onTipoChanged,
    required this.onSubtipoChanged,
    required this.onFechaChanged,
    required this.onFieldChanged,
    required this.onActivoChanged,
  });

  final List<TipoSocio> tipos;
  final String? tipoSocio;
  final String? subtipoId;
  final List<SubtipoSocio> subtipos;
  final bool esFiscal;
  final TextEditingController observacionesCtrl;
  final DateTime fechaIngreso;
  final bool puedeGestionar;
  final bool socioActivo;
  final ValueChanged<String?>? onTipoChanged;
  final ValueChanged<String?>? onSubtipoChanged;
  final ValueChanged<DateTime> onFechaChanged;
  final VoidCallback onFieldChanged;
  final ValueChanged<bool> onActivoChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined,
                    size: 18, color: AppTheme.azulMedio),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Datos de socio',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textoPrincipal,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // Tipo socio
            esFiscal
                ? const InputDecorator(
                    decoration: InputDecoration(labelText: 'Tipo de socio'),
                    child: Text('Honorario'),
                  )
                : (tipos.isEmpty
                    ? const InputDecorator(
                        decoration:
                            InputDecoration(labelText: 'Tipo de socio'),
                        child: Text(
                          'Cargando…',
                          style: TextStyle(color: AppTheme.textoSecundario),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        key: ValueKey(tipoSocio),
                        initialValue: tipoSocio,
                        decoration: const InputDecoration(
                            labelText: 'Tipo de socio'),
                        items: tipos
                            .where((t) => t.id != 'honorario')
                            .map((t) => DropdownMenuItem<String>(
                                value: t.id, child: Text(t.nombre)))
                            .toList(),
                        onChanged: onTipoChanged,
                      )),
            if (!esFiscal) ...[
              const SizedBox(height: 12),
              subtipos.isEmpty
                  ? const InputDecorator(
                      decoration: InputDecoration(labelText: 'Subtipo'),
                      child: Text(
                        'Cargando…',
                        style: TextStyle(color: AppTheme.textoSecundario),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      key: ValueKey(subtipoId),
                      initialValue: subtipoId,
                      decoration:
                          const InputDecoration(labelText: 'Subtipo'),
                      items: subtipos
                          .map((s) => DropdownMenuItem(
                              value: s.id, child: Text(s.nombre)))
                          .toList(),
                      onChanged: onSubtipoChanged,
                    ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: puedeGestionar
                  ? () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: fechaIngreso,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) onFechaChanged(d);
                    }
                  : null,
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Fecha de ingreso'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmtFecha(fechaIngreso)),
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppTheme.azulMedio),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: observacionesCtrl,
              decoration:
                  const InputDecoration(labelText: 'Observaciones'),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              readOnly: !puedeGestionar,
              onChanged: (_) => onFieldChanged(),
            ),
            if (puedeGestionar) ...[
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Socio habilitado',
                    style: TextStyle(fontSize: 14)),
                value: socioActivo,
                activeThumbColor: AppTheme.verdeTeal,
                onChanged: onActivoChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _CuotasCard ───────────────────────────────────────────────────────────────

class _CuotasCard extends StatefulWidget {
  const _CuotasCard(
      {required this.socioId, required this.puedeGestionar});
  final String socioId;
  final bool puedeGestionar;

  @override
  State<_CuotasCard> createState() => _CuotasCardState();
}

class _CuotasCardState extends State<_CuotasCard> {
  final _cuotaRepo = CuotaRepository();
  late final Stream<List<Cuota>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _cuotaRepo.obtenerPorSocio(widget.socioId);
  }

  void _abrirModalPago() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ModalPago(
        socioId: widget.socioId,
        onGuardar: (c) =>
            context.read<CuotaProvider>().registrarPago(c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuotaProv = context.watch<CuotaProvider>();
    final metodosPago =
        context.watch<MetodoPagoProvider>().metodosPago;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 18, color: AppTheme.verdeIngreso),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Cuotas',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textoPrincipal,
                    ),
                  ),
                ),
                if (widget.puedeGestionar)
                  TextButton.icon(
                    onPressed: _abrirModalPago,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Registrar pago'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.verdeTeal),
                  ),
              ],
            ),
            const Divider(height: 16),
            StreamBuilder<List<Cuota>>(
              stream: _stream,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final cuotas = snap.data ?? [];
                if (cuotas.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sin pagos registrados.',
                      style:
                          TextStyle(color: AppTheme.textoSecundario),
                    ),
                  );
                }
                return Column(
                  children: cuotas.map((c) {
                    final tipoNombre =
                        cuotaProv.nombreTipoCuota(c.tipoCuotaId);
                    final metodo = metodosPago
                        .where((m) => m['id'] == c.metodoPagoId)
                        .firstOrNull;
                    final metodoNombre =
                        metodo?['nombre'] as String? ?? c.metodoPagoId;
                    return _CuotaTile(
                      cuota: c,
                      tipoNombre: tipoNombre,
                      metodoNombre: metodoNombre,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CuotaTile extends StatelessWidget {
  const _CuotaTile({
    required this.cuota,
    required this.tipoNombre,
    required this.metodoNombre,
  });

  final Cuota cuota;
  final String tipoNombre;
  final String metodoNombre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 18, color: AppTheme.verdeIngreso),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      cuota.periodo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textoPrincipal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _fmtMonto(cuota.monto),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.verdeIngreso,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$tipoNombre · $metodoNombre · ${_fmtFecha(cuota.fechaPago)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textoSecundario,
                  ),
                ),
                if (cuota.usuarioId.isNotEmpty)
                  NombreUsuarioWidget(
                    usuarioId: cuota.usuarioId,
                    prefijo: 'Registrado por: ',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textoSecundario),
                  ),
                if (cuota.observaciones != null &&
                    cuota.observaciones!.isNotEmpty)
                  Text(
                    cuota.observaciones!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textoSecundario,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          if (cuota.comprobante != null)
            IconButton(
              icon: const Icon(Icons.receipt, size: 20),
              color: AppTheme.azulMedio,
              tooltip: 'Ver comprobante',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () async {
                final uri = Uri.parse(cuota.comprobante!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
    );
  }
}

// ── _ModalPago ────────────────────────────────────────────────────────────────

class _ModalPago extends StatefulWidget {
  const _ModalPago({required this.socioId, required this.onGuardar});
  final String socioId;
  final Future<void> Function(Cuota) onGuardar;

  @override
  State<_ModalPago> createState() => _ModalPagoState();
}

class _ModalPagoState extends State<_ModalPago> {
  final _form = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _periodoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  String? _tipoCuotaId;
  String? _metodoPagoId;
  DateTime _fechaPago = DateTime.now();
  bool _saving = false;
  bool _cargandoTarifa = false;
  bool _subiendo = false;
  String? _nombreComprobante;
  Uint8List? _comprobanteBytes;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodoCtrl.text =
        '${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _periodoCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _adjuntarComprobante() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _nombreComprobante = result.files.first.name;
        _comprobanteBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> _onTipoCuotaChanged(String? tipoCuotaId) async {
    setState(() {
      _tipoCuotaId = tipoCuotaId;
      _cargandoTarifa = true;
    });
    if (tipoCuotaId == null) {
      setState(() => _cargandoTarifa = false);
      return;
    }
    try {
      final tarifa = await context
          .read<CuotaProvider>()
          .obtenerTarifaVigente(tipoCuotaId);
      if (mounted) {
        _montoCtrl.text = tarifa != null
            ? NumberFormat('#,##0.##', 'es_AR').format(tarifa.monto)
            : '';
      }
    } finally {
      if (mounted) setState(() => _cargandoTarifa = false);
    }
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final monto = double.tryParse(
        _montoCtrl.text.replaceAll('.', '').replaceAll(',', '.'));
    // Capturar uid y messenger antes de cualquier gap asíncrono
    final uid = context.read<AuthProvider>().currentUser?.uid ?? '';
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un monto válido')),
      );
      return;
    }
    // Subir comprobante si hay archivo seleccionado
    String? comprobanteUrl;
    if (_comprobanteBytes != null && _nombreComprobante != null) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _subiendo = true);
      try {
        final now2 = DateTime.now();
        final path =
            'cuotas/${now2.year}/${now2.month.toString().padLeft(2, '0')}';
        comprobanteUrl = await StorageService().subirComprobante(
            path, _comprobanteBytes!, _nombreComprobante!);
      } catch (e) {
        messenger.showSnackBar(SnackBar(
          content: Text('No se pudo subir el comprobante: $e'),
          backgroundColor: AppTheme.rojoGasto,
        ));
      } finally {
        if (mounted) setState(() => _subiendo = false);
      }
    }

    setState(() => _saving = true);
    try {
      final cuota = Cuota(
        id: '',
        socioId: widget.socioId,
        tipoCuotaId: _tipoCuotaId!,
        periodo: _periodoCtrl.text.trim(),
        moneda: 'ARS',
        metodoPagoId: _metodoPagoId!,
        usuarioId: uid,
        observaciones:
            _observacionesCtrl.text.trim().isEmpty
                ? null
                : _observacionesCtrl.text.trim(),
        comprobante: comprobanteUrl,
        monto: monto,
        fechaPago: _fechaPago,
        fechaCreacion: DateTime.now(),
      );
      await widget.onGuardar(cuota);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiposCuota = context.watch<CuotaProvider>().tiposCuota;
    final metodos =
        context.watch<MetodoPagoProvider>().obtenerActivos();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registrar pago',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _tipoCuotaId,
                decoration: const InputDecoration(
                    labelText: 'Tipo de cuota *'),
                items: tiposCuota
                    .map((t) => DropdownMenuItem(
                        value: t.id, child: Text(t.nombre)))
                    .toList(),
                onChanged: _onTipoCuotaChanged,
                validator: (v) => v == null ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _periodoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Período *',
                  helperText: 'Formato: MM/AAAA',
                  hintText: '06/2026',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  final parts = v.split('/');
                  if (parts.length != 2) return 'Formato: MM/AAAA';
                  final mes = int.tryParse(parts[0]);
                  final anio = int.tryParse(parts[1]);
                  if (mes == null || mes < 1 || mes > 12) {
                    return 'Mes inválido (01-12)';
                  }
                  if (anio == null || anio < 2000) return 'Año inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _montoCtrl,
                decoration: InputDecoration(
                  labelText: 'Monto *',
                  prefixText: '\$ ',
                  suffixIcon: _cargandoTarifa
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _metodoPagoId,
                decoration: const InputDecoration(
                    labelText: 'Método de pago *'),
                items: metodos
                    .map((m) => DropdownMenuItem(
                          value: m['id'] as String,
                          child: MetodoPagoRow(
                              nombre: m['nombre'] as String),
                        ))
                    .toList(),
                selectedItemBuilder: (context) => metodos
                    .map((m) => Text(m['nombre'] as String,
                        overflow: TextOverflow.ellipsis))
                    .toList(),
                onChanged: (v) => setState(() => _metodoPagoId = v),
                validator: (v) => v == null ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _fechaPago,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _fechaPago = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Fecha de pago'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmtFecha(_fechaPago)),
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppTheme.azulMedio),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _observacionesCtrl,
                decoration: const InputDecoration(
                    labelText: 'Observaciones'),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              if (_nombreComprobante == null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Adjuntar comprobante'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.azulMedio,
                    side: const BorderSide(color: AppTheme.azulMedio),
                  ),
                  onPressed: _adjuntarComprobante,
                )
              else
                Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined,
                        size: 18, color: AppTheme.azulMedio),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _nombreComprobante!,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textoPrincipal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: AppTheme.rojoGasto,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() {
                        _nombreComprobante = null;
                        _comprobanteBytes = null;
                      }),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving || _subiendo ? null : _guardar,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Text('Registrar pago'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
