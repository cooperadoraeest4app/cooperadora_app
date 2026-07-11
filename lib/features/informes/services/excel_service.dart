import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../domain/models/balance_resultado.dart';

class ExcelService {
  final _fmtFecha = DateFormat('dd/MM/yyyy');

  Future<List<int>> generarBalance({
    required BalanceResultado resultado,
    required bool vistaDetallada,
    required String titulo,
  }) async {
    final excel = Excel.createExcel();
    final sheetName = vistaDetallada ? 'Balance Mensual' : 'Balance Anual';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    int row = 0;

    _escribirCelda(sheet, row, 0,
        'BALANCE ${vistaDetallada ? "MENSUAL" : "ANUAL"} — $titulo',
        bold: true, fontSize: 14);
    row++;
    _escribirCelda(sheet, row, 0,
        'Cooperadora EEST4 Burzaco — EEST N°4 Alte. Brown');
    row++;
    _escribirCelda(sheet, row, 0,
        '${_fmtFecha.format(resultado.fechaDesde)} — ${_fmtFecha.format(resultado.fechaHasta)}');
    row += 2;

    if (vistaDetallada) {
      _generarMensualDinamico(sheet, resultado, row);
    } else {
      _generarAnualDinamico(sheet, resultado, row);
    }

    return excel.encode()!;
  }

  // ── Vista Anual (salidas agrupadas por categoría) ──────────────────────────

  void _generarAnualDinamico(Sheet sheet, BalanceResultado r, int startRow) {
    int row = startRow;

    _escribirCelda(sheet, row, 0, 'ENTRADAS', bold: true);
    _escribirCelda(sheet, row, 1, 'PESOS', bold: true);
    _escribirCelda(sheet, row, 3, 'SALIDAS', bold: true);
    _escribirCelda(sheet, row, 4, 'PESOS', bold: true);
    row++;

    int entRow = row;
    for (final rubro in r.entradas) {
      _escribirCelda(sheet, entRow, 0, rubro.nombre, bold: true);
      entRow++;
      for (final cat in rubro.categorias) {
        _escribirCelda(sheet, entRow, 0, '  ${cat.nombre}');
        _escribirCeldaNumero(sheet, entRow, 1, cat.total);
        entRow++;
      }
    }
    _escribirCelda(sheet, entRow, 0, 'Total Entradas (a)', bold: true);
    _escribirCeldaNumero(sheet, entRow, 1, r.totalEntradas, bold: true);

    int salRow = row;
    for (final rubro in r.salidas) {
      _escribirCelda(sheet, salRow, 3, rubro.nombre, bold: true);
      salRow++;
      for (final cat in rubro.categorias) {
        _escribirCelda(sheet, salRow, 3, '  ${cat.nombre}');
        _escribirCeldaNumero(sheet, salRow, 4, cat.total);
        salRow++;
      }
    }
    _escribirCelda(sheet, salRow, 3, 'Total Salidas (b)', bold: true);
    _escribirCeldaNumero(sheet, salRow, 4, r.totalSalidas, bold: true);

    final resRow = (entRow > salRow ? entRow : salRow) + 2;
    _escribirResumen(sheet, resRow, r);
  }

  // ── Vista Mensual (salidas con movimientos individuales) ───────────────────

