import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/admin/domain/models/persona.dart';
import '../../features/admin/presentation/providers/curso_provider.dart';

// ── SeccionHijosWidget ────────────────────────────────────────────────────────

class SeccionHijosWidget extends StatefulWidget {
  const SeccionHijosWidget({
    super.key,
    required this.personaId,
    required this.puedeEditar,
  });
  final String personaId;
  final bool puedeEditar;

  @override
  State<SeccionHijosWidget> createState() => _SeccionHijosWidgetState();
}

class _SeccionHijosWidgetState extends State<SeccionHijosWidget> {
  List<String> _hijosIds = [];
  StreamSubscription<DocumentSnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('personas')
        .doc(widget.personaId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data() ?? {};
      setState(() {
        _hijosIds =
            (data['hijosIds'] as List<dynamic>?)?.cast<String>() ?? [];
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _vincularHijo(String hijoId) async {
    await FirebaseFirestore.instance
        .collection('personas')
        .doc(widget.personaId)
        .update({'hijosIds': FieldValue.arrayUnion([hijoId])});
  }

  Future<void> _desvincularHijo(String hijoId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular hijo/a'),
        content:
            const Text('¿Confirmás que querés desvincular a este hijo/a?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.rojoGasto,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await FirebaseFirestore.instance
        .collection('personas')
        .doc(widget.personaId)
        .update({'hijosIds': FieldValue.arrayRemove([hijoId])});
  }

  void _abrirModalHijo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ModalAgregarHijo(onVincular: _vincularHijo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                const Icon(Icons.family_restroom,
                    size: 18, color: AppTheme.azulMedio),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Hijos/as en la institución',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textoPrincipal,
                    ),
                  ),
                ),
                if (widget.puedeEditar)
                  TextButton.icon(
                    onPressed: _abrirModalHijo,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.verdeTeal,
                        visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_hijosIds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sin hijos/as vinculados.',
                style: TextStyle(color: AppTheme.textoSecundario),
              ),
            )
          else
            ..._hijosIds.map((id) => _HijoTile(
                  personaId: id,
                  puedeEditar: widget.puedeEditar,
                  onDesvincular: () => _desvincularHijo(id),
                )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── _HijoTile ─────────────────────────────────────────────────────────────────

class _HijoTile extends StatefulWidget {
  const _HijoTile({
    required this.personaId,
    required this.puedeEditar,
    required this.onDesvincular,
  });
  final String personaId;
  final bool puedeEditar;
  final VoidCallback onDesvincular;

  @override
  State<_HijoTile> createState() => _HijoTileState();
}

class _HijoTileState extends State<_HijoTile> {
  late final Stream<DocumentSnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('personas')
        .doc(widget.personaId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        final data =
            snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final nombre =
            '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
        final cursoId = data['cursoId'] as String?;
        final curso = cursoId != null
            ? context.watch<CursoProvider>().obtenerPorId(cursoId)
            : null;
        return ListTile(
          dense: true,
          title: Text(nombre.isEmpty ? '(sin nombre)' : nombre),
          subtitle: Text(curso?.nombre ?? 'Sin curso asignado'),
          trailing: widget.puedeEditar
              ? IconButton(
                  icon:
                      const Icon(Icons.link_off, color: AppTheme.rojoGasto),
                  tooltip: 'Desvincular',
                  onPressed: widget.onDesvincular,
                )
              : null,
        );
      },
    );
  }
}

// ── _ModalAgregarHijo ─────────────────────────────────────────────────────────

class _ModalAgregarHijo extends StatefulWidget {
  const _ModalAgregarHijo({required this.onVincular});
  final Future<void> Function(String hijoId) onVincular;

  @override
  State<_ModalAgregarHijo> createState() => _ModalAgregarHijoState();
}

class _ModalAgregarHijoState extends State<_ModalAgregarHijo> {
  final _dniController = TextEditingController();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  bool _buscando = false;
  bool _busquedaRealizada = false;
  Persona? _personaEncontrada;
  String? _cursoId;
  bool _saving = false;

  @override
  void dispose() {
    _dniController.dispose();
    _nombreController.dispose();
    _apellidoController.dispose();
    super.dispose();
  }

  Future<void> _buscarPorDni() async {
    final dni = _dniController.text.trim();
    if (dni.isEmpty) return;
    setState(() {
      _buscando = true;
      _busquedaRealizada = false;
      _personaEncontrada = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('personas')
          .where('dni', isEqualTo: dni)
          .limit(1)
          .get();
      if (!mounted) return;
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        setState(
            () => _personaEncontrada = Persona.fromMap(doc.data(), doc.id));
      }
      setState(() => _busquedaRealizada = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al buscar: $e')));
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _vincularExistente() async {
    if (_personaEncontrada == null) return;
    setState(() => _saving = true);
    try {
      await widget.onVincular(_personaEncontrada!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _crearYVincular() async {
    final nombre = _nombreController.text.trim();
    final apellido = _apellidoController.text.trim();
    if (nombre.isEmpty || apellido.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nombre y apellido son requeridos')));
      return;
    }
    setState(() => _saving = true);
    try {
      final ahora = DateTime.now();
      final nuevaPersona = Persona(
        id: '',
        tipoPersona: 'fisica',
        nombre: nombre,
        apellido: apellido,
        dni: _dniController.text.trim().isEmpty
            ? null
            : _dniController.text.trim(),
        subtipo: 'alumno',
        cursoId: _cursoId,
        activo: true,
        fechaCreacion: ahora,
      );
      final ref = await FirebaseFirestore.instance
          .collection('personas')
          .add(nuevaPersona.toMap());
      await widget.onVincular(ref.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cursos = context.watch<CursoProvider>().activos;
    print('[Cursos] cantidad: ${cursos.length}');
    for (final c in cursos) {
      print('[Cursos] ${c.id} → ${c.nombre}');
    }
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Agregar hijo/a',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dniController,
                    decoration: const InputDecoration(
                        labelText: 'DNI del alumno/a'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _buscando ? null : _buscarPorDni,
                  child: _buscando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Buscar'),
                ),
              ],
            ),
            if (_busquedaRealizada) ...[
              const SizedBox(height: 12),
              if (_personaEncontrada != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.verdeIngreso.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.verdeIngreso),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person,
                          color: AppTheme.verdeIngreso, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_personaEncontrada!.nombre} ${_personaEncontrada!.apellido}'
                              .trim(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _vincularExistente,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.verdeTeal,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Vincular'),
                  ),
                ),
              ] else ...[
                const Text(
                  'No se encontró ninguna persona con ese DNI. '
                  'Podés crear un nuevo alumno/a:',
                  style: TextStyle(color: AppTheme.textoSecundario),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _apellidoController,
                  decoration:
                      const InputDecoration(labelText: 'Apellido *'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _cursoId,
                  decoration: const InputDecoration(labelText: 'Curso'),
                  items: cursos
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nombre),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _cursoId = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _crearYVincular,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.verdeTeal,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Crear y vincular'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
