import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../admin/domain/models/persona.dart';
import '../../../admin/presentation/providers/configuracion_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/socio_repository.dart';
import '../../domain/models/socio.dart';

class CredencialSocioScreen extends StatefulWidget {
  const CredencialSocioScreen({super.key});

  @override
  State<CredencialSocioScreen> createState() => _CredencialSocioScreenState();
}

class _CredencialSocioScreenState extends State<CredencialSocioScreen> {
  static const _tarjetaFormato = PdfPageFormat(
    85.6 * PdfPageFormat.mm,
    54.0 * PdfPageFormat.mm,
    marginAll: 0,
  );

  Socio? _socio;
  Persona? _persona;
  String? _logoUrl;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final auth = context.read<AuthProvider>();
      final socioId = auth.socioId;
      if (socioId == null) {
        setState(() {
          _error = 'No tenés un socio vinculado a tu cuenta.';
          _loading = false;
        });
        return;
      }

      final socio = await SocioRepository().obtenerPorId(socioId);
      if (socio == null) throw Exception('Socio no encontrado.');

      final personaDoc = await FirebaseFirestore.instance
          .collection('personas')
          .doc(socio.personaId)
          .get();
      if (!personaDoc.exists) throw Exception('Datos de persona no encontrados.');
      final persona = Persona.fromMap(personaDoc.data()!, personaDoc.id);

      final configDoc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('config')
          .get();
      final logoUrl = configDoc.data()?['logoUrl'] as String?;

