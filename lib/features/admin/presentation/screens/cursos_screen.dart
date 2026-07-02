import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../domain/models/curso.dart';
import '../providers/curso_provider.dart';

class CursosScreen extends StatefulWidget {
  const CursosScreen({super.key});

  @override
  State<CursosScreen> createState() => _CursosScreenState();
}

class _CursosScreenState extends State<CursosScreen> {
  void _abrirModal([Curso? curso]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CursoSheet(curso: curso),
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
        title: const Text('Cursos'),
        actions: const [AccionAuthWidget()],
      ),
      body: Builder(
        builder: (ctx) {
          final provider = context.watch<CursoProvider>();
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final cursos = provider.todos;
          if (cursos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: AppTheme.textoSecundario.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay cursos cargados',
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
            itemCount: cursos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _CursoCard(
              curso: cursos[i],
              onEditar: () => _abrirModal(cursos[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.verdeTeal,
        foregroundColor: AppTheme.blanco,
        tooltip: 'Nuevo curso',
        onPressed: () => _abrirModal(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CursoCard extends StatelessWidget {
  const _CursoCard({required this.curso, required this.onEditar});

  final Curso curso;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.school, color: AppTheme.azulMedio, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    curso.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textoPrincipal,
                    ),
                  ),
                  if (curso.nivel != null && curso.nivel!.isNotEmpty)
                    Text(
                      curso.nivel!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textoSecundario,
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: curso.activo,
              activeThumbColor: AppTheme.verdeTeal,
              activeTrackColor: AppTheme.verdeTeal.withAlpha(100),
              onChanged: (v) => context
                  .read<CursoProvider>()
                  .activarDesactivar(curso.id, v),
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

class _CursoSheet extends StatefulWidget {
  const _CursoSheet({this.curso});

  final Curso? curso;

  @override
  State<_CursoSheet> createState() => _CursoSheetState();
}

class _CursoSheetState extends State<_CursoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _nivelCtrl = TextEditingController();
  final _ordenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = widget.curso?.nombre ?? '';
    _nivelCtrl.text = widget.curso?.nivel ?? '';
    _ordenCtrl.text = widget.curso?.orden?.toString() ?? '';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _nivelCtrl.dispose();
    _ordenCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<CursoProvider>();
    final nombre = _nombreCtrl.text.trim();
    final nivel = _nivelCtrl.text.trim();
    final orden = int.tryParse(_ordenCtrl.text.trim());

    if (widget.curso != null) {
      await provider.actualizar(widget.curso!.copyWith(
        nombre: nombre,
        nivel: nivel.isEmpty ? null : nivel,
        orden: orden,
      ));
    } else {
      await provider.agregar(Curso(
        id: '',
        nombre: nombre,
        nivel: nivel.isEmpty ? null : nivel,
        orden: orden,
        activo: true,
      ));
    }
    if (!mounted) return;
    final scaffold = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    scaffold.showSnackBar(
      SnackBar(
        content:
            Text(widget.curso != null ? 'Curso actualizado' : 'Curso creado'),
        backgroundColor: AppTheme.verdeTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<CursoProvider>().isSaving;
    final esEdicion = widget.curso != null;

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
                esEdicion ? 'Editar curso' : 'Nuevo curso',
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _nivelCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nivel'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ordenCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Orden'),
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
                        esEdicion ? 'Guardar cambios' : 'Crear curso',
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
