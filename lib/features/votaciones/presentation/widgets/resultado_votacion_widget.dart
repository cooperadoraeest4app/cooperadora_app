import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';

class ResultadoVotacionWidget extends StatefulWidget {
  const ResultadoVotacionWidget({
    super.key,
    required this.votacionId,
    required this.titulo,
    required this.tipo,
    this.scrollController,
  });

  final String votacionId;
  final String titulo;
  final String tipo; // 'proyecto' / 'presupuesto'
  final ScrollController? scrollController;

  @override
  State<ResultadoVotacionWidget> createState() =>
      _ResultadoVotacionWidgetState();
}

class _ResultadoVotacionWidgetState extends State<ResultadoVotacionWidget> {
  bool _cargando = true;

  int _totalAFavor = 0;
  int _totalEnContra = 0;
  int _totalAbstenciones = 0;

  int _activosAFavor = 0;
  int _activosEnContra = 0;
  int _activosAbstenciones = 0;

  int _consultantesAFavor = 0;
  int _consultantesEnContra = 0;
  int _consultantesAbstenciones = 0;

  int _quorumRequerido = 0;
  DateTime? _fechaCierre;
  String _estado = '';

  @override
  void initState() {
    super.initState();
    _cargarResultados();
  }

  Future<void> _cargarResultados() async {
    final votacionSnap = await FirebaseFirestore.instance
        .collection('votaciones')
        .doc(widget.votacionId)
        .get();

    if (!votacionSnap.exists) {
      if (mounted) setState(() => _cargando = false);
      return;
    }

    final votacion = votacionSnap.data()!;
    _quorumRequerido = (votacion['quorumRequerido'] as num?)?.toInt() ?? 0;
    _estado = votacion['estado'] as String? ?? '';
    _fechaCierre = votacion['fechaCierre'] is Timestamp
        ? (votacion['fechaCierre'] as Timestamp).toDate()
        : null;

    final votosSnap = await FirebaseFirestore.instance
        .collection('votos')
        .where('votacionId', isEqualTo: widget.votacionId)
        .get();

    for (final doc in votosSnap.docs) {
      final data = doc.data();
      final valor = data['valor'] as String? ?? '';
      final esActivo = (data['tipoSocio'] as String?) == 'activo';

      if (valor == 'a_favor') {
        _totalAFavor++;
        if (esActivo) { _activosAFavor++; } else { _consultantesAFavor++; }
      } else if (valor == 'en_contra') {
        _totalEnContra++;
        if (esActivo) { _activosEnContra++; } else { _consultantesEnContra++; }
      } else {
        _totalAbstenciones++;
        if (esActivo) { _activosAbstenciones++; } else { _consultantesAbstenciones++; }
      }
    }

    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalVotos = _totalAFavor + _totalEnContra + _totalAbstenciones;
    final totalActivos =
        _activosAFavor + _activosEnContra + _activosAbstenciones;
    final totalConsultantes =
        _consultantesAFavor + _consultantesEnContra + _consultantesAbstenciones;
    final porcentaje =
        totalVotos > 0 ? _totalAFavor / totalVotos * 100 : 0.0;

    return Column(
      children: [
        // Handle
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.celesteBorde,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.azulOscuro,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resultado de la votación',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${widget.titulo} · '
                '${widget.tipo == 'proyecto' ? 'Proyecto' : 'Presupuesto'}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        // Contenido scrolleable
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estado + fecha
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ChipEstadoVotacion(estado: _estado),
                    if (_fechaCierre != null)
                      Text(
                        'Cerrada el ${DateFormat('dd/MM/yyyy').format(_fechaCierre!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textoSecundario,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Totales generales
                Row(
                  children: [
                    _RecuadroTotal(
                      valor: _totalAFavor,
                      label: 'A favor',
                      color: AppTheme.verdeIngreso,
                    ),
                    const SizedBox(width: 10),
                    _RecuadroTotal(
                      valor: _totalEnContra,
                      label: 'En contra',
                      color: AppTheme.rojoGasto,
                    ),
                    const SizedBox(width: 10),
                    _RecuadroTotal(
                      valor: _totalAbstenciones,
                      label: 'Abstenciones',
                      color: AppTheme.amarilloAlerta,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Barra de progreso
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: porcentaje / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(
                        AppTheme.verdeIngreso),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${porcentaje.toStringAsFixed(1)}% a favor',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textoSecundario,
                      ),
                    ),
                    Text(
                      '$totalVotos votos emitidos',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textoSecundario,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Divisor desglose
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Desglose',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textoSecundario,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 14),

                // Vinculantes
                _SeccionDesglose(
                  icono: Icons.gavel,
                  titulo: 'Socios Activos — vinculante',
                  colorTitulo: AppTheme.azulOscuro,
                  aFavor: _activosAFavor,
                  enContra: _activosEnContra,
                  abstenciones: _activosAbstenciones,
                  subtitulo:
                      '$totalActivos votos · Quórum requerido: $_quorumRequerido',
                  vinculante: true,
                ),

                // No vinculantes
                if (totalConsultantes > 0) ...[
                  const SizedBox(height: 12),
                  _SeccionDesglose(
                    icono: Icons.people,
                    titulo: 'Consultantes — no vinculante',
                    colorTitulo: AppTheme.textoSecundario,
                    aFavor: _consultantesAFavor,
                    enContra: _consultantesEnContra,
                    abstenciones: _consultantesAbstenciones,
                    subtitulo:
                        'Solo orientativo · $totalConsultantes votos',
                    vinculante: false,
                  ),
                ],

                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.azulOscuro,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── _ChipEstadoVotacion ────────────────────────────────────────────────────────

class _ChipEstadoVotacion extends StatelessWidget {
  const _ChipEstadoVotacion({required this.estado});
  final String estado;

  @override
  Widget build(BuildContext context) {
    final ({Color color, String label}) config = switch (estado) {
      'aprobada' => (color: AppTheme.verdeIngreso, label: '✅ Aprobado'),
      'rechazada' => (color: AppTheme.rojoGasto, label: '❌ Rechazado'),
      'comprado' => (color: AppTheme.verdeTeal, label: '✅ Comprado'),
      _ => (color: AppTheme.amarilloAlerta, label: '🗳️ En curso'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: config.color,
        ),
      ),
    );
  }
}

// ── _RecuadroTotal ─────────────────────────────────────────────────────────────

class _RecuadroTotal extends StatelessWidget {
  const _RecuadroTotal({
    required this.valor,
    required this.label,
    required this.color,
  });

  final int valor;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$valor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SeccionDesglose ───────────────────────────────────────────────────────────

class _SeccionDesglose extends StatelessWidget {
  const _SeccionDesglose({
    required this.icono,
    required this.titulo,
    required this.colorTitulo,
    required this.aFavor,
    required this.enContra,
    required this.abstenciones,
    required this.subtitulo,
    required this.vinculante,
  });

  final IconData icono;
  final String titulo;
  final Color colorTitulo;
  final int aFavor;
  final int enContra;
  final int abstenciones;
  final String subtitulo;
  final bool vinculante;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 13, color: colorTitulo),
            const SizedBox(width: 5),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorTitulo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _CeldaDesglose(
              valor: aFavor,
              color: AppTheme.verdeIngreso,
              vinculante: vinculante,
            ),
            const SizedBox(width: 6),
            _CeldaDesglose(
              valor: enContra,
              color: AppTheme.rojoGasto,
              vinculante: vinculante,
            ),
            const SizedBox(width: 6),
            _CeldaDesglose(
              valor: abstenciones,
              color: AppTheme.amarilloAlerta,
              vinculante: vinculante,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitulo,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textoSecundario,
            fontStyle:
                vinculante ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ── _CeldaDesglose ─────────────────────────────────────────────────────────────

class _CeldaDesglose extends StatelessWidget {
  const _CeldaDesglose({
    required this.valor,
    required this.color,
    required this.vinculante,
  });

  final int valor;
  final Color color;
  final bool vinculante;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: vinculante
              ? color.withValues(alpha: 0.06)
              : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: vinculante
                ? color.withValues(alpha: 0.2)
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Center(
          child: Text(
            '$valor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: vinculante ? 1.0 : 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
