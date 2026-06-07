import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCoopController = TextEditingController(text: '');
  final _nombreEscuelaController = TextEditingController(text: '');
  final _emailController = TextEditingController(text: '');
  final _telefonoController = TextEditingController(text: '');
  final _anioController =
      TextEditingController(text: DateTime.now().year.toString());
  final _quorumController = TextEditingController(text: '30');
  final _aprobacionController = TextEditingController(text: '50');

  bool _mostrarIngresosGastos = true;
  bool _mostrarProyectos = true;
  bool _mostrarCuentaBancaria = true;
  bool _mostrarResumenesBancarios = true;
  bool _mostrarSocios = false;

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

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Configuración guardada (próximamente conectado a Firestore)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: AppTheme.blanco,
        iconTheme: const IconThemeData(color: AppTheme.blanco),
        titleTextStyle: const TextStyle(
          color: AppTheme.blanco,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        title: const Text('Configuración'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCardDatos(),
              const SizedBox(height: 16),
              _buildCardSecciones(),
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
                onPressed: _guardar,
                child: const Text(
                  'Guardar configuración',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                labelText: 'Nombre de la Cooperadora',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Campo obligatorio'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreEscuelaController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Escuela',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Campo obligatorio'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email de contacto',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono de contacto',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _anioController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Año lectivo activo',
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Quórum mínimo (%)',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obligatorio';
                      final n = int.tryParse(v);
                      if (n == null || n < 0 || n > 100) {
                        return '0–100';
                      }
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
                    decoration: const InputDecoration(
                      labelText: 'Aprobación (%)',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Obligatorio';
                      final n = int.tryParse(v);
                      if (n == null || n < 0 || n > 100) {
                        return '0–100';
                      }
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

  Widget _buildCardSecciones() {
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
            _mostrarIngresosGastos,
            (v) => setState(() => _mostrarIngresosGastos = v),
          ),
          _buildSwitch(
            'Proyectos',
            _mostrarProyectos,
            (v) => setState(() => _mostrarProyectos = v),
          ),
          _buildSwitch(
            'Cuenta bancaria',
            _mostrarCuentaBancaria,
            (v) => setState(() => _mostrarCuentaBancaria = v),
          ),
          _buildSwitch(
            'Resúmenes bancarios',
            _mostrarResumenesBancarios,
            (v) => setState(() => _mostrarResumenesBancarios = v),
          ),
          _buildSwitch(
            'Socios',
            _mostrarSocios,
            (v) => setState(() => _mostrarSocios = v),
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
