import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/accion_auth_widget.dart';
import '../../../../../shared/widgets/app_drawer.dart';
import '../../../home/presentation/screens/home_screen.dart';

class VotacionConfigScreen extends StatefulWidget {
  const VotacionConfigScreen({super.key});

  @override
  State<VotacionConfigScreen> createState() => _VotacionConfigScreenState();
}

class _VotacionConfigScreenState extends State<VotacionConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = true;
  bool _guardando = false;
  bool _reseteando = false;
  bool _modoTesting = false;

  final _ctrls = <String, TextEditingController>{
    'quorumPorcentajeCD': TextEditingController(),
    'quorumMultiplicadorSocios': TextEditingController(),
    'quorumPisoSociosDirecta': TextEditingController(),
    'quorumPorcentajePadron': TextEditingController(),
    'mayoriaRequerida': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('config')
          .get();
      final data = snap.data() ?? {};
      if (!mounted) return;
      setState(() {
        _modoTesting = data['modoTesting'] as bool? ?? false;
        _ctrls['quorumPorcentajeCD']!.text =
            ((data['quorumPorcentajeCD'] as num?) ?? 30).toString();
        _ctrls['quorumMultiplicadorSocios']!.text =
            ((data['quorumMultiplicadorSocios'] as num?) ?? 3).toString();
        _ctrls['quorumPisoSociosDirecta']!.text =
            ((data['quorumPisoSociosDirecta'] as num?) ?? 15).toString();
        _ctrls['quorumPorcentajePadron']!.text =
            ((data['quorumPorcentajePadron'] as num?) ?? 30).toString();
        _ctrls['mayoriaRequerida']!.text =
            ((data['mayoriaRequerida'] as num?) ?? 66.67).toString();
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _confirmarReset() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resetear datos de prueba'),
        content: const Text(
          'Esto eliminará todas las votaciones y votos registrados, '
          'y revertirá los ítems de proyecto a su estado anterior.\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.rojoGasto),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );
    if (confirmar == true) await _ejecutarReset();
  }

  Future<void> _ejecutarReset() async {
    setState(() => _reseteando = true);
    try {
      final itemsSnap = await FirebaseFirestore.instance
          .collection('items_proyecto')
          .where('estado', isEqualTo: 'presupuestos_aprobados')
          .get();
      final batchItems = FirebaseFirestore.instance.batch();
      for (final doc in itemsSnap.docs) {
        final estadoAnterior =
            doc.data()['estadoAnterior'] as String? ?? 'pendiente';
        batchItems.update(doc.reference, {
          'estado': estadoAnterior,
          'estadoAnterior': FieldValue.delete(),
          'presupuestoAprobadoId': FieldValue.delete(),
        });
      }
      await batchItems.commit();

      final votosSnap =
          await FirebaseFirestore.instance.collection('votos').get();
      final batchVotos = FirebaseFirestore.instance.batch();
      for (final doc in votosSnap.docs) {
        batchVotos.delete(doc.reference);
      }
      await batchVotos.commit();

      final votacionesSnap =
          await FirebaseFirestore.instance.collection('votaciones').get();
      final batchVotaciones = FirebaseFirestore.instance.batch();
      for (final doc in votacionesSnap.docs) {
        batchVotaciones.delete(doc.reference);
      }
      await batchVotaciones.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Datos de prueba reseteados correctamente'),
          backgroundColor: AppTheme.verdeIngreso,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al resetear: $e'),
          backgroundColor: AppTheme.rojoGasto,
        ));
      }
    } finally {
      if (mounted) setState(() => _reseteando = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('config')
          .set({
        'quorumPorcentajeCD':
            double.parse(_ctrls['quorumPorcentajeCD']!.text),
        'quorumMultiplicadorSocios':
            int.parse(_ctrls['quorumMultiplicadorSocios']!.text),
        'quorumPisoSociosDirecta':
            int.parse(_ctrls['quorumPisoSociosDirecta']!.text),
        'quorumPorcentajePadron':
            double.parse(_ctrls['quorumPorcentajePadron']!.text),
        'mayoriaRequerida':
            double.parse(_ctrls['mayoriaRequerida']!.text),
        'modoTesting': _modoTesting,
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Configuración de votaciones guardada'),
          backgroundColor: AppTheme.verdeIngreso,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: AppTheme.rojoGasto,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          children: [
            Container(
                width: 1, height: 20, color: Colors.white.withValues(alpha: 0.3)),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: Icon(Icons.home,
                    color: Colors.white.withValues(alpha: 0.8), size: 20),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                ),
              ),
            ),
            Container(
                width: 1, height: 20, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Configuración de Votaciones',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [AccionAuthWidget()],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSeccion(
                      titulo: 'Quórum',
                      children: [
                        _CampoNumerico(
                          label: 'Porcentaje de CD requerido',
                          sufijo: '%',
                          controller: _ctrls['quorumPorcentajeCD']!,
                          ayuda:
                              'Porcentaje mínimo de miembros de la Comisión Directiva que deben estar presentes',
                        ),
                        const SizedBox(height: 16),
                        _CampoNumerico(
                          label: 'Multiplicador de socios',
                          controller: _ctrls['quorumMultiplicadorSocios']!,
                          ayuda:
                              'Por cada miembro de CD presente, se requieren N socios activos',
                          soloEntero: true,
                        ),
                        const SizedBox(height: 16),
                        _CampoNumerico(
                          label: 'Piso mínimo de socios activos',
                          controller: _ctrls['quorumPisoSociosDirecta']!,
                          ayuda:
                              'Cantidad mínima de socios activos para que haya quórum válido',
                          soloEntero: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSeccion(
                      titulo: 'Democracia directa',
                      children: [
                        _CampoNumerico(
                          label: 'Porcentaje del padrón',
                          sufijo: '%',
                          controller: _ctrls['quorumPorcentajePadron']!,
                          ayuda:
                              'Porcentaje ideal del padrón total de socios para quórum de democracia directa',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSeccion(
                      titulo: 'Mayoría',
                      children: [
                        _CampoNumerico(
                          label: 'Mayoría requerida',
                          sufijo: '%',
                          controller: _ctrls['mayoriaRequerida']!,
                          ayuda:
                              'Porcentaje mínimo de votos a favor para aprobar una moción',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSeccion(
                      titulo: 'Testing',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Modo testing'),
                          subtitle: const Text(
                            'Reduce todos los umbrales a 1 voto para facilitar las pruebas. DESACTIVAR antes de usar en producción.',
                          ),
                          value: _modoTesting,
                          activeThumbColor: AppTheme.amarilloAlerta,
                          onChanged: (v) => setState(() => _modoTesting = v),
                        ),
                        if (_modoTesting) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.amarilloAlerta.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.amarilloAlerta),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber,
                                    color: AppTheme.amarilloAlerta),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Modo testing activo. El quórum requerido es de 1 voto y la mayoría del 50%. Desactivar antes de usar en producción.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.amarilloAlerta),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.verdeTeal,
                        foregroundColor: AppTheme.blanco,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.blanco),
                            )
                          : const Text(
                              'Guardar cambios',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                    if (_modoTesting && kMostrarOpcionesTestingDestructivas)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: OutlinedButton.icon(
                          onPressed: _reseteando ? null : _confirmarReset,
                          icon: const Icon(Icons.restart_alt,
                              color: AppTheme.rojoGasto),
                          label: const Text('Resetear datos de prueba'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.rojoGasto,
                            side: const BorderSide(color: AppTheme.rojoGasto),
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSeccion(
      {required String titulo, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                color: AppTheme.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CampoNumerico extends StatelessWidget {
  const _CampoNumerico({
    required this.label,
    required this.controller,
    required this.ayuda,
    this.sufijo,
    this.soloEntero = false,
  });

  final String label;
  final TextEditingController controller;
  final String ayuda;
  final String? sufijo;
  final bool soloEntero;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: soloEntero
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            soloEntero
                ? FilteringTextInputFormatter.digitsOnly
                : FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          decoration: InputDecoration(
            labelText: label,
            suffixText: sufijo,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Campo obligatorio';
            if (double.tryParse(v) == null) return 'Número inválido';
            return null;
          },
        ),
        const SizedBox(height: 4),
        Text(
          ayuda,
          style: const TextStyle(
              fontSize: 11, color: AppTheme.textoSecundario),
        ),
      ],
    );
  }
}
