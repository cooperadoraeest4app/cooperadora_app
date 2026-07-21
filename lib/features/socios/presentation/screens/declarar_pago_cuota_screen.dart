import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DeclararPagoCuotaScreen extends StatefulWidget {
  const DeclararPagoCuotaScreen({super.key});

  @override
  State<DeclararPagoCuotaScreen> createState() =>
      _DeclararPagoCuotaScreenState();
}

class _DeclararPagoCuotaScreenState extends State<DeclararPagoCuotaScreen> {
  final _montoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  DateTime _fechaPago = DateTime.now();
  String? _nombreComprobante;
  Uint8List? _comprobanteBytes;
  bool _guardando = false;
  bool _cargandoTarifa = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTarifa());
  }

  Future<void> _cargarTarifa() async {
    try {
      // Buscar tipo de cuota mensual
      final tiposSnap = await FirebaseFirestore.instance
          .collection('tipos_cuota')
          .get();
      if (!mounted || tiposSnap.docs.isEmpty) return;

      // ignore: avoid_print
      print('[DeclararPago] tipos: ${tiposSnap.docs.map((d) => '${d.id}: ${d.data()['nombre']}').toList()}');

      final tipoMensual = tiposSnap.docs.firstWhere(
        (d) => (d.data()['nombre'] as String? ?? '')
            .toLowerCase()
            .contains('mensual'),
        orElse: () => tiposSnap.docs.first,
      );

      // ignore: avoid_print
      print('[DeclararPago] tipo mensual seleccionado: ${tipoMensual.id} — ${tipoMensual.data()['nombre']}');

      final tarifaSnap = await FirebaseFirestore.instance
          .collection('tarifas_cuota')
          .where('tipoCuotaId', isEqualTo: tipoMensual.id)
          .orderBy('vigenciaDesde', descending: true)
          .limit(1)
          .get();

      // ignore: avoid_print
      print('[DeclararPago] tarifas encontradas: ${tarifaSnap.docs.length}');

      if (!mounted || tarifaSnap.docs.isEmpty) return;
      final monto =
          (tarifaSnap.docs.first.data()['monto'] as num).toDouble();

      // ignore: avoid_print
      print('[DeclararPago] monto: $monto');

      if (_montoCtrl.text.isEmpty) {
        setState(() {
          _montoCtrl.text = monto == monto.truncateToDouble()
              ? monto.toInt().toString()
              : monto.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _cargandoTarifa = false);
    }
  }

  Future<void> _seleccionarFoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer el archivo')),
        );
      }
      return;
    }
    setState(() {
      _nombreComprobante = file.name;
      _comprobanteBytes = file.bytes;
    });
  }

  Future<void> _adjuntarArchivo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer el archivo')),
        );
      }
      return;
    }
    setState(() {
      _nombreComprobante = file.name;
      _comprobanteBytes = file.bytes;
    });
  }

  Future<void> _guardar() async {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      _snack('Ingresá un monto válido');
      return;
    }
    if (_comprobanteBytes == null || _nombreComprobante == null) {
      _snack('Adjuntá el comprobante de pago');
      return;
    }

    setState(() => _guardando = true);
    try {
      final auth = context.read<AuthProvider>();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final socioId = auth.socioId;
      if (uid == null || socioId == null) {
        _snack('No se pudo identificar tu cuenta de socio');
        return;
      }

      // Upload comprobante (within existing /comprobantes/** storage rule)
      final ext = _nombreComprobante!.split('.').last;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref('comprobantes/pagos_pendientes/$socioId/$ts.$ext');
      await ref.putData(_comprobanteBytes!);
      final comprobanteUrl = await ref.getDownloadURL();

      // Resolve nombre del socio
      String nombreSocio = '';
      int numeroSocio = 0;
      final socioDoc = await FirebaseFirestore.instance
          .collection('socios')
          .doc(socioId)
          .get();
      if (socioDoc.exists) {
        final data = socioDoc.data()!;
        numeroSocio = (data['numeroSocio'] as num? ?? 0).toInt();
        final personaId = data['personaId'] as String?;
        if (personaId != null) {
          final personaDoc = await FirebaseFirestore.instance
              .collection('personas')
              .doc(personaId)
              .get();
          if (personaDoc.exists) {
            final pd = personaDoc.data()!;
            nombreSocio =
                '${pd['nombre'] ?? ''} ${pd['apellido'] ?? ''}'.trim();
          }
        }
      }

      // Write pagos_pendientes
      final pagoRef =
          FirebaseFirestore.instance.collection('pagos_pendientes').doc();
      await pagoRef.set({
        'socioId': socioId,
        'usuarioUid': uid,
        'monto': monto,
        'fechaPago': Timestamp.fromDate(_fechaPago),
        'comprobanteUrl': comprobanteUrl,
        'observaciones':
            _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
        'estado': 'pendiente',
        'creadoEn': FieldValue.serverTimestamp(),
        'nombreSocio': nombreSocio,
        'numeroSocio': numeroSocio,
      });

      // Write notificacion for editors
      await FirebaseFirestore.instance.collection('notificaciones').add({
        'tipo': 'pago_declarado',
        'pagoPendienteId': pagoRef.id,
        'socioId': socioId,
        'destinatarioRol': 'editor',
        'destinatarioUid': null,
        'leida': false,
        'creadoEn': FieldValue.serverTimestamp(),
        'monto': monto,
        'nombreSocio': nombreSocio,
        'numeroSocio': numeroSocio,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago declarado. Un editor lo confirmará pronto.'),
          backgroundColor: AppTheme.verdeTeal,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.rojoGasto),
    );
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Declarar pago de cuota'),
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Categoría fija
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Categoría'),
            child: const Text('Cuota Social',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 12),

          // Método fijo
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Método de pago'),
            child: const Text('Transferencia',
                style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 12),

          // Monto
          TextFormField(
            controller: _montoCtrl,
            decoration: InputDecoration(
              labelText: 'Monto *',
              prefixText: '\$ ',
              suffixIcon: _cargandoTarifa
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))
            ],
          ),
          const SizedBox(height: 12),

          // Fecha
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _fechaPago,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _fechaPago = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha de pago *',
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
              ),
              child: Text(DateFormat('dd/MM/yyyy').format(_fechaPago)),
            ),
          ),
          const SizedBox(height: 12),

          // Comprobante — mismo patrón que AgregarMovimientoScreen
          const Text(
            'Comprobante *',
            style: TextStyle(
                fontSize: 13, color: AppTheme.textoSecundario),
          ),
          const SizedBox(height: 6),
          if (_nombreComprobante != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.azulMedio.withAlpha(25),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                border: Border.all(color: AppTheme.azulMedio.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      size: 18, color: AppTheme.azulMedio),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _nombreComprobante!,
                      style: const TextStyle(
                          color: AppTheme.azulMedio, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _nombreComprobante = null;
                      _comprobanteBytes = null;
                    }),
                    child: const Icon(Icons.close,
                        size: 18, color: AppTheme.textoSecundario),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.azulMedio,
                    side: const BorderSide(color: AppTheme.azulMedio),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _seleccionarFoto,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Sacar foto'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.azulMedio,
                    side: const BorderSide(color: AppTheme.azulMedio),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _adjuntarArchivo,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Adjuntar archivo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Observaciones
          TextFormField(
            controller: _obsCtrl,
            decoration:
                const InputDecoration(labelText: 'Observaciones (opcional)'),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.azulOscuro,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enviar declaración',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
