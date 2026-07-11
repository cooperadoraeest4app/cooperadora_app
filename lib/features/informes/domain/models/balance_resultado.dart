class MovimientoBalance {
  final DateTime fecha;
  final String? nroComprobante;
  final String descripcion;
  final double monto;
  final String rubroId;

  const MovimientoBalance({
    required this.fecha,
    this.nroComprobante,
    required this.descripcion,
    required this.monto,
    required this.rubroId,
  });
}

class CategoriaBalance {
  final String categoriaId;
  final String nombre;
  final double total;
  final int cantidad;

  const CategoriaBalance({
    required this.categoriaId,
    required this.nombre,
    required this.total,
    required this.cantidad,
  });
}

class RubroBalance {
  final String rubroId;
  final String nombre;
  final double total;
  final List<CategoriaBalance> categorias;

  const RubroBalance({
    required this.rubroId,
    required this.nombre,
    required this.total,
    required this.categorias,
  });
}

class MesBalance {
  final int anio;
  final int mes;
  final double entradas;
  final double salidas;

  const MesBalance({
    required this.anio,
    required this.mes,
    required this.entradas,
    required this.salidas,
  });
}

class BalanceResultado {
  final DateTime fechaDesde;
  final DateTime fechaHasta;
  final List<RubroBalance> entradas;
  final List<RubroBalance> salidas;
  final double totalEntradas;
  final double totalSalidas;
  final double saldoEjercicioAnterior;
  final double totalGeneral; // totalEntradas + saldoEjercicioAnterior
  final double saldoProximoEjercicio; // totalGeneral - totalSalidas
  final double? saldoCajaChica;
  final DateTime? fechaSaldoCajaChica;
  final double? saldoBanco;
  final DateTime? fechaSaldoBanco;
  final bool saldoBancoExacto;
  final List<MovimientoBalance> salidasDetalle;

  const BalanceResultado({
    required this.fechaDesde,
    required this.fechaHasta,
    required this.entradas,
    required this.salidas,
    required this.totalEntradas,
    required this.totalSalidas,
    required this.saldoEjercicioAnterior,
    required this.totalGeneral,
    required this.saldoProximoEjercicio,
    this.saldoCajaChica,
    this.fechaSaldoCajaChica,
    this.saldoBanco,
    this.fechaSaldoBanco,
    this.saldoBancoExacto = true,
    this.salidasDetalle = const [],
  });
}
