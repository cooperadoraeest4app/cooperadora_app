import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/models/balance_resultado.dart';
import '../domain/models/balance_snapshot.dart';

final _fmtNum = NumberFormat('#,##0.00', 'es_AR');
final _fmtFecha = DateFormat('dd/MM/yyyy');
final _fmtFechaHora = DateFormat('dd/MM/yyyy HH:mm');

// Paleta monocromática — imprimible en B&N
const _pdfGrisOscuro = PdfColor.fromInt(0xFF333333);
const _pdfGrisMedio = PdfColor.fromInt(0xFF666666);
const _pdfGrisClaro = PdfColor.fromInt(0xFFCCCCCC);
const _pdfFondoSeccion = PdfColor.fromInt(0xFFF5F5F5);

String _ars(double v) => '\$${_fmtNum.format(v)}';
// Números negativos con paréntesis en lugar de color rojo
String _arsValor(double v) =>
    v < 0 ? '(\$${_fmtNum.format(v.abs())})' : '\$${_fmtNum.format(v)}';

class PdfService {
  static Future<void> generarYMostrar({
    required BalanceResultado resultado,
    required String nombreCooperadora,
    BalanceSnapshot? snapshot,
    bool vistaDetallada = false,
  }) async {
    final bytes = await _generar(
      resultado: resultado,
      nombreCooperadora: nombreCooperadora,
      snapshot: snapshot,
      vistaDetallada: vistaDetallada,
    );
    await Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(bytes));
  }

  static Future<List<int>> _generar({
    required BalanceResultado resultado,
    required String nombreCooperadora,
    BalanceSnapshot? snapshot,
    bool vistaDetallada = false,
  }) async {
    final regular = await PdfGoogleFonts.nunitoSansRegular();
    final bold = await PdfGoogleFonts.nunitoSansBold();
    final italic = await PdfGoogleFonts.nunitoSansItalic();

    final periodo =
        '${_fmtFecha.format(resultado.fechaDesde)} — ${_fmtFecha.format(resultado.fechaHasta)}';

    final esPreview = snapshot == null;
    final encabezadoEstado = esPreview
        ? null
        : 'v${snapshot.version} — ${_fmtFecha.format(snapshot.fechaCierre)}';

    final generadoEl = _fmtFechaHora.format(DateTime.now());
    final r = resultado;

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 40),
        header: (ctx) => _buildHeader(
          nombreCooperadora: nombreCooperadora,
          periodo: periodo,
          estado: encabezadoEstado,
          esPreview: esPreview,
          bold: bold,
          regular: regular,
        ),
        footer: (ctx) => _buildFooter(
          pagina: ctx.pageNumber,
          total: ctx.pagesCount,
          generadoEl: generadoEl,
          regular: regular,
        ),
        build: (ctx) => [
          pw.SizedBox(height: 12),

          // Dos columnas ENTRADAS | SALIDAS
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildColumna(
                  titulo: 'ENTRADAS',
                  rubros: r.entradas,
                  total: r.totalEntradas,
                  bold: bold,
                  regular: regular,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: vistaDetallada && r.salidasDetalle.isNotEmpty
                    ? _buildColumnaSalidasDetallada(
                        rubros: r.salidas,
                        movimientos: r.salidasDetalle,
                        total: r.totalSalidas,
                        bold: bold,
                        regular: regular,
                      )
                    : _buildColumna(
                        titulo: 'SALIDAS',
                        rubros: r.salidas,
                        total: r.totalSalidas,
                        bold: bold,
                        regular: regular,
                      ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          _buildResumen(r: r, bold: bold, regular: regular),

          if (!r.saldoBancoExacto && r.saldoBanco != null) ...[
            pw.SizedBox(height: 12),
            _buildAdvertenciaBanco(
              fechaUsada: r.fechaSaldoBanco!,
              fechaCierre: r.fechaHasta,
              regular: regular,
              italic: italic,
            ),
          ],

          pw.SizedBox(height: 8),
          pw.Text(
            '(*) Debe coincidir con Libro de Socios/as',
            style: pw.TextStyle(font: italic, fontSize: 7, color: _pdfGrisMedio),
          ),

          pw.SizedBox(height: 40),
          _buildFirma(regular: regular),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header ────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader({
    required String nombreCooperadora,
    required String periodo,
    required String? estado,
    required bool esPreview,
    required pw.Font bold,
    required pw.Font regular,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  nombreCooperadora,
                  style: pw.TextStyle(font: bold, fontSize: 14, color: _pdfGrisOscuro),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Informe de Balance — $periodo',
                  style: pw.TextStyle(font: regular, fontSize: 10, color: _pdfGrisMedio),
                ),
              ],
            ),
            if (estado != null)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _pdfGrisClaro),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  estado,
                  style: pw.TextStyle(font: regular, fontSize: 8, color: _pdfGrisMedio),
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _pdfGrisClaro, thickness: 1),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter({
    required int pagina,
    required int total,
    required String generadoEl,
    required pw.Font regular,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _pdfGrisClaro, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generado el $generadoEl',
            style: pw.TextStyle(font: regular, fontSize: 8, color: _pdfGrisMedio),
          ),
          pw.Text(
            'Página $pagina de $total',
            style: pw.TextStyle(font: regular, fontSize: 8, color: _pdfGrisMedio),
          ),
        ],
      ),
    );
  }

  // ── Columna ENTRADAS / SALIDAS ────────────────────────────────────────────

  static pw.Widget _buildColumna({
    required String titulo,
    required List<RubroBalance> rubros,
    required double total,
    required pw.Font bold,
    required pw.Font regular,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _pdfGrisClaro),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Cabecera: borde izquierdo grueso en gris oscuro en lugar de fondo de color
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: _pdfFondoSeccion,
              border: pw.Border(
                left: pw.BorderSide(color: _pdfGrisOscuro, width: 3),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text(
              titulo,
              style: pw.TextStyle(font: bold, fontSize: 11, color: _pdfGrisOscuro),
            ),
          ),

          // Filas de rubros y categorías — alternando fondo blanco / gris muy claro
          ...rubros.asMap().entries.expand((entry) {
            final fondoRubro = entry.key % 2 == 0 ? _pdfFondoSeccion : PdfColors.white;
            final rubro = entry.value;
            return [
              pw.Container(
                color: fondoRubro,
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        rubro.nombre.toUpperCase(),
                        style: pw.TextStyle(font: bold, fontSize: 8, color: _pdfGrisOscuro),
                      ),
                    ),
                    pw.Text(
                      _ars(rubro.total),
                      style: pw.TextStyle(font: bold, fontSize: 8, color: _pdfGrisOscuro),
                    ),
                  ],
                ),
              ),
              ...rubro.categorias.map(
                (cat) => pw.Container(
                  color: PdfColors.white,
                  padding: const pw.EdgeInsets.fromLTRB(16, 3, 8, 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          cat.nombre,
                          style: pw.TextStyle(font: regular, fontSize: 8, color: _pdfGrisMedio),
                        ),
                      ),
                      pw.Text(
                        _ars(cat.total),
                        style: pw.TextStyle(font: regular, fontSize: 8, color: _pdfGrisMedio),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          }),

          // Total columna — negrita, línea superior separadora
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: _pdfFondoSeccion,
              border: pw.Border(top: pw.BorderSide(color: _pdfGrisClaro, width: 0.5)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL',
                    style: pw.TextStyle(font: bold, fontSize: 9, color: _pdfGrisOscuro)),
                pw.Text(_ars(total),
                    style: pw.TextStyle(font: bold, fontSize: 9, color: _pdfGrisOscuro)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Resumen de totales ────────────────────────────────────────────────────

  static pw.Widget _buildResumen({
    required BalanceResultado r,
    required pw.Font bold,
    required pw.Font regular,
  }) {
    pw.Widget fila(
      String label,
      double valor, {
      bool destacado = false,
      bool conSigno = false,
    }) {
      final texto = conSigno ? _arsValor(valor) : _ars(valor);
      final style = pw.TextStyle(
        font: destacado ? bold : regular,
        fontSize: destacado ? 10 : 9,
        color: destacado ? _pdfGrisOscuro : _pdfGrisMedio,
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: style),
            pw.Text(texto, style: style),
          ],
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _pdfFondoSeccion,
        border: pw.Border.all(color: _pdfGrisClaro),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        children: [
          fila('Total Entradas', r.totalEntradas),
          fila('+ Saldo ejercicio anterior', r.saldoEjercicioAnterior, conSigno: true),
          pw.Divider(color: _pdfGrisClaro, thickness: 0.5),
          fila('= Total General', r.totalGeneral, destacado: true),
          fila('- Total Salidas', r.totalSalidas),
          pw.Divider(color: _pdfGrisClaro, thickness: 0.5),
          fila('= Saldo próximo ejercicio', r.saldoProximoEjercicio,
              destacado: true, conSigno: true),
          if (r.saldoCajaChica != null || r.saldoBanco != null) ...[
            pw.Divider(color: _pdfGrisClaro, thickness: 0.5),
            if (r.saldoCajaChica != null) fila('En Caja Chica', r.saldoCajaChica!),
            if (r.saldoBanco != null)
              fila(
                'En Banco${r.saldoBancoExacto ? '' : ' (estimado)'}',
                r.saldoBanco!,
              ),
          ],
        ],
      ),
    );
  }

  // ── Advertencia saldo bancario ────────────────────────────────────────────

  static pw.Widget _buildAdvertenciaBanco({
    required DateTime fechaUsada,
    required DateTime fechaCierre,
    required pw.Font regular,
    required pw.Font italic,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _pdfGrisClaro),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        'Advertencia: No se encontró saldo bancario al ${_fmtFecha.format(fechaCierre)}. '
        'Se usó el último disponible del ${_fmtFecha.format(fechaUsada)}. '
        'El saldo bancario es ESTIMADO y puede no coincidir con el saldo real.',
        style: pw.TextStyle(font: italic, fontSize: 8, color: _pdfGrisMedio),
      ),
    );
  }

  // ── Columna SALIDAS detallada (transacciones individuales) ───────────────────

  static pw.Widget _buildColumnaSalidasDetallada({
    required List<RubroBalance> rubros,
    required List<MovimientoBalance> movimientos,
    required double total,
    required pw.Font bold,
    required pw.Font regular,
  }) {
    final fmt = DateFormat('dd/MM');
    final Map<String, List<MovimientoBalance>> porRubro = {};
    for (final m in movimientos) {
      porRubro.putIfAbsent(m.rubroId, () => []).add(m);
    }

    pw.Widget filaMovimiento(MovimientoBalance m) => pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(8, 2, 8, 2),
          child: pw.Row(children: [
            pw.SizedBox(
              width: 26,
              child: pw.Text(fmt.format(m.fecha),
                  style: pw.TextStyle(
                      font: regular, fontSize: 7, color: _pdfGrisMedio)),
            ),
            pw.SizedBox(
              width: 32,
              child: pw.Text(m.nroComprobante ?? '—',
                  style: pw.TextStyle(
                      font: regular, fontSize: 7, color: _pdfGrisMedio),
                  maxLines: 1),
            ),
            pw.Expanded(
              child: pw.Text(
                  m.descripcion.isEmpty ? '(sin descripción)' : m.descripcion,
                  style: pw.TextStyle(font: regular, fontSize: 7),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip),
            ),
            pw.SizedBox(
              width: 44,
              child: pw.Text(_ars(m.monto),
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      font: regular, fontSize: 7, color: _pdfGrisMedio)),
            ),
          ]),
        );

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _pdfGrisClaro),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Cabecera
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: _pdfFondoSeccion,
              border: pw.Border(
                  left: pw.BorderSide(color: _pdfGrisOscuro, width: 3)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Text('SALIDAS',
                style: pw.TextStyle(
                    font: bold, fontSize: 11, color: _pdfGrisOscuro)),
          ),
          // Encabezados columna
          pw.Container(
            color: _pdfFondoSeccion,
            padding: const pw.EdgeInsets.fromLTRB(8, 3, 8, 3),
            child: pw.Row(children: [
              pw.SizedBox(
                  width: 26,
                  child: pw.Text('Fecha',
                      style: pw.TextStyle(
                          font: bold, fontSize: 7, color: _pdfGrisMedio))),
              pw.SizedBox(
                  width: 32,
                  child: pw.Text('N°Comp.',
                      style: pw.TextStyle(
                          font: bold, fontSize: 7, color: _pdfGrisMedio))),
              pw.Expanded(
                  child: pw.Text('Descripción',
                      style: pw.TextStyle(
                          font: bold, fontSize: 7, color: _pdfGrisMedio))),
              pw.SizedBox(
                  width: 44,
                  child: pw.Text('Monto',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          font: bold, fontSize: 7, color: _pdfGrisMedio))),
            ]),
          ),
          // Rubros con transacciones
          ...rubros.expand((r) {
            final movs = porRubro[r.rubroId] ?? [];
            if (movs.isEmpty) return <pw.Widget>[];
            return [
              pw.Container(
                color: _pdfFondoSeccion,
                padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: pw.Row(children: [
                  pw.Expanded(
                    child: pw.Text(r.nombre.toUpperCase(),
                        style: pw.TextStyle(
                            font: bold, fontSize: 8, color: _pdfGrisOscuro)),
                  ),
                  pw.Text(_ars(r.total),
                      style: pw.TextStyle(
                          font: bold, fontSize: 8, color: _pdfGrisOscuro)),
                ]),
              ),
              ...movs.map(filaMovimiento),
            ];
          }),
          // Total
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: _pdfFondoSeccion,
              border: pw.Border(
                  top: pw.BorderSide(color: _pdfGrisClaro, width: 0.5)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL',
                    style: pw.TextStyle(
                        font: bold, fontSize: 9, color: _pdfGrisOscuro)),
                pw.Text(_ars(total),
                    style: pw.TextStyle(
                        font: bold, fontSize: 9, color: _pdfGrisOscuro)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Firma ─────────────────────────────────────────────────────────────────────

  static pw.Widget _buildFirma({required pw.Font regular}) {
    pw.Widget linea(String cargo) => pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Divider(color: _pdfGrisClaro, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Text(cargo,
                  style: pw.TextStyle(
                      font: regular, fontSize: 8, color: _pdfGrisMedio)),
            ],
          ),
        );

    return pw.Row(
      children: [
        linea('Firma Tesorero/a'),
        pw.SizedBox(width: 40),
        linea('Firma Presidente/a'),
      ],
    );
  }
}
