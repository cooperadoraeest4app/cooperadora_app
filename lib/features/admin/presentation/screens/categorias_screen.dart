import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/categoria_provider.dart';

const _kIconos = <(String, IconData)>[
  ('people', Icons.people),
  ('favorite', Icons.favorite),
  ('account_balance', Icons.account_balance),
  ('celebration', Icons.celebration),
  ('sell', Icons.sell),
  ('add_circle', Icons.add_circle),
  ('bolt', Icons.bolt),
  ('menu_book', Icons.menu_book),
  ('warehouse', Icons.warehouse),
  ('build', Icons.build),
  ('point_of_sale', Icons.point_of_sale),
  ('remove_circle', Icons.remove_circle),
  ('home_repair_service', Icons.home_repair_service),
  ('water_drop', Icons.water_drop),
  ('local_gas_station', Icons.local_gas_station),
];

const _kColoresPaleta = <Color>[
  Color(0xFF2E6DA4),
  Color(0xFF1A3A5C),
  Color(0xFF2E9E7A),
  Color(0xFF27AE60),
  Color(0xFF9B59B6),
  Color(0xFF8E44AD),
  Color(0xFFE67E22),
  Color(0xFFF39C12),
  Color(0xFFE74C3C),
  Color(0xFF6B7A99),
];