      if (mounted) {
        setState(() {
          _socio = socio;
          _persona = persona;
          _logoUrl = logoUrl;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String get _qrData => jsonEncode({
        'socioId': _socio!.id,
        'numeroSocio': _socio!.numeroSocio,
        'nombre': _persona!.nombreCompleto,
        'dni': _persona!.dni ?? '',
      });

  void _mostrarQRAmpliado() {
    final qrData = _qrData;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _persona!.nombreCompleto,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.azulOscuro),
              ),
              Text(
                'Socio N°${_socio!.numeroSocio.toString().padLeft(3, '0')}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.azulOscuro, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _imprimir() async {
    await Printing.layoutPdf(
      onLayout: (_) => _generarPDF(_tarjetaFormato),
      format: _tarjetaFormato,
      name: 'credencial_socio_${_socio!.numeroSocio}',
    );
  }

  Future<void> _descargarPDF() async {
    final pdfBytes = await _generarPDF(_tarjetaFormato);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename:
          'credencial_socio_${_socio!.numeroSocio.toString().padLeft(3, '0')}.pdf',
    );
  }

  Future<Uint8List> _generarPDF(PdfPageFormat format) async {
    final qrData = _qrData;
    final cooperadoraNombre =
        context.read<ConfiguracionProvider>().nombreCooperadora;

    final qrPainter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      gapless: true,
    );
    final qrByteData =
        await qrPainter.toImageData(200, format: ui.ImageByteFormat.png);
    final qrBytes = qrByteData?.buffer.asUint8List();

    Uint8List? logoBytes;
    if (_logoUrl != null) {
      try {
        final request = await HttpClient().getUrl(Uri.parse(_logoUrl!));
        final response = await request.close();
        final chunks = <int>[];
        await for (final chunk in response) {
          chunks.addAll(chunk);
        }
        logoBytes = Uint8List.fromList(chunks);
      } catch (_) {}
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: _tarjetaFormato,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => _buildCredencialPDF(
          qrBytes: qrBytes,
          logoBytes: logoBytes,
          cooperadoraNombre: cooperadoraNombre.isNotEmpty
              ? cooperadoraNombre
              : 'Cooperadora Escolar',
        ),
      ),
    );
    return doc.save();
  }

  pw.Widget _buildCredencialPDF({
    Uint8List? qrBytes,
    Uint8List? logoBytes,
    required String cooperadoraNombre,
  }) {
    final socio = _socio!;
    final persona = _persona!;
    const azulOscuro = PdfColor.fromInt(0xFF1A237E);
    const celesteFondo = PdfColor.fromInt(0xFFE8EAF6);

    return pw.Container(
      width: 85.6 * PdfPageFormat.mm,
      height: 54.0 * PdfPageFormat.mm,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: azulOscuro, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        children: [
          // Header
          pw.Container(
            height: 26,
            decoration: const pw.BoxDecoration(
              color: azulOscuro,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Row(
              children: [
                if (logoBytes != null)
                  pw.Container(
                    width: 18,
                    height: 18,
                    child: pw.Image(pw.MemoryImage(logoBytes)),
                  ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(
                    cooperadoraNombre,
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9),
                  ),
                ),
                pw.Text(
                  'CREDENCIAL DE SOCIO',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 7),
                ),
              ],
            ),
          ),
          // Body
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          persona.nombreCompleto,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                        pw.SizedBox(height: 2),
                        if (persona.dni != null)
                          _pwDato('DNI', persona.dni!),
                        _pwDato('N° Socio',
                            socio.numeroSocio.toString().padLeft(3, '0')),
                        _pwDato('Tipo', _tipoSocioLabel(socio.tipoSocio)),
                        _pwDato('Ingreso',
                            DateFormat('dd/MM/yyyy').format(socio.fechaIngreso)),
                      ],
                    ),
                  ),
                  if (qrBytes != null)
                    pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Container(
                          decoration: pw.BoxDecoration(
                            border:
                                pw.Border.all(color: azulOscuro, width: 1.5),
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(4)),
                          ),
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Image(pw.MemoryImage(qrBytes),
                              width: 58, height: 58),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Escanear para validar',
                          style: const pw.TextStyle(
                              fontSize: 5, color: PdfColors.grey),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          // Footer
          pw.Container(
            height: 16,
            decoration: const pw.BoxDecoration(
              color: celesteFondo,
              borderRadius: pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(5),
                bottomRight: pw.Radius.circular(5),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Válido: ${DateTime.now().year}',
                  style: const pw.TextStyle(
                      fontSize: 5, color: PdfColors.blueGrey),
                ),
                pw.Text(
                  socio.activo ? 'ACTIVO' : 'INACTIVO',
                  style: pw.TextStyle(
                    fontSize: 5,
                    color: socio.activo ? PdfColors.green800 : PdfColors.red,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pwDato(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: '$label: ',
                style: const pw.TextStyle(
                    fontSize: 5, color: PdfColors.blueGrey),
              ),
              pw.TextSpan(
                text: value,
                style: pw.TextStyle(
                    fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      );

  String _tipoSocioLabel(String tipo) => switch (tipo) {
        'activo' => 'Socio activo',
        'honorario' => 'Socio honorario',
        'adherente' => 'Socio adherente',
        _ => tipo,
      };

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfiguracionProvider>();
    final cooperadoraNombre = config.nombreCooperadora.isNotEmpty
        ? config.nombreCooperadora
        : 'Cooperadora Escolar';

    return Scaffold(
      backgroundColor: AppTheme.celesteFondo,
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
        title: const Text(
          'Mi credencial',
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppTheme.textoSecundario),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: AppTheme.textoSecundario),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Credencial responsiva (FittedBox escala si la pantalla es más angosta que 540px)
                      LayoutBuilder(
                        builder: (ctx, constraints) => FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                          child: _CredencialWidget(
                            socio: _socio!,
                            persona: _persona!,
                            nombreCooperadora: cooperadoraNombre,
                            logoUrl: _logoUrl,
                            fotoUrl: _persona!.fotoUrl,
                            paraImprimir: false,
                            onMostrarQR: _mostrarQRAmpliado,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('Imprimir'),
                            onPressed: _imprimir,
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Descargar PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.verdeTeal,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _descargarPDF,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ── Widgets de la credencial ──────────────────────────────────────────────────

class _CredencialWidget extends StatelessWidget {
  const _CredencialWidget({
    required this.socio,
    required this.persona,
    required this.nombreCooperadora,
    this.logoUrl,
    this.fotoUrl,
    this.paraImprimir = false,
    this.onMostrarQR,
  });

  final Socio socio;
  final Persona persona;
  final String nombreCooperadora;
  final String? logoUrl;
  final String? fotoUrl;
  final bool paraImprimir;
  final VoidCallback? onMostrarQR;

  @override
  Widget build(BuildContext context) {
    final qrData = jsonEncode({
      'socioId': socio.id,
      'numeroSocio': socio.numeroSocio,
      'nombre': persona.nombreCompleto,
      'dni': persona.dni ?? '',
    });

    return Container(
      width: 540,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.azulOscuro, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            _Header(logoUrl: logoUrl, nombre: nombreCooperadora),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _FotoSocio(fotoUrl: fotoUrl),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _DatosSocio(socio: socio, persona: persona)),
                    const SizedBox(width: 16),
                    _SeccionQR(
                      qrData: qrData,
                      paraImprimir: paraImprimir,
                      onTap: paraImprimir ? null : onMostrarQR,
                    ),
                  ],
                ),
              ),
            ),
            _Footer(socio: socio),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.logoUrl, required this.nombre});

  final String? logoUrl;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      color: AppTheme.azulOscuro,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: logoUrl != null
                ? Image.network(
                    logoUrl!,
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(Icons.school,
                        color: Colors.white, size: 28),
                  )
                : const Icon(Icons.school, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'CREDENCIAL',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _FotoSocio extends StatelessWidget {
  const _FotoSocio({this.fotoUrl});

  final String? fotoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.celesteBorde),
        color: AppTheme.celesteFondo,
      ),
      clipBehavior: Clip.antiAlias,
      child: fotoUrl != null
          ? Image.network(
              fotoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.person,
                  color: AppTheme.textoSecundario, size: 40),
            )
          : const Icon(Icons.person,
              color: AppTheme.textoSecundario, size: 40),
    );
  }
}

