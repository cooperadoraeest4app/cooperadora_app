import 'package:flutter/material.dart';
import '../../../home/presentation/screens/home_screen.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/nombre_usuario_widget.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/usuarios_provider.dart';
import 'usuario_detalle_screen.dart';
import '../../../../shared/widgets/app_drawer.dart';

class UsuariosScreen extends StatelessWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsuariosProvider>();
    final auth = context.watch<AuthProvider>();
    final miId = auth.datosUsuario?['id'] as String? ?? auth.currentUser?.uid;

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
                'Usuarios',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [AccionAuthWidget()],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: provider.usuariosStream,
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
              miId: miId,
            ),
          );
        },
      ),
    );
  }
}

class _UsuarioCard extends StatelessWidget {
  const _UsuarioCard({
    required this.usuario,
    required this.provider,
    required this.miId,
  });

  final Map<String, dynamic> usuario;
  final UsuariosProvider provider;
  final String? miId;

  @override
  Widget build(BuildContext context) {
    final id = usuario['id'] as String? ?? '';
    final email = usuario['email'] as String? ?? id;
    final rol = usuario['rol'] as String? ?? 'sin_rol';
    final activo = usuario['activo'] as bool? ?? false;
    final inicial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final esMiCuenta = miId != null && id == miId;
    final esAdminUser = rol == 'admin';

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
                  Row(
                    children: [
                      Flexible(
                        child: NombreUsuarioWidget(
                          usuarioId: id,
                          style: const TextStyle(
                            color: AppTheme.textoPrincipal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (esAdminUser) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.shield,
                          size: 14,
                          color: AppTheme.azulMedio,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textoSecundario,
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
              icon: Icon(
                Icons.edit,
                color: esMiCuenta
                    ? AppTheme.textoSecundario.withAlpha(80)
                    : AppTheme.azulMedio,
              ),
              tooltip: esMiCuenta
                  ? 'No podés cambiar tu propio rol'
                  : 'Cambiar rol',
              onPressed:
                  esMiCuenta ? null : () => _mostrarSelectorRol(context, id, rol),
            ),
            IconButton(
              icon: const Icon(Icons.person, color: AppTheme.azulMedio),
              tooltip: 'Ver detalle',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UsuarioDetalleScreen(usuarioId: id),
                ),
              ),
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
        'auditor' => (AppTheme.azulMedio, AppTheme.blanco),
        'solo_lectura' => (const Color(0xFFE0E0E0), AppTheme.textoSecundario),
        'consultante' => (const Color(0xFFFFE0B2), const Color(0xFFE65100)),
        _ => (const Color(0xFFE0E0E0), AppTheme.textoSecundario),
      };

  static String _label(String rol) => switch (rol) {
        'admin' => 'Admin',
        'editor' => 'Editor',
        'auditor' => 'Auditor',
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
    ('auditor', 'Auditor', Icons.history,
        'Puede ver el log de cambios y toda la información'),
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
