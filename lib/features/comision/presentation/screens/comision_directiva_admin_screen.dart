import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../admin/domain/models/persona.dart';
import '../../../admin/presentation/providers/cargo_provider.dart';
import '../../../admin/presentation/providers/persona_provider.dart';
import '../../../../shared/widgets/app_drawer.dart';

class ComisionDirectivaAdminScreen extends StatefulWidget {
  const ComisionDirectivaAdminScreen({super.key});

  @override
  State<ComisionDirectivaAdminScreen> createState() =>
      _ComisionDirectivaAdminScreenState();
}

class _ComisionDirectivaAdminScreenState
    extends State<ComisionDirectivaAdminScreen> {
  @override
  void initState() {
    super.initState();
    // Asegurar que los 11 cargos por defecto existan en Firestore.
    // Esto solo crea documentos si la colección está vacía y el usuario es admin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CargoProvider>().inicializarSiVacio();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CargoProvider>();

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        foregroundColor: Colors.white,
        title: const Text('Comisión Directiva'),
        actions: const [AccionAuthWidget()],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.cargos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final cargo = provider.cargos[i];
                final personaId = cargo['personaId'] as String?;
                final personaProvider = context.read<PersonaProvider>();
                final persona = personaId != null && personaId.isNotEmpty
                    ? personaProvider.porId(personaId)
                    : null;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.celesteAccento,
                      backgroundImage: persona?.fotoUrl != null
                          ? NetworkImage(persona!.fotoUrl!)
                          : null,
                      child: persona?.fotoUrl == null
                          ? Text(
                              persona != null
                                  ? persona.nombreCompleto[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: AppTheme.azulOscuro,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            )
                          : null,
                    ),
                    title: Text(
                      cargo['nombre'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textoPrincipal),
                    ),
                    subtitle: Text(
                      persona != null
                          ? persona.nombreCompleto
                          : 'Vacante',
                      style: TextStyle(
                        color: persona != null
                            ? AppTheme.textoSecundario
                            : AppTheme.textoSecundario,
                        fontSize: 13,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: AppTheme.azulMedio),
                      onPressed: () => _editarCargo(context, cargo),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _editarCargo(
      BuildContext context, Map<String, dynamic> cargo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ModalAsignarPersona(cargo: cargo),
    );
  }
}

// ── Modal de asignación ───────────────────────────────────────────────────────

class _ModalAsignarPersona extends StatefulWidget {
  const _ModalAsignarPersona({required this.cargo});
  final Map<String, dynamic> cargo;

  @override
  State<_ModalAsignarPersona> createState() => _ModalAsignarPersonaState();
}

class _ModalAsignarPersonaState extends State<_ModalAsignarPersona> {
  final _searchCtrl = TextEditingController();
  Persona? _seleccionada;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final personaId = widget.cargo['personaId'] as String?;
    if (personaId != null && personaId.isNotEmpty) {
      final p = context.read<PersonaProvider>().porId(personaId);
      if (p != null) {
        _seleccionada = p;
        _searchCtrl.text = p.nombreCompleto;
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await context
          .read<CargoProvider>()
          .asignarPersona(widget.cargo['id'] as String, _seleccionada?.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.rojoGasto),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;
    final personaProvider = context.watch<PersonaProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.cargo['nombre'] as String,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Autocomplete<Persona>(
            displayStringForOption: (p) => p.nombreCompleto,
            fieldViewBuilder:
                (context, controller, focusNode, onEditingComplete) {
              if (_searchCtrl.text.isNotEmpty && controller.text.isEmpty) {
                controller.text = _searchCtrl.text;
              }
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                onEditingComplete: onEditingComplete,
                decoration: const InputDecoration(
                  labelText: 'Buscar persona',
                  prefixIcon: Icon(Icons.search),
                ),
              );
            },
            optionsBuilder: (value) {
              return personaProvider.buscar(value.text);
            },
            onSelected: (p) {
              setState(() => _seleccionada = p);
            },
          ),
          const SizedBox(height: 12),
          if (_seleccionada != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Chip(
                avatar: const Icon(Icons.person, size: 16,
                    color: AppTheme.azulOscuro),
                label: Text(_seleccionada!.nombreCompleto),
                backgroundColor: AppTheme.celesteFondo,
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() {
                  _seleccionada = null;
                  _searchCtrl.clear();
                }),
              ),
            ),
          const SizedBox(height: 8),
          if (_seleccionada != null)
            TextButton.icon(
              icon: const Icon(Icons.person_off_outlined, size: 18,
                  color: AppTheme.textoSecundario),
              label: const Text('Dejar vacante',
                  style: TextStyle(color: AppTheme.textoSecundario)),
              onPressed: () => setState(() {
                _seleccionada = null;
                _searchCtrl.clear();
              }),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.verdeTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
