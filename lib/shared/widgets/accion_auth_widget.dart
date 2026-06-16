import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/admin/presentation/screens/admin_panel_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/perfil_screen.dart';

class AccionAuthWidget extends StatelessWidget {
  const AccionAuthWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return Padding(
        padding: const EdgeInsets.only(right: 16),
        child: OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white, width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          child: const Text('Ingresar'),
        ),
      );
    }

    final email = auth.currentUser?.email ?? '';
    final inicial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: CircleAvatar(
          backgroundColor: AppTheme.celesteAccento,
          radius: 17,
          child: Text(
            inicial,
            style: const TextStyle(
              color: AppTheme.azulOscuro,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            email,
            style: const TextStyle(color: AppTheme.textoSecundario, fontSize: 12),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PerfilScreen()),
          ),
          child: const Row(children: [
            Icon(Icons.person_outline, size: 18, color: AppTheme.azulMedio),
            SizedBox(width: 8),
            Text('Mi perfil'),
          ]),
        ),
        if (auth.esAdmin || auth.esAuditor) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
            ),
            child: const Row(children: [
              Icon(Icons.admin_panel_settings, size: 18, color: AppTheme.azulMedio),
              SizedBox(width: 8),
              Text('Panel de administración'),
            ]),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => context.read<AuthProvider>().logout(),
          child: const Row(children: [
            Icon(Icons.logout, size: 18, color: AppTheme.rojoGasto),
            SizedBox(width: 8),
            Text('Cerrar sesión'),
          ]),
        ),
      ],
    );
  }
}
