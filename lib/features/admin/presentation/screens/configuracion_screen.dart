import 'package:flutter/material.dart';
import '../../../home/presentation/screens/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../providers/configuracion_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCoopController = TextEditingController();
  final _nombreEscuelaController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _anioController = TextEditingController();
  final _quorumController = TextEditingController();
  final _aprobacionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarDatos());
  }

  Future<void> _cargarDatos() async {
    final provider = context.read<ConfiguracionProvider>();
    await provider.cargar();
    if (!mounted) return;
    _nombreCoopController.text = provider.nombreCooperadora;
    _nombreEscuelaController.text = provider.nombreEscuela;
    _emailController.text = provider.emailContacto;
    _telefonoController.text = provider.telefonoContacto;
    _anioController.text = provider.anioLectivo.toString();
    _quorumController.text = provider.quorumMinimo.toString();
    _aprobacionController.text = provider.porcentajeAprobacion.toString();
  }

  @override
  void dispose() {
    _nombreCoopController.dispose();
    _nombreEscuelaController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _anioController.dispose();
    _quorumController.dispose();
    _aprobacionController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ConfiguracionProvider>();
    await provider.guardar(
      nombreCooperadora: _nombreCoopController.text.trim(),
      nombreEscuela: _nombreEscuelaController.text.trim(),
      emailContacto: _emailController.text.trim(),
      telefonoContacto: _telefonoController.text.trim(),
      anioLectivo: int.parse(_anioController.text),
      quorumMinimo: int.parse(_quorumController.text),
      porcentajeAprobacion: int.parse(_aprobacionController.text),
    );
    if (!mounted) return;
    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: AppTheme.rojoGasto,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración guardada correctamente'),
          backgroundColor: AppTheme.verdeIngreso,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConfiguracionProvider>();

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
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(width: 1, height: 20, color: Colors.white.withOpacity(0.3)),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: Icon(Icons.home, color: Colors.white.withOpacity(0.8), size: 20),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                ),
              ),
            ),
            Container(width: 1, height: 20, color: Colors.white.withOpacity(0.3)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Configuración',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [AccionAuthWidget()],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCardDatos(),
                    const SizedBox(height: 16),
                    _buildCardSecciones(provider),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.verdeTeal,
                        foregroundColor: AppTheme.blanco,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      onPressed: provider.isSaving ? null : _guardar,
                      child: provider.isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.blanco,
                              ),
                            )
                          : const Text(
                              'Guardar configuración',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCardDatos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nombreCoopController,
              decoration: const InputDecoration(
                  labelText: 'Nombre de la Cooperadora'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Campo obligatorio'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreEscuelaController,
              decoration:
                  const InputDecoration(labelText: 'Nombre de la Escuela'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Campo obligatorio'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'Email de contacto'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Teléfono de contacto'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _anioController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration:
                        const InputDecoration(labelText: 'Año lectivo activo'),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Campo obligatorio'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _quorumController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration:
                        const InputDecoration(labelText: 'Quórum mínimo (%)'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obligatorio';
                      final n = int.tryParse(v);
                      if (n == null || n < 0 || n > 100) return '0–100';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _aprobacionController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration:
                        const InputDecoration(labelText: 'Aprobación (%)'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obligatorio';
                      final n = int.tryParse(v);
                      if (n == null || n < 0 || n > 100) return '0–100';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSecciones(ConfiguracionProvider provider) {
    final s = provider.seccionesPublicas;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Secciones públicas',
              style: TextStyle(
                color: AppTheme.textoSecundario,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _buildSwitch(
            'Ingresos y gastos',
            s['ingresos'] ?? true,
            (v) => provider.actualizarSeccion('ingresos', v),
          ),
          _buildSwitch(
            'Proyectos',
            s['proyectos'] ?? true,
            (v) => provider.actualizarSeccion('proyectos', v),
          ),
          _buildSwitch(
            'Cuenta bancaria',
            s['cuentaBancaria'] ?? true,
            (v) => provider.actualizarSeccion('cuentaBancaria', v),
          ),
          _buildSwitch(
            'Resúmenes bancarios',
            s['resumenesBancarios'] ?? true,
            (v) => provider.actualizarSeccion('resumenesBancarios', v),
          ),
          _buildSwitch(
            'Socios',
            s['socios'] ?? false,
            (v) => provider.actualizarSeccion('socios', v),
          ),
          _buildSwitch(
            'Inventario',
            s['inventario'] ?? true,
            (v) => provider.actualizarSeccion('inventario', v),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      activeThumbColor: AppTheme.verdeTeal,
      activeTrackColor: AppTheme.verdeTeal.withAlpha(100),
      onChanged: onChanged,
    );
  }
}
