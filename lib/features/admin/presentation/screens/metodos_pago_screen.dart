import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../providers/metodo_pago_provider.dart';

class MetodosPagoScreen extends StatefulWidget {
  const MetodosPagoScreen({super.key});

  @override
  State<MetodosPagoScreen> createState() => _MetodosPagoScreenState();
}

class _MetodosPagoScreenState extends State<MetodosPagoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MetodoPagoProvider>().inicializarDatosDefault();
      }
    });
  }

  void _abrirModal([Map<String, dynamic>? metodo]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MetodoPagoSheet(metodo: metodo),
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
        title: const Text('Métodos de pago'),
        actions: const [AccionAuthWidget()],
      ),
      body: Builder(
        builder: (ctx) {
          final provider = context.watch<MetodoPagoProvider>();
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final metodos = provider.metodosPago;
          if (metodos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.credit_card_outlined,
                    size: 64,
                    color: AppTheme.textoSecundario.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay métodos de pago',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textoSecundario,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: metodos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _MetodoPagoCard(
              metodo: metodos[i],
              onEditar: () => _abrirModal(metodos[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.verdeTeal,
        foregroundColor: AppTheme.blanco,
        tooltip: 'Nuevo método de pago',
        onPressed: () => _abrirModal(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MetodoPagoCard extends StatelessWidget {
  const _MetodoPagoCard({required this.metodo, required this.onEditar});

  final Map<String, dynamic> metodo;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final id = metodo['id'] as String? ?? '';
    final nombre = metodo['nombre'] as String? ?? '';
    final activo = metodo['activo'] as bool? ?? true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.payment, color: AppTheme.azulMedio, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textoPrincipal,
                ),
              ),
            ),
            Switch(
              value: activo,
              activeThumbColor: AppTheme.verdeTeal,
              activeTrackColor: AppTheme.verdeTeal.withAlpha(100),
              onChanged: (v) =>
                  context.read<MetodoPagoProvider>().activarDesactivar(id, v),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.azulMedio),
              tooltip: 'Editar',
              onPressed: onEditar,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modal crear / editar ───────────────────────────────────────────────────────

class _MetodoPagoSheet extends StatefulWidget {
  const _MetodoPagoSheet({this.metodo});

  final Map<String, dynamic>? metodo;

  @override
  State<_MetodoPagoSheet> createState() => _MetodoPagoSheetState();
}

class _MetodoPagoSheetState extends State<_MetodoPagoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = widget.metodo?['nombre'] as String? ?? '';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<MetodoPagoProvider>();
    final nombre = _nombreCtrl.text.trim();
    if (widget.metodo != null) {
      await provider.actualizar(
          widget.metodo!['id'] as String, {'nombre': nombre});
    } else {
      await provider.crear({'nombre': nombre, 'activo': true, 'orden': 99});
    }
    if (!mounted) return;
    final scaffold = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text(
            widget.metodo != null ? 'Método actualizado' : 'Método creado'),
        backgroundColor: AppTheme.verdeTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<MetodoPagoProvider>().isSaving;
    final esEdicion = widget.metodo != null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                esEdicion ? 'Editar método de pago' : 'Nuevo método de pago',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textoPrincipal,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                autofocus: true,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El nombre es obligatorio'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isSaving ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.blanco,
                        ),
                      )
                    : Text(
                        esEdicion ? 'Guardar cambios' : 'Crear método',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