  void _generarMensualDinamico(Sheet sheet, BalanceResultado r, int startRow) {
    int row = startRow;

    _escribirCelda(sheet, row, 0, 'ENTRADAS', bold: true);
    _escribirCelda(sheet, row, 1, 'PESOS', bold: true);
    _escribirCelda(sheet, row, 3, 'FECHA', bold: true);
    _escribirCelda(sheet, row, 4, 'N° Comp.(*)', bold: true);
    _escribirCelda(sheet, row, 5, 'ARTÍCULOS / PROVEEDOR', bold: true);
    _escribirCelda(sheet, row, 6, 'PESOS', bold: true);
    row++;

    // ENTRADAS
    int entRow = row;
    for (final rubro in r.entradas) {
      _escribirCelda(sheet, entRow, 0, rubro.nombre, bold: true);
      entRow++;
      for (final cat in rubro.categorias) {
        _escribirCelda(sheet, entRow, 0, '  ${cat.nombre}');
        _escribirCeldaNumero(sheet, entRow, 1, cat.total);
        entRow++;
      }
    }
    _escribirCelda(sheet, entRow, 0, 'Total Entradas (a)', bold: true);
    _escribirCeldaNumero(sheet, entRow, 1, r.totalEntradas, bold: true);

    // SALIDAS DETALLADAS
    int salRow = row;
    String? rubroActualId;
    final fmtMes = DateFormat('dd/MM');
    for (final mov in r.salidasDetalle) {
      if (mov.rubroId != rubroActualId) {
        rubroActualId = mov.rubroId;
        final rubro = r.salidas.firstWhere(
          (rb) => rb.rubroId == mov.rubroId,
          orElse: () => const RubroBalance(
              rubroId: '', nombre: 'Sin Rubro', total: 0, categorias: []),
        );
        _escribirCelda(sheet, salRow, 5, rubro.nombre, bold: true);
        salRow++;
      }
      _escribirCelda(sheet, salRow, 3, fmtMes.format(mov.fecha));
      _escribirCelda(sheet, salRow, 4, mov.nroComprobante ?? '');
      _escribirCelda(sheet, salRow, 5, mov.descripcion);
      _escribirCeldaNumero(sheet, salRow, 6, mov.monto);
      salRow++;
    }
    _escribirCelda(sheet, salRow, 5, 'Total Salidas (b)', bold: true);
    _escribirCeldaNumero(sheet, salRow, 6, r.totalSalidas, bold: true);

    final resRow = (entRow > salRow ? entRow : salRow) + 2;
    _escribirResumen(sheet, resRow, r);
  }

  // ── Resumen y notas al pie (compartido) ────────────────────────────────────

  void _escribirResumen(Sheet sheet, int startRow, BalanceResultado r) {
    int row = startRow;

    _escribirCelda(sheet, row, 0, 'RESUMEN', bold: true);
    row++;

    final items = [
      ('Total Entradas (a)', r.totalEntradas, false),
      ('Saldo ejercicio anterior (1)', r.saldoEjercicioAnterior, false),
      ('Total General', r.totalGeneral, false),
      ('Total Salidas (b)', r.totalSalidas, false),
      ('Saldo próximo ejercicio (2)', r.saldoProximoEjercicio, true),
      if (r.saldoBanco != null) ('En Banco (3)', r.saldoBanco!, false),
      if (r.saldoCajaChica != null) ('En Caja Chica (4)', r.saldoCajaChica!, false),
    ];

    for (final (label, valor, negrita) in items) {
      _escribirCelda(sheet, row, 0, label, bold: negrita);
      _escribirCeldaNumero(sheet, row, 1, valor, bold: negrita);
      row++;
    }

    row++;
    for (final nota in [
      '(1) Debe coincidir con "Saldo próximo ejercicio" del ejercicio anterior',
      '(2) Total General - Total Salidas',
      '(3) Debe coincidir con Extracto bancario',
      '(4) Debe coincidir con Dinero efectivo de Caja Chica',
      'NOTA: El Saldo del próximo ejercicio debe coincidir con la suma del Banco más Caja Chica.',
    ]) {
      _escribirCelda(sheet, row, 0, nota, fontSize: 8, italic: true);
      row++;
    }

    row++;
    _escribirCelda(sheet, row, 0,
        'Firma Tesorero/a: _______________________________');
    _escribirCelda(sheet, row, 3,
        'Firma Presidente/a: _______________________________');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _escribirCelda(
    Sheet sheet, int row, int col, String value, {
    bool bold = false,
    int fontSize = 10,
    bool italic = false,
  }) {
    final cell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);
    cell.cellStyle = CellStyle(
      bold: bold,
      fontSize: fontSize,
      italic: italic,
      fontFamily: getFontFamily(FontFamily.Arial),
    );
  }

  void _escribirCeldaNumero(
    Sheet sheet, int row, int col, double value, {
    bool bold = false,
  }) {
    final cell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = DoubleCellValue(value);
    cell.cellStyle = CellStyle(
      bold: bold,
      numberFormat: NumFormat.defaultNumeric,
      fontFamily: getFontFamily(FontFamily.Arial),
    );
  }
}