Color _colorFromHex(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

String _colorToHex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

IconData _iconFromNombre(String nombre) {
  for (final (n, i) in _kIconos) {
    if (n == nombre) return i;
  }
  return Icons.label;
}

class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CategoriaProvider>().inicializarDatosDefault();
    });
  }

  void _abrirModal([Map<String, dynamic>? categoria]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CategoriaSheet(categoria: categoria),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.azulOscuro,
          foregroundColor: AppTheme.blanco,
          iconTheme: const IconThemeData(color: AppTheme.blanco),
          titleTextStyle: const TextStyle(
            color: AppTheme.blanco,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          title: const Text('Categorías'),
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
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: context.watch<CategoriaProvider>().categorias,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final todas = snap.data ?? [];
            return TabBarView(
              children: [
                _ListaCategorias(
                  categorias:
                      todas.where((c) => c['tipo'] == 'ingreso').toList(),
                  onEditar: _abrirModal,
                ),
                _ListaCategorias(
                  categorias:
                      todas.where((c) => c['tipo'] == 'gasto').toList(),
                  onEditar: _abrirModal,
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppTheme.verdeTeal,
          foregroundColor: AppTheme.blanco,
          tooltip: 'Nueva categoría',
          onPressed: () => _abrirModal(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _ListaCategorias extends StatelessWidget {
  const _ListaCategorias({
    required this.categorias,
    required this.onEditar,
  });

  final List<Map<String, dynamic>> categorias;
  final void Function([Map<String, dynamic>?]) onEditar;

  @override
  Widget build(BuildContext context) {
    if (categorias.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: AppTheme.textoSecundario.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay categorías',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: AppTheme.textoSecundario),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: categorias.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _CategoriaCard(
        categoria: categorias[i],
        onEditar: () => onEditar(categorias[i]),
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  const _CategoriaCard({required this.categoria, required this.onEditar});

  final Map<String, dynamic> categoria;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final id = categoria['id'] as String? ?? '';
    final nombre = categoria['nombre'] as String? ?? '';
    final iconoNombre = categoria['icono'] as String? ?? 'label';
    final colorHex = categoria['color'] as String? ?? '#6B7A99';
    final activa = categoria['activa'] as bool? ?? true;
    final icono = _iconFromNombre(iconoNombre);
    final color = _colorFromHex(colorHex);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(30),
              child: Icon(icono, color: color, size: 22),
            ),
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
              value: activa,
              activeThumbColor: AppTheme.verdeTeal,
              activeTrackColor: AppTheme.verdeTeal.withAlpha(100),
              onChanged: (v) =>
                  context.read<CategoriaProvider>().activarDesactivar(id, v),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.azulMedio),
              tooltip: 'Editar categoría',
              onPressed: onEditar,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modal crear / editar ───────────────────────────────────────────────────────

class _CategoriaSheet extends StatefulWidget {
  const _CategoriaSheet({this.categoria});

  final Map<String, dynamic>? categoria;

  @override
  State<_CategoriaSheet> createState() => _CategoriaSheetState();
}

class _CategoriaSheetState extends State<_CategoriaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  late String _tipo;
  late String _colorHex;
  late String _iconoNombre;

  @override
  void initState() {
    super.initState();
    final cat = widget.categoria;
    _nombreCtrl.text = cat?['nombre'] as String? ?? '';
    _tipo = cat?['tipo'] as String? ?? 'ingreso';
    _colorHex =
        cat?['color'] as String? ?? _colorToHex(_kColoresPaleta.first);
    _iconoNombre = cat?['icono'] as String? ?? _kIconos.first.$1;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<CategoriaProvider>();
    final datos = {
      'nombre': _nombreCtrl.text.trim(),
      'tipo': _tipo,
      'color': _colorHex,
      'icono': _iconoNombre,
      'activa': true,
    };
    if (widget.categoria != null) {
      await provider.actualizar(widget.categoria!['id'] as String, datos);
    } else {
      await provider.crear(datos);
    }
    if (!mounted) return;
    final scaffold = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text(widget.categoria != null
            ? 'Categoría actualizada'
            : 'Categoría creada'),
        backgroundColor: AppTheme.verdeTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<CategoriaProvider>().isSaving;
    final esEdicion = widget.categoria != null;
    final colorSeleccionado = _colorFromHex(_colorHex);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
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
                esEdicion ? 'Editar categoría' : 'Nueva categoría',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textoPrincipal,
                ),
              ),
              const SizedBox(height: 20),

              // Nombre
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El nombre es obligatorio'
                    : null,
              ),
              const SizedBox(height: 16),

              // Tipo (solo al crear)
              if (!esEdicion) ...[
                const Text(
                  'Tipo',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textoSecundario),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _BotonTipo(
                        label: 'Ingreso',
                        seleccionado: _tipo == 'ingreso',
                        color: AppTheme.verdeIngreso,
                        onTap: () => setState(() => _tipo = 'ingreso'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BotonTipo(
                        label: 'Gasto',
                        seleccionado: _tipo == 'gasto',
                        color: AppTheme.rojoGasto,
                        onTap: () => setState(() => _tipo = 'gasto'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Color
              const Text(
                'Color',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _kColoresPaleta.map((color) {
                  final hex = _colorToHex(color);
                  final sel = _colorHex == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: sel
                            ? Border.all(
                                color: AppTheme.textoPrincipal, width: 3)
                            : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Ícono
              const Text(
                'Ícono',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kIconos.map((entrada) {
                  final (nombre, iconData) = entrada;
                  final sel = _iconoNombre == nombre;
                  return GestureDetector(
                    onTap: () => setState(() => _iconoNombre = nombre),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: sel
                            ? colorSeleccionado.withAlpha(40)
                            : const Color(0xFFF5F5F5),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                        border: Border.all(
                          color:
                              sel ? colorSeleccionado : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        iconData,
                        color: sel
                            ? colorSeleccionado
                            : AppTheme.textoSecundario,
                        size: 22,
                      ),
                    ),
                  );
                }).toList(),
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
                        esEdicion ? 'Guardar cambios' : 'Crear categoría',
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

class _BotonTipo extends StatelessWidget {
  const _BotonTipo({
    required this.label,
    required this.seleccionado,
    required this.color,
    required this.onTap,
  });

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
          border: Border.all(
            color: seleccionado ? color : AppTheme.celesteBorde,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: seleccionado ? color : AppTheme.textoSecundario,
              fontWeight:
                  seleccionado ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
