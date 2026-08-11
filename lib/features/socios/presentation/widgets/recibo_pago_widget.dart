import 'dart:convert';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/pago_cuota.dart';
import '../../domain/models/recibo.dart';
import '../../domain/models/socio.dart';
import '../../domain/services/recibo_service.dart';

class ReciboPagoWidget extends StatelessWidget {
  const ReciboPagoWidget({
    super.key,
    required this.pagoId,
    required this.socioId,
  });

  final String pagoId;
  final String socioId;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.receipt_long, size: 18, color: AppTheme.azulMedio),
      tooltip: 'Ver recibo',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ReciboSheet(pagoId: pagoId, socioId: socioId),
      ),
    );
  }
}

class _ReciboData {
  final PagoCuota pago;
  final Socio socio;
  final String nombreSocio;
  final String metodoPago;

  _ReciboData({
    required this.pago,
    required this.socio,
    required this.nombreSocio,
    required this.metodoPago,
  });
}

class _ReciboSheet extends StatefulWidget {
  const _ReciboSheet({required this.pagoId, required this.socioId});
  final String pagoId;
  final String socioId;

  @override
  State<_ReciboSheet> createState() => _ReciboSheetState();
}

class _ReciboSheetState extends State<_ReciboSheet> {
  Recibo? _recibo;
  _ReciboData? _data;
  String? _nombreRegistrador;
  String? _nombreTesorero;
  String? _error;
  bool _loading = true;
  bool _generandoPdf = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final db = FirebaseFirestore.instance;

      // Pago
      final pagoDoc =
          await db.collection('pagos_cuota').doc(widget.pagoId).get();
      if (!pagoDoc.exists) throw Exception('Pago no encontrado');
      final pago = PagoCuota.fromMap(pagoDoc.data()!, pagoDoc.id);

      // Socio
      final socioDoc =
          await db.collection('socios').doc(widget.socioId).get();
      if (!socioDoc.exists) throw Exception('Socio no encontrado');
      final socio = Socio.fromMap(socioDoc.data()!, socioDoc.id);

      // Nombre del socio (desde persona)
      final personaDoc =
          await db.collection('personas').doc(socio.personaId).get();
      final pd = personaDoc.data() ?? {};
      final String nombreSocio;
      if (pd['tipoPersona'] == 'fiscal') {
        nombreSocio = pd['razonSocial'] as String? ?? '—';
      } else {
        final n = pd['nombre'] as String? ?? '';
        final a = pd['apellido'] as String? ?? '';
        nombreSocio = [a, n].where((s) => s.isNotEmpty).join(', ');
      }

      // Método de pago
      final metodoDoc =
          await db.collection('metodos_pago').doc(pago.metodoPagoId).get();
      final metodoPago =
          metodoDoc.data()?['nombre'] as String? ?? pago.metodoPagoId;

      // Nombre del registrador (quien confirmó el pago)
      debugPrint('[Recibo] usuarioId del pago: ${pago.usuarioId}');
      String nombreRegistrador = '';
      try {
        final usuarioDoc =
            await db.collection('usuarios').doc(pago.usuarioId).get();
        final ud = usuarioDoc.data() ?? {};
        final regPersonaId = ud['personaId'] as String?;
        if (regPersonaId != null) {
          final regPersonaDoc =
              await db.collection('personas').doc(regPersonaId).get();
          final rpd = regPersonaDoc.data() ?? {};
          final rN = rpd['nombre'] as String? ?? '';
          final rA = rpd['apellido'] as String? ?? '';
          nombreRegistrador = [rA, rN].where((s) => s.isNotEmpty).join(', ');
        }
      } catch (_) {}
      debugPrint('[Recibo] nombreRegistrador: $nombreRegistrador');

      // Tesorera (desde cargos)
      String? nombreTesorero;
      try {
        final cargosSnap = await db
            .collection('cargos')
            .where('nombre', isEqualTo: 'Tesorera')
            .limit(1)
            .get();
        if (cargosSnap.docs.isNotEmpty) {
          final tesPId =
              cargosSnap.docs.first.data()['personaId'] as String?;
          if (tesPId != null) {
            final tesDoc =
                await db.collection('personas').doc(tesPId).get();
            final tpd = tesDoc.data() ?? {};
            final tN = tpd['nombre'] as String? ?? '';
            final tA = tpd['apellido'] as String? ?? '';
            nombreTesorero =
                [tA, tN].where((s) => s.isNotEmpty).join(', ');
          }
        }
      } catch (_) {}

      // Recibo (obtener o crear)
      final recibo = await ReciboService().obtenerOCrear(
        pago: pago,
        numeroSocio: socio.numeroSocio,
        nombreSocio: nombreSocio,
        metodoPago: metodoPago,
      );

