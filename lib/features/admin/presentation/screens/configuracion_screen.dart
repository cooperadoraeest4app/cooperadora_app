import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../../../home/presentation/screens/home_screen.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../providers/configuracion_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/logo_cooperadora_widget.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _subiendoLogo = false;

  final _nombreCoopController = TextEditingController();
  final _nombreEscuelaController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _anioController = TextEditingController();

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
  }

  @override
  void dispose() {
    _nombreCoopController.dispose();
    _nombreEscuelaController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _anioController.dispose();
    super.dispose();
  }

  Future<void> _subirLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.size > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El archivo no puede superar 2MB'),
            backgroundColor: AppTheme.rojoGasto,
          ),
        );
      }
      return;
    }

    setState(() => _subiendoLogo = true);
    try {
      final ref = FirebaseStorage.instance
          .ref('configuracion/logo/logo_cooperadora.${file.extension}');
      await ref.putData(file.bytes!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('config')
          .update({'logoUrl': url});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo actualizado correctamente'),
            backgroundColor: AppTheme.verdeIngreso,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir el logo: $e'),
            backgroundColor: AppTheme.rojoGasto,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  Future<void> _eliminarLogo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar logo'),
        content: const Text('¿Confirmás que querés eliminar el logo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.rojoGasto,
                foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final list = await FirebaseStorage.instance
          .ref('configuracion/logo')
          .listAll();
      await Future.wait(list.items.map((item) => item.delete()));

      await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('config')
          .update({'logoUrl': FieldValue.delete()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo eliminado'),
            backgroundColor: AppTheme.verdeIngreso,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: AppTheme.rojoGasto,
          ),
        );
      }
    }
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

  Widget _buildLogoSection() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('configuracion')
          .doc('config')
          .snapshots(),
      builder: (context, snap) {
        final data =
            snap.data?.data() as Map<String, dynamic>? ?? {};
        final logoUrl = data['logoUrl'] as String?;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Logo de la Cooperadora',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LogoCooperadoraWidget(size: 80, borderRadius: 8),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      icon: _subiendoLogo
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.upload, size: 16),
                      label: Text(logoUrl != null
                          ? 'Cambiar logo'
                          : 'Subir logo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.azulMedio,
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          _subiendoLogo ? null : _subirLogo,
                    ),
                    if (logoUrl != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.delete,
                            size: 16,
                            color: AppTheme.rojoGasto),
                        label: const Text('Eliminar',
                            style: TextStyle(
                                color: AppTheme.rojoGasto)),
                        onPressed: _eliminarLogo,
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      'PNG o JPG, máx. 2MB',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textoSecundario),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCardDatos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLogoSection(),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
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
            TextFormField(
              controller: _anioController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  const InputDecoration(labelText: 'Año lectivo activo'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
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
