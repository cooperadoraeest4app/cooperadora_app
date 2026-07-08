import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../admin/presentation/providers/cargo_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';

class ComisionDirectivaScreen extends StatefulWidget {
  const ComisionDirectivaScreen({super.key});

  @override
  State<ComisionDirectivaScreen> createState() => _ComisionDirectivaScreenState();
}

// StatefulWidget para que el botón "Reintentar" pueda llamar setState(),
// lo que fuerza una reconstrucción y pasa un Stream nuevo al StreamBuilder.
class _ComisionDirectivaScreenState extends State<ComisionDirectivaScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppTheme.azulOscuro,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.3)),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: const Icon(Icons.home, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                ),
              ),
            ),
            Container(width: 1, height: 20, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Comisión Directiva',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [AccionAuthWidget()],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context.read<CargoProvider>().cargosStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.rojoGasto, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.rojoGasto),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          final cargos = snapshot.data ?? [];
          if (cargos.isEmpty) {
            return const Center(
              child: Text('Sin cargos registrados',
                  style: TextStyle(color: AppTheme.textoSecundario)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cargos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final cargo = cargos[i];
              final personaId = cargo['personaId'] as String?;
              return _CargoCard(cargo: cargo, personaId: personaId);
            },
          );
        },
      ),
    );
  }
}

// ── Cards de cargo ────────────────────────────────────────────────────────────

class _CargoCard extends StatelessWidget {
  const _CargoCard({required this.cargo, required this.personaId});
  final Map<String, dynamic> cargo;
  final String? personaId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: personaId != null && personaId!.isNotEmpty
          ? _CardConPersona(
              nombreCargo: cargo['nombre'] as String,
              personaId: personaId!,
            )
          : _CardVacante(nombreCargo: cargo['nombre'] as String),
    );
  }
}

class _CardVacante extends StatelessWidget {
  const _CardVacante({required this.nombreCargo});
  final String nombreCargo;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.celesteFondo,
        child: Icon(Icons.person_outline, color: AppTheme.textoSecundario, size: 22),
      ),
      title: Text(
        nombreCargo,
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textoPrincipal),
      ),
      subtitle: const Text('Vacante',
          style: TextStyle(color: AppTheme.textoSecundario, fontSize: 13)),
    );
  }
}

class _CardConPersona extends StatefulWidget {
  const _CardConPersona({required this.nombreCargo, required this.personaId});
  final String nombreCargo;
  final String personaId;

  @override
  State<_CardConPersona> createState() => _CardConPersonaState();
}

class _CardConPersonaState extends State<_CardConPersona> {
  Map<String, dynamic>? _persona;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(_CardConPersona old) {
    super.didUpdateWidget(old);
    if (old.personaId != widget.personaId) _cargar();
  }

  Future<void> _cargar() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('personas')
          .doc(widget.personaId)
          .get();
      if (mounted) {
        setState(() {
          _persona = doc.data();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
        leading: CircleAvatar(radius: 22, backgroundColor: AppTheme.celesteFondo),
        title: LinearProgressIndicator(),
      );
    }

    final nombre = _persona != null
        ? '${_persona!['nombre'] ?? ''} ${_persona!['apellido'] ?? ''}'.trim()
        : '';
    final fotoUrl = _persona?['fotoUrl'] as String?;
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.celesteAccento,
        backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
        child: fotoUrl == null
            ? Text(
                inicial,
                style: const TextStyle(
                    color: AppTheme.azulOscuro,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              )
            : null,
      ),
      title: Text(
        widget.nombreCargo,
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textoPrincipal),
      ),
      subtitle: Text(
        nombre.isNotEmpty ? nombre : 'Persona no encontrada',
        style: const TextStyle(color: AppTheme.textoSecundario, fontSize: 13),
      ),
    );
  }
}
