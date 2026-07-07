import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/admin/presentation/providers/configuracion_provider.dart';
import '../../features/admin/presentation/screens/admin_panel_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/perfil_screen.dart';
import '../../features/comision/presentation/screens/comision_directiva_screen.dart';
import '../../features/cuenta_bancaria/presentation/screens/cuenta_bancaria_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/inventario/presentation/screens/inventario_screen.dart';
import '../../features/ingresos/presentation/screens/movimientos_screen.dart';
import '../../features/proyectos/presentation/screens/proyectos_screen.dart';

class AppDrawer extends StatelessWidget {
  final bool esInicio;
  const AppDrawer({super.key, this.esInicio = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final config = context.watch<ConfiguracionProvider>();
    final secciones = config.seccionesPublicas;
    final puedeVolver = !esInicio;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          DrawerHeader(
            decoration: const BoxDecoration(color: AppTheme.azulOscuro),
            margin: EdgeInsets.zero,
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.school, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    config.nombreCooperadora.isNotEmpty
                        ? config.nombreCooperadora
                        : 'Cooperadora',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  if (config.nombreEscuela.isNotEmpty)
                    Text(
                      config.nombreEscuela,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                ],
              ),
            ),
          ),

          // Volver — solo si hay pantalla anterior
          if (puedeVolver) ...[
            ListTile(
              leading: const Icon(Icons.arrow_back,
                  color: AppTheme.textoSecundario),
              title: const Text('Volver',
                  style: TextStyle(color: AppTheme.textoSecundario)),
              tileColor: AppTheme.textoSecundario.withValues(alpha: 0.08),
              onTap: () {
                Navigator.pop(context); // cierra drawer
                Navigator.pop(context); // vuelve atrás
              },
            ),
            const Divider(height: 1),
          ],

          // Inicio
          ListTile(
            leading: const Icon(Icons.home, color: AppTheme.azulMedio),
            title: Text(
              'Inicio',
              style: TextStyle(
                fontWeight:
                    puedeVolver ? FontWeight.normal : FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
          const Divider(height: 1),

          // Comisión Directiva — solo logueados
          if (auth.isLoggedIn)
            ListTile(
              leading: const Icon(Icons.groups, color: AppTheme.azulMedio),
              title: const Text('Comisión Directiva'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ComisionDirectivaScreen()),
                );
              },
            ),

          // Secciones públicas configurables
          if (secciones['proyectos'] == true)
            ListTile(
              leading: const Icon(Icons.folder_special_outlined,
                  color: AppTheme.azulMedio),
              title: const Text('Proyectos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProyectosScreen()),
                );
              },
            ),
          if (secciones['ingresos'] == true)
            ListTile(
              leading:
                  const Icon(Icons.swap_vert, color: AppTheme.azulMedio),
              title: const Text('Movimientos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MovimientosScreen()),
                );
              },
            ),
          if (secciones['cuentaBancaria'] == true)
            ListTile(
              leading: const Icon(Icons.account_balance,
                  color: AppTheme.azulMedio),
              title: const Text('Cuenta Bancaria'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CuentaBancariaScreen()),
                );
              },
            ),
          if (secciones['inventario'] == true)
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined,
                  color: AppTheme.azulMedio),
              title: const Text('Inventario'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventarioScreen()),
                );
              },
            ),

          const Divider(),

          // Opciones de usuario
          if (auth.isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.person_outline,
                  color: AppTheme.azulMedio),
              title: const Text('Mi perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PerfilScreen()),
                );
              },
            ),
            if (auth.esAdmin || auth.esAuditor)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings,
                    color: AppTheme.azulMedio),
                title: const Text('Panel de administración'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminPanelScreen()),
                  );
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.logout, color: AppTheme.rojoGasto),
              title: const Text('Cerrar sesión',
                  style: TextStyle(color: AppTheme.rojoGasto)),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthProvider>().logout();
              },
            ),
          ] else ...[
            ListTile(
              leading:
                  const Icon(Icons.login, color: AppTheme.azulMedio),
              title: const Text('Ingresar'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
