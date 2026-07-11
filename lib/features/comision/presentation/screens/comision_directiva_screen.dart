import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../admin/domain/models/persona.dart';
import '../../../admin/presentation/providers/cargo_provider.dart';
import '../../../admin/presentation/providers/persona_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';

class ComisionDirectivaScreen extends StatefulWidget {
  const ComisionDirectivaScreen({super.key});

  @override
  State<ComisionDirectivaScreen> createState() => _ComisionDirectivaScreenState();
}

class _ComisionDirectivaScreenState extends State<ComisionDirectivaScreen> {
  @override
  Widget build(BuildContext context) {
    final cargoProvider = context.watch<CargoProvider>();
    final personaProvider = context.watch<PersonaProvider>();

    Widget body;
    if (!cargoProvider.cargado) {
      body = const Center(child: CircularProgressIndicator());
    } else if (cargoProvider.cargos.isEmpty) {
      body = const Center(
        child: Text('Sin cargos registrados',
            style: TextStyle(color: AppTheme.textoSecundario)),
      );
    } else {
      final cargos = cargoProvider.cargos;
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: cargos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final cargo = cargos[i];
          final personaId = cargo['personaId'] as String?;
          final persona = personaId != null && personaId.isNotEmpty
              ? personaProvider.porId(personaId)
              : null;
          return _CargoCard(
            nombreCargo: cargo['nombre'] as String,
            persona: persona,
          );
        },
      );
    }

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
      body: body,
    );
  }
}

// ── Card de cargo ─────────────────────────────────────────────────────────────

class _CargoCard extends StatelessWidget {
  const _CargoCard({required this.nombreCargo, required this.persona});
  final String nombreCargo;
  final Persona? persona;

  @override
  Widget build(BuildContext context) {
    final fotoUrl = persona?.fotoUrl;
    final nombre = persona?.nombreCompleto ?? '';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: persona != null
              ? AppTheme.celesteAccento
              : AppTheme.celesteFondo,
          backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
          child: fotoUrl == null
              ? Icon(
                  persona != null ? null : Icons.person_outline,
                  color: persona != null ? null : AppTheme.textoSecundario,
                  size: 22,
                )
              : null,
        ),
        title: Text(
          nombreCargo,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppTheme.textoPrincipal),
        ),
        subtitle: Text(
          persona != null ? nombre : 'Vacante',
          style: const TextStyle(color: AppTheme.textoSecundario, fontSize: 13),
        ),
      ),
    );
  }
}