class _DatosSocio extends StatelessWidget {
  const _DatosSocio({required this.socio, required this.persona});

  final Socio socio;
  final Persona persona;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          persona.nombreCompleto,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textoPrincipal),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        _Dato(
            label: 'N° Socio',
            value: socio.numeroSocio.toString().padLeft(3, '0')),
        if (persona.dni != null) _Dato(label: 'DNI', value: persona.dni!),
        _Dato(label: 'Tipo', value: _tipoLabel(socio.tipoSocio)),
        _Dato(
          label: 'Ingreso',
          value: DateFormat('dd/MM/yyyy').format(socio.fechaIngreso),
        ),
      ],
    );
  }

  String _tipoLabel(String tipo) => switch (tipo) {
        'activo' => 'Socio activo',
        'honorario' => 'Socio honorario',
        'adherente' => 'Socio adherente',
        _ => tipo,
      };
}

class _Dato extends StatelessWidget {
  const _Dato({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
              fontSize: 12, color: AppTheme.textoPrincipal),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AppTheme.textoSecundario),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeccionQR extends StatelessWidget {
  const _SeccionQR({
    required this.qrData,
    required this.paraImprimir,
    this.onTap,
  });

  final String qrData;
  final bool paraImprimir;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.azulOscuro, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(6),
            child: Stack(
              children: [
                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 104,
                  backgroundColor: Colors.white,
                ),
                if (!paraImprimir)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.azulOscuro,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.zoom_in,
                          color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          paraImprimir ? 'Escanear para validar' : 'Presionar para ampliar',
          style: const TextStyle(
              fontSize: 10, color: AppTheme.textoSecundario),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.socio});

  final Socio socio;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: AppTheme.celesteFondo,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Válido: ${DateTime.now().year}',
            style: const TextStyle(
                fontSize: 10, color: AppTheme.textoSecundario),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: socio.activo
                  ? AppTheme.verdeIngreso.withValues(alpha: 0.15)
                  : AppTheme.rojoGasto.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              socio.activo ? 'ACTIVO' : 'INACTIVO',
              style: TextStyle(
                fontSize: 10,
                color:
                    socio.activo ? AppTheme.verdeIngreso : AppTheme.rojoGasto,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
