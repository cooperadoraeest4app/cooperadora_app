import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../providers/rubro_provider.dart';
import '../../domain/models/rubro.dart';

class RubrosScreen extends StatefulWidget {
  const RubrosScreen({super.key});

  @override
  State<RubrosScreen> createState() => _RubrosScreenState();
}

class _RubrosScreenState extends State<RubrosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RubroProvider>().inicializarSiVacio();
    });
  }

  void _abrirModal([Rubro? rubro]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _RubroSheet(rubro: rubro),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                  'Rubros',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [AccionAuthWidget()],
          bottom: const TabBar(
            labelColor: AppTheme.blanco,
            unselectedLabelColor: AppTheme.celesteAccento,
            indicatorColor: AppTheme.verdeTeal,
            tabs: [
              Tab(text: 'Ingresos'),
              Tab(text: 'Gastos'),
            ],
          ),
        ),
        body: Builder(
          builder: (ctx) {
            final provider = context.watch<RubroProvider>();
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return TabBarView(
              children: [
                _ListaRubros(
                  rubros: provider.rubros.where((r) => r.tipo == 'ingreso').toList(),
                  onEditar: (r) => _abrirModal(r),
                ),
                _ListaRubros(
                  rubros: provider.rubros.where((r) => r.tipo == 'gasto').toList(),
                  onEditar: (r) => _abrirModal(r),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppTheme.verdeTeal,
          foregroundColor: AppTheme.blanco,
          tooltip: 'Nuevo rubro',
          onPressed: () => _abrirModal(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _ListaRubros extends StatelessWidget {
  const _ListaRubros({required this.rubros, required this.onEditar});
  final List<Rubro> rubros;
  final void Function(Rubro) onEditar;

  @override
  Widget build(BuildContext context) {
    if (rubros.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 64, color: AppTheme.textoSecundario.withAlpha(100)),
            const SizedBox(height: 16),
            Text('No hay rubros', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.textoSecundario)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rubros.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _RubroCard(
        rubro: rubros[i],
        onEditar: () => onEditar(rubros[i]),
      ),
    );
  }
}

class _RubroCard extends StatelessWidget {
  const _RubroCard({required this.rubro, required this.onEditar});
  final Rubro rubro;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final color = rubro.tipo == 'ingreso' ? AppTheme.verdeIngreso : AppTheme.rojoGasto;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(30),
              child: Icon(Icons.folder, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rubro.nombre, style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (rubro.esPredeterminado)
                    Text('Predeterminado', style: TextStyle(fontSize: 11, color: AppTheme.textoSecundario)),
                ],
              ),
            ),
            Switch(
              value: rubro.activo,
              activeThumbColor: AppTheme.verdeTeal,
              activeTrackColor: AppTheme.verdeTeal.withAlpha(100),
              onChanged: (v) async {
                if (!v && await context.read<RubroProvider>().tieneCategorias(rubro.id)) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se puede desactivar un rubro con categorías activas'),
                      backgroundColor: AppTheme.rojoGasto,
                    ),
                  );
                  return;
                }
                if (context.mounted) {
                  context.read<RubroProvider>().activarDesactivar(rubro.id, v);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.azulMedio),
              onPressed: onEditar,
            ),
          ],
        ),
      ),
    );
  }
}

class _RubroSheet extends StatefulWidget {
  const _RubroSheet({this.rubro});
  final Rubro? rubro;

  @override
  State<_RubroSheet> createState() => _RubroSheetState();
}

class _RubroSheetState extends State<_RubroSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  late String _tipo;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = widget.rubro?.nombre ?? '';
    _tipo = widget.rubro?.tipo ?? 'ingreso';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<RubroProvider>();
    final datos = {
      'nombre': _nombreCtrl.text.trim(),
      'tipo': _tipo,
      'activo': true,
      'esPredeterminado': false,
    };
    if (widget.rubro != null) {
      await provider.actualizar(widget.rubro!.id, datos);
    } else {
      await provider.crear(datos);
    }
    if (!mounted) return;
    final scaffold = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    scaffold.showSnackBar(SnackBar(
      content: Text(widget.rubro != null ? 'Rubro actualizado' : 'Rubro creado'),
      backgroundColor: AppTheme.verdeTeal,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<RubroProvider>().isSaving;
    final esEdicion = widget.rubro != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: const BoxDecoration(color: Color(0xFFE0E0E0), borderRadius: BorderRadius.all(Radius.circular(2))),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                esEdicion ? 'Editar rubro' : 'Nuevo rubro',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textoPrincipal),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              if (!esEdicion) ...[
                const Text('Tipo', style: TextStyle(fontSize: 12, color: AppTheme.textoSecundario)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _BotonTipo(
                        label: 'Ingreso', seleccionado: _tipo == 'ingreso',
                        color: AppTheme.verdeIngreso, onTap: () => setState(() => _tipo = 'ingreso'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BotonTipo(
                        label: 'Gasto', seleccionado: _tipo == 'gasto',
                        color: AppTheme.rojoGasto, onTap: () => setState(() => _tipo = 'gasto'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: isSaving ? null : _guardar,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.blanco))
                    : Text(esEdicion ? 'Guardar cambios' : 'Crear rubro',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotonTipo extends StatelessWidget {
  const _BotonTipo({required this.label, required this.seleccionado, required this.color, required this.onTap});
  final String label;
  final bool seleccionado;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado ? color.withAlpha(30) : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: seleccionado ? color : AppTheme.celesteBorde, width: seleccionado ? 2 : 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: seleccionado ? color : AppTheme.textoSecundario,
              fontWeight: seleccionado ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
