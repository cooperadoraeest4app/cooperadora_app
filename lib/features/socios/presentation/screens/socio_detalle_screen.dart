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
import '../../../admin/presentation/providers/metodo_pago_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/cuota_repository.dart';
import '../../data/repositories/socio_repository.dart';
import '../../domain/models/cuota.dart';
import '../../domain/models/integrante.dart';
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

String _tipoIntegranteLabel(String tipo) => switch (tipo) {
      'padre' => 'Padre',
      'madre' => 'Madre',
      'tutor' => 'Tutor/a',
      'alumno' => 'Alumno/a',
      _ => 'Otro',
    };

// ── SocioDetalleScreen ────────────────────────────────────────────────────────

class SocioDetalleScreen extends StatefulWidget {
  const SocioDetalleScreen({super.key, required this.socio});
  final Socio socio;

  @override
  State<SocioDetalleScreen> createState() => _SocioDetalleScreenState();
}

class _SocioDetalleScreenState extends State<SocioDetalleScreen> {
  final _socioRepo = SocioRepository();

  late Socio _original;
  String? _tipoId;
  String? _subtipoId;
  late TextEditingController _apellidoCtrl;
  late TextEditingController _razonSocialCtrl;
  late TextEditingController _cuitCtrl;
  late TextEditingController _observacionesCtrl;
  late DateTime _fechaIngreso;

  List<SubtipoSocio> _subtipos = [];
  StreamSubscription<List<SubtipoSocio>>? _subtiposSub;

  bool _saving = false;

  bool get _esHonorario => _tipoId == 'honorario';

  bool get _hayCambios {
    if (_tipoId == null) return false;
    final s = _original;
    if (_tipoId != s.tipoSocioId) return true;
    final origSubtipo =
        s.subtipoSocioId.isNotEmpty ? s.subtipoSocioId : null;
    if (_subtipoId != origSubtipo) return true;
    if (!_esHonorario) {
      if (_apellidoCtrl.text.trim().toUpperCase() !=
          (s.apellidoFamilia ?? '')) {
        return true;
      }
    } else {
      if (_razonSocialCtrl.text.trim() != (s.razonSocial ?? '')) {
        return true;
      }
      if (_cuitCtrl.text.trim() != (s.cuit ?? '')) {
        return true;
      }
    }
    if (_observacionesCtrl.text.trim() != (s.observaciones ?? '')) {
      return true;
    }
    final fi = _fechaIngreso;
    final orig = s.fechaIngreso;
    if (fi.year != orig.year || fi.month != orig.month || fi.day != orig.day) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _init(widget.socio);
  }

  void _init(Socio s) {
    _original = s;
    _tipoId = s.tipoSocioId;
    _subtipoId = s.subtipoSocioId.isNotEmpty ? s.subtipoSocioId : null;
    _apellidoCtrl = TextEditingController(text: s.apellidoFamilia ?? '');
    _razonSocialCtrl = TextEditingController(text: s.razonSocial ?? '');
    _cuitCtrl = TextEditingController(text: s.cuit ?? '');
    _observacionesCtrl = TextEditingController(text: s.observaciones ?? '');
    _fechaIngreso = s.fechaIngreso;
    if (s.tipoSocioId.isNotEmpty) _cargarSubtipos(s.tipoSocioId);
  }

