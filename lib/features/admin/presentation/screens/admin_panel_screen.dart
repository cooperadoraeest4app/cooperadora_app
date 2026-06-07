import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'configuracion_screen.dart';
import 'usuarios_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  static const _opciones = [
    _OpcionPanel(
      icono: Icons.settings,
      titulo: 'Configuración general',
      subtitulo: 'Nombre, logo, secciones públicas',
      esConfiguracion: true,
    ),
    _OpcionPanel(
      icono: Icons.people,
      titulo: 'Usuarios',
      subtitulo: 'Gestionar usuarios y roles',
      esUsuarios: true,
    ),
    _OpcionPanel(
      icono: Icons.mail,
      titulo: 'Invitaciones',
      subtitulo: 'Crear y gestionar invitaciones',
    ),
    _OpcionPanel(
      icono: Icons.label,
      titulo: 'Categorías',
      subtitulo: 'Categorías de ingresos y gastos',
    ),
    _OpcionPanel(
      icono: Icons.credit_card,
      titulo: 'Métodos de pago',
      subtitulo: 'Formas de pago disponibles',
    ),
  ];

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
        title: const Text('Panel de Administración'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _opciones.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final opcion = _opciones[index];
          return Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.celesteFondo,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Icon(opcion.icono, color: AppTheme.azulOscuro, size: 22),
              ),
              title: Text(
                opcion.titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textoPrincipal,
                ),
              ),
              subtitle: Text(
                opcion.subtitulo,
                style: const TextStyle(color: AppTheme.textoSecundario),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppTheme.textoSecundario,
              ),
              onTap: () {
                if (opcion.esConfiguracion) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ConfiguracionScreen(),
                    ),
                  );
                } else if (opcion.esUsuarios) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UsuariosScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Próximamente')),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _OpcionPanel {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool esConfiguracion;
  final bool esUsuarios;

  const _OpcionPanel({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    this.esConfiguracion = false,
    this.esUsuarios = false,
  });
}
