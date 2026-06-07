import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/usuarios_provider.dart';

class UsuariosScreen extends StatelessWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsuariosProvider>();

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
        title: const Text('Usuarios'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: provider.usuarios,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final usuarios = snap.data ?? [];
          if (usuarios.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: usuarios.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _UsuarioCard(
              usuario: usuarios[index],
              provider: provider,
            ),
          );
        },
      ),
    );
  }
}

class _UsuarioCard extends StatelessWidget {
  const _UsuarioCard({required this.usuario, required this.provider});

  final Map<String, dynamic> usuario;
  final UsuariosProvider provider;

  @override
  Widget build(BuildContext context) {
    final id = usuario['id'] as String? ?? '';
    final email = usuario['email'] as String? ?? id;
    final rol = usuario['rol'] as String? ?? 'sin_rol';
    final activo = usuario['activo'] as bool? ?? false;
    final inicial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.celesteFondo,
              child: Text(
                inicial,
                style: const TextStyle(
                  color: AppTheme.azulOscuro,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: const TextStyle(
                      color: AppTheme.textoPrincipal,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _RolChip(rol: rol),
                ],
              ),
            ),
            Switch(
              value: activo,
              activeThumbColor: AppTheme.verdeTeal,
              activeTrackColor: AppTheme.verdeTeal.withAlpha(100),
              onChanged: (v) => provider.activarDesactivar(id, v),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.azulMedio),
              tooltip: 'Cambiar rol',
              onPressed: () => _mostrarSelectorRol(context, id, rol),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarSelectorRol(BuildContext context, String id, String rolActual) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SelectorRol(
        rolActual: rolActual,
        onSeleccionar: (nuevoRol) {
          Navigator.pop(context);
          provider.actualizarRol(id, nuevoRol);
        },
      ),
    );
  }
}

class _RolChip extends StatelessWidget {
  const _RolChip({required this.rol});

  final String rol;

  static (Color bg, Color fg) _colores(String rol) => switch (rol) {
        'admin' => (AppTheme.azulOscuro, AppTheme.blanco),
        'editor' => (AppTheme.verdeTeal, AppTheme.blanco),
        'solo_lectura' => (const Color(0xFFE0E0E0), AppTheme.textoSecundario),
        'consultante' => (Color(0xFFFFE0B2), Color(0xFFE65100)),
        _ => (const Color(0xFFE0E0E0), AppTheme.textoSecundario),
      };

  static String _label(String rol) => switch (rol) {
        'admin' => 'Admin',
        'editor' => 'Editor',
        'solo_lectura' => 'Solo lectura',
        'consultante' => 'Consultante',
        _ => rol,
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colores(rol);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        _label(rol),
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SelectorRol extends StatelessWidget {
  const _SelectorRol({
    required this.rolActual,
    required this.onSeleccionar,
  });

  final String rolActual;
  final ValueChanged<String> onSeleccionar;

  static const _roles = [
    ('admin', 'Admin', Icons.admin_panel_settings,
        'Acceso completo a todas las funciones'),
    ('editor', 'Editor', Icons.edit_note,
        'Puede cargar y editar movimientos'),
    ('solo_lectura', 'Solo lectura', Icons.visibility,
        'Puede ver todo pero no modificar'),
    ('consultante', 'Consultante', Icons.person_outline,
        'Acceso solo a secciones públicas'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cambiar rol',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textoPrincipal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._roles.map(
            (r) => ListTile(
              leading: Icon(r.$3, color: AppTheme.azulMedio),
              title: Text(
                r.$2,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                r.$4,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario),
              ),
              trailing: rolActual == r.$1
                  ? const Icon(Icons.check_circle, color: AppTheme.verdeTeal)
                  : null,
              onTap: () => onSeleccionar(r.$1),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppTheme.textoSecundario.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay usuarios registrados',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textoSecundario,
                ),
          ),
        ],
      ),
    );
  }
}
