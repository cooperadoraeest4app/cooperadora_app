import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'categorias_screen.dart';
import 'configuracion_screen.dart';
import 'invitaciones_screen.dart';
import 'metodos_pago_screen.dart';
import 'usuarios_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
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
      esInvitaciones: true,
    ),
    _OpcionPanel(
      icono: Icons.label,
      titulo: 'Categorías',
      subtitulo: 'Categorías de ingresos y gastos',
      esCategorias: true,
    ),
    _OpcionPanel(
      icono: Icons.credit_card,
      titulo: 'Métodos de pago',
      subtitulo: 'Formas de pago disponibles',
      esMetodosPago: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (!auth.esAdmin) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tenés permisos para acceder a esta sección'),
            backgroundColor: AppTheme.rojoGasto,
          ),
        );
      }
    });
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
                child:
                    Icon(opcion.icono, color: AppTheme.azulOscuro, size: 22),
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
                        builder: (_) => const ConfiguracionScreen()),
                  );
                } else if (opcion.esUsuarios) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UsuariosScreen()),
                  );
                } else if (opcion.esInvitaciones) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InvitacionesScreen()),
                  );
                } else if (opcion.esCategorias) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CategoriasScreen()),
                  );
                } else if (opcion.esMetodosPago) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MetodosPagoScreen()),
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
  final bool esInvitaciones;
  final bool esCategorias;
  final bool esMetodosPago;

  const _OpcionPanel({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    this.esConfiguracion = false,
    this.esUsuarios = false,
    this.esInvitaciones = false,
    this.esCategorias = false,
    this.esMetodosPago = false,
  });
}
