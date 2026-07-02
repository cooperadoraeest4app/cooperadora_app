import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/admin/presentation/providers/usuarios_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

class NombreUsuarioWidget extends StatelessWidget {
  const NombreUsuarioWidget({
    super.key,
    required this.usuarioId,
    this.style,
    this.prefijo = '',
  });

  final String usuarioId;
  final TextStyle? style;
  final String prefijo;

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isLoggedIn) {
      return const SizedBox.shrink();
    }

    if (usuarioId.isEmpty) {
      return Text('${prefijo}Sin asignar', style: style);
    }

    final usuariosProvider = context.watch<UsuariosProvider>();

    if (usuariosProvider.isLoading) {
      return SizedBox(
        height: 14,
        width: 80,
        child: LinearProgressIndicator(
          color: AppTheme.celesteAccento,
          backgroundColor: AppTheme.celesteFondo,
        ),
      );
    }

    debugPrint('NombreUsuarioWidget buscando: $usuarioId');
    debugPrint('Usuarios disponibles: '
        '${usuariosProvider.usuarios.map((u) => "${u['id']} / ${u['authUid']}").toList()}');

    final usuario = usuariosProvider.usuarios.firstWhere(
      (u) => u['id'] == usuarioId || u['authUid'] == usuarioId,
      orElse: () => {},
    );

    debugPrint('Match encontrado: $usuario');

    final nombre = usuario['nombreCompleto'] as String? ??
        usuario['email'] as String? ??
        usuarioId;

    return Text('$prefijo$nombre', style: style);
  }
}