  void _cargarSubtipos(String tipoId) {
    _subtiposSub?.cancel();
    _subtiposSub = _socioRepo.obtenerSubtipos(tipoId).listen((list) {
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
    _apellidoCtrl.dispose();
    _razonSocialCtrl.dispose();
    _cuitCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _saving = true);
    try {
      final updated = _original.copyWith(
        tipoSocioId: _tipoId!,
        subtipoSocioId: _subtipoId ?? '',
        apellidoFamilia: _esHonorario
            ? null
            : _apellidoCtrl.text.trim().toUpperCase(),
        clearApellidoFamilia: _esHonorario,
        razonSocial:
            _esHonorario ? _razonSocialCtrl.text.trim() : null,
        clearRazonSocial: !_esHonorario,
        cuit: _esHonorario && _cuitCtrl.text.trim().isNotEmpty
            ? _cuitCtrl.text.trim()
            : null,
        clearCuit: !_esHonorario || _cuitCtrl.text.trim().isEmpty,
        observaciones: _observacionesCtrl.text.trim().isEmpty
            ? null
            : _observacionesCtrl.text.trim(),
        clearObservaciones: _observacionesCtrl.text.trim().isEmpty,
        fechaIngreso: _fechaIngreso,
      );
      await context.read<SocioProvider>().actualizar(updated);
      if (mounted) {
        setState(() {
          _original = updated;
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
              content: Text('Error: $e'),
              backgroundColor: AppTheme.rojoGasto),
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
        title: Text(_original.nombreDisplay),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              _EditCard(
                tipos: tipos,
                tipoId: _tipoId,
                subtipoId: _subtipoId,
                subtipos: _subtipos,
                apellidoCtrl: _apellidoCtrl,
                razonSocialCtrl: _razonSocialCtrl,
                cuitCtrl: _cuitCtrl,
                observacionesCtrl: _observacionesCtrl,
                fechaIngreso: _fechaIngreso,
                esHonorario: _esHonorario,
                puedeGestionar: puedeGestionar,
                socioActivo: liveSocio.activo,
                onTipoChanged: puedeGestionar
                    ? (v) {
                        setState(() {
                          _tipoId = v;
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
              _IntegrantesCard(
                  socioId: widget.socio.id,
                  puedeGestionar: puedeGestionar),
              const SizedBox(height: 12),
              _CuotasCard(
                  socioId: widget.socio.id,
                  puedeGestionar: puedeGestionar),
              if (_hayCambios && puedeGestionar)
                const SizedBox(height: 72),
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
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Text('Guardar cambios'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── _EditCard ─────────────────────────────────────────────────────────────────

class _EditCard extends StatelessWidget {
  const _EditCard({
    required this.tipos,
    required this.tipoId,
    required this.subtipoId,
    required this.subtipos,
    required this.apellidoCtrl,
    required this.razonSocialCtrl,
    required this.cuitCtrl,
    required this.observacionesCtrl,
    required this.fechaIngreso,
    required this.esHonorario,
    required this.puedeGestionar,
    required this.socioActivo,
    required this.onTipoChanged,
    required this.onSubtipoChanged,
    required this.onFechaChanged,
    required this.onFieldChanged,
    required this.onActivoChanged,
  });

  final List<TipoSocio> tipos;
  final String? tipoId;
  final String? subtipoId;
  final List<SubtipoSocio> subtipos;
  final TextEditingController apellidoCtrl;
  final TextEditingController razonSocialCtrl;
  final TextEditingController cuitCtrl;
  final TextEditingController observacionesCtrl;
  final DateTime fechaIngreso;
  final bool esHonorario;
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
            // Tipo socio
            tipos.isEmpty
                ? const InputDecorator(
                    decoration:
                        InputDecoration(labelText: 'Tipo de socio'),
                    child: Text(
                      'Cargando…',
                      style:
                          TextStyle(color: AppTheme.textoSecundario),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    key: ValueKey(tipoId),
                    initialValue: tipoId,
                    decoration: const InputDecoration(
                        labelText: 'Tipo de socio'),
                    items: tipos
                        .map((t) => DropdownMenuItem<String>(
                            value: t.id, child: Text(t.nombre)))
                        .toList(),
                    onChanged: onTipoChanged,
                  ),
            const SizedBox(height: 12),
            // Subtipo
            if (tipoId != null)
              subtipos.isEmpty
                  ? const InputDecorator(
                      decoration: InputDecoration(labelText: 'Subtipo'),
                      child: Text(
                        'Cargando…',
                        style:
                            TextStyle(color: AppTheme.textoSecundario),
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
            if (tipoId != null) ...[
              const SizedBox(height: 12),
              // Nombre field (conditional on tipo)
              if (esHonorario) ...[
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
                  decoration:
                      const InputDecoration(labelText: 'CUIT'),
                  keyboardType: TextInputType.number,
                  readOnly: !puedeGestionar,
                  onChanged: (_) => onFieldChanged(),
                ),
              ] else
                TextFormField(
                  controller: apellidoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Apellido de familia',
                    helperText: 'Se guarda en mayúsculas',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  readOnly: !puedeGestionar,
                  onChanged: (_) => onFieldChanged(),
                ),
              const SizedBox(height: 12),
            ],
            // Fecha de ingreso
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
            // Observaciones
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

// ── _Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── _IntegrantesCard ──────────────────────────────────────────────────────────

class _IntegrantesCard extends StatefulWidget {
  const _IntegrantesCard(
      {required this.socioId, required this.puedeGestionar});
  final String socioId;
  final bool puedeGestionar;

  @override
  State<_IntegrantesCard> createState() => _IntegrantesCardState();
}

class _IntegrantesCardState extends State<_IntegrantesCard> {
  final _repo = SocioRepository();
  late final Stream<List<Integrante>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repo.obtenerIntegrantes(widget.socioId);
  }

  void _abrirModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ModalIntegrante(
        socioId: widget.socioId,
        onGuardar: (i) => _repo.agregarIntegrante(i),
      ),
    );
  }

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
                const Icon(Icons.group_outlined,
                    size: 18, color: AppTheme.azulMedio),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Integrantes',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textoPrincipal,
                    ),
                  ),
                ),
                if (widget.puedeGestionar)
                  TextButton.icon(
                    onPressed: _abrirModal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.verdeTeal),
                  ),
              ],
            ),
            const Divider(height: 16),
            StreamBuilder<List<Integrante>>(
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
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Sin integrantes registrados.',
                      style:
                          TextStyle(color: AppTheme.textoSecundario),
                    ),
                  );
                }
                return Column(
                  children: items
                      .map((i) => _IntegranteTile(
                            integrante: i,
                            puedeGestionar: widget.puedeGestionar,
                            onEliminar: () =>
                                _repo.eliminarIntegrante(i.id),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IntegranteTile extends StatelessWidget {
  const _IntegranteTile({
    required this.integrante,
    required this.puedeGestionar,
    required this.onEliminar,
  });

  final Integrante integrante;
  final bool puedeGestionar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  integrante.nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  children: [
                    _Chip(
                      label: _tipoIntegranteLabel(integrante.tipo),
                      color: AppTheme.azulMedio,
                    ),
                    if (integrante.grado != null &&
                        integrante.grado!.isNotEmpty)
                      _Chip(
                        label: integrante.grado!,
                        color: AppTheme.textoSecundario,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (puedeGestionar)
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppTheme.rojoGasto,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Eliminar integrante'),
                      content: Text(
                          '¿Eliminás a ${integrante.nombre}?'),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: const Text('Cancelar')),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, true),
                          child: const Text('Eliminar',
                              style: TextStyle(
                                  color: AppTheme.rojoGasto)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) onEliminar();
                },
              ),
            ),
        ],
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

// ── _ModalIntegrante ──────────────────────────────────────────────────────────

class _ModalIntegrante extends StatefulWidget {
  const _ModalIntegrante(
      {required this.socioId, required this.onGuardar});
  final String socioId;
  final Future<void> Function(Integrante) onGuardar;

  @override
  State<_ModalIntegrante> createState() => _ModalIntegranteState();
}

class _ModalIntegranteState extends State<_ModalIntegrante> {
  final _form = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _gradoCtrl = TextEditingController();
  String _tipo = 'alumno';
  bool _saving = false;

  static const _tipos = [
    ('alumno', 'Alumno/a'),
    ('padre', 'Padre'),
    ('madre', 'Madre'),
    ('tutor', 'Tutor/a'),
    ('otro', 'Otro'),
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _gradoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final integrante = Integrante(
        id: '',
        socioId: widget.socioId,
        tipo: _tipo,
        personaId: '',
        nombre: _nombreCtrl.text.trim(),
        grado: _tipo == 'alumno' && _gradoCtrl.text.trim().isNotEmpty
            ? _gradoCtrl.text.trim()
            : null,
        fechaCreacion: DateTime.now(),
      );
      await widget.onGuardar(integrante);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Agregar integrante',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration:
                    const InputDecoration(labelText: 'Tipo *'),
                items: _tipos
                    .map((t) => DropdownMenuItem(
                        value: t.$1, child: Text(t.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _tipo = v ?? 'alumno'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nombre completo *'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              if (_tipo == 'alumno') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gradoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Grado',
                    helperText: 'Ej: 3° "A"',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _guardar,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Text('Agregar'),
                ),
              ),
            ],
          ),
        ),
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
        _montoCtrl.text =
            tarifa != null ? tarifa.monto.toStringAsFixed(2) : '';
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