      if (mounted) {
        setState(() {
          _recibo = recibo;
          _data = _ReciboData(
            pago: pago,
            socio: socio,
            nombreSocio: nombreSocio,
            metodoPago: metodoPago,
          );
          _nombreRegistrador =
              nombreRegistrador.isNotEmpty ? nombreRegistrador : null;
          _nombreTesorero = nombreTesorero;
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

  static String _fmt(double monto) {
    final formateado = NumberFormat('#,##0', 'es_AR').format(monto);
    return '\$$formateado';
  }

  static String _fmtFecha(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  String get _qrPayload => jsonEncode({
        'r': _recibo!.numeroFormateado,
        's': _recibo!.numeroSocio,
        'm': _recibo!.monto,
        'f': _fmtFecha(_recibo!.fechaPago),
      });

  // ── PDF ───────────────────────────────────────────────────────────────────

  Future<void> _descargarPDF() async {
    if (_recibo == null || _data == null) return;
    setState(() => _generandoPdf = true);
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final fontBoldData =
          await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      final ttf = pw.Font.ttf(fontData);
      final ttfBold = pw.Font.ttf(fontBoldData);

      final pdfBytes = await _buildPdf(_recibo!, _data!, font: ttf, fontBold: ttfBold);
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al generar PDF: $e'),
              backgroundColor: AppTheme.rojoGasto),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  Future<Uint8List> _buildPdf(
    Recibo recibo,
    _ReciboData data, {
    required pw.Font font,
    required pw.Font fontBold,
  }) async {
    final qrBytes = await _generarQrBytes(_qrPayload);
    final qrImage = pw.MemoryImage(qrBytes);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: font,
        bold: fontBold,
      ),
    );
    final pageFormat = PdfPageFormat(
      160 * PdfPageFormat.mm,
      110 * PdfPageFormat.mm,
      marginAll: 8 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header con borde inferior grueso
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('COOPERADORA EEST N°4',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('Burzaco, Buenos Aires',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('RECIBO DE PAGO',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('N° ${recibo.numeroFormateado}',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                              color: PdfColors.blue)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            // Banda CUOTA SOCIAL
            pw.Container(
              color: PdfColors.grey200,
              padding:
                  const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: pw.Center(
                child: pw.Text(
                  'CUOTA SOCIAL',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            // Cuerpo
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfFila('Recibí de', data.nombreSocio),
                      _pdfFila('N° socio',
                          recibo.numeroSocio.toString().padLeft(3, '0')),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        _fmt(recibo.monto),
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 18),
                      ),
                      pw.SizedBox(height: 4),
                      _pdfFila('Fecha', _fmtFecha(recibo.fechaPago)),
                      _pdfFila('Método', data.metodoPago),
                      _pdfFila('Registrado por',
                          _nombreRegistrador ?? '- Sin datos -'),
                      _pdfFila(
                          'Tesorera', _nombreTesorero ?? '- Sin asignar -'),
                    ],
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.SizedBox(
                  width: 55,
                  height: 55,
                  child: pw.Image(qrImage),
                ),
              ],
            ),
            pw.Expanded(child: pw.Container()),
            // Footer con separador
            pw.Divider(
                color: PdfColors.grey400, thickness: 0.5, height: 6),
            pw.Text(
              'Ejercicio ${recibo.ejercicio}/${recibo.ejercicio + 1}'
              ' · Este recibo acredita el pago de cuota social.',
              style: const pw.TextStyle(
                  fontSize: 7, color: PdfColors.grey),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfFila(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.TextSpan(
              text: valor,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _generarQrBytes(String data) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    final image = await painter.toImage(200);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  // ── Flutter UI (bottom sheet) ─────────────────────────────────────────────

  Widget _filaRecibo(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
              fontSize: 13, color: AppTheme.textoPrincipal),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AppTheme.textoSecundario),
            ),
            TextSpan(
              text: valor,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.receipt_long,
                    color: AppTheme.azulMedio, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Recibo de pago',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          if (_loading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!,
                      style:
                          const TextStyle(color: AppTheme.rojoGasto)),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  // Vista previa del recibo
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.celesteBorde),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: AppTheme.azulOscuro, width: 2),
                            ),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'COOPERADORA EEST N°4',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: AppTheme.azulOscuro),
                                  ),
                                  Text(
                                    'Burzaco, Buenos Aires',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textoSecundario),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'RECIBO DE PAGO',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textoPrincipal),
                                  ),
                                  Text(
                                    'N° ${_recibo!.numeroFormateado}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.azulMedio,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Banda CUOTA SOCIAL
                        Container(
                          color: AppTheme.celesteAccento
                              .withValues(alpha: 0.15),
                          padding:
                              const EdgeInsets.symmetric(vertical: 7),
                          child: const Center(
                            child: Text(
                              'C U O T A   S O C I A L',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: AppTheme.azulOscuro,
                                  letterSpacing: 1),
                            ),
                          ),
                        ),
                        // Cuerpo
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _filaRecibo(
                                        'Recibí de',
                                        _data!.nombreSocio),
                                    _filaRecibo(
                                        'N° socio',
                                        _recibo!.numeroSocio
                                            .toString()
                                            .padLeft(3, '0')),
                                    const SizedBox(height: 8),
                                    Text(
                                      _fmt(_recibo!.monto),
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: AppTheme.azulOscuro),
                                    ),
                                    const SizedBox(height: 8),
                                    _filaRecibo('Fecha',
                                        _fmtFecha(_recibo!.fechaPago)),
                                    _filaRecibo(
                                        'Método', _data!.metodoPago),
                                    _filaRecibo('Registrado por',
                                        _nombreRegistrador ??
                                            '- Sin datos -'),
                                    _filaRecibo('Tesorera',
                                        _nombreTesorero ??
                                            '- Sin asignar -'),
                                  ],
                                ),
                              ),
                              QrImageView(
                                data: _qrPayload,
                                version: QrVersions.auto,
                                size: 80,
                                backgroundColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        // Footer
                        const Divider(
                            height: 1, color: AppTheme.celesteBorde),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Text(
                            'Ejercicio ${_recibo!.ejercicio}/${_recibo!.ejercicio + 1}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textoSecundario),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.azulOscuro,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _generandoPdf
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Imprimir / Compartir PDF'),
                      onPressed: _generandoPdf ? null : _descargarPDF,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
