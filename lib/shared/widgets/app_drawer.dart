import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/admin/presentation/providers/configuracion_provider.dart';
import '../../features/admin/presentation/screens/admin_panel_screen.dart';
import '../../features/admin/presentation/screens/invitaciones_screen.dart';
import '../../features/admin/presentation/screens/log_cambios_screen.dart';
import '../../features/admin/presentation/screens/usuarios_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/perfil_screen.dart';
import '../../features/comision/presentation/screens/comision_directiva_screen.dart';
import '../../features/cuenta_bancaria/presentation/screens/cuenta_bancaria_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/informes/presentation/screens/informes_screen.dart';
import '../../features/ingresos/presentation/screens/agregar_movimiento_screen.dart';
import '../../features/ingresos/presentation/screens/movimientos_screen.dart';
import '../../features/inventario/presentation/screens/inventario_screen.dart';
import '../../features/proyectos/presentation/screens/proyectos_screen.dart';
import '../../features/socios/presentation/screens/socios_screen.dart';

class AppDrawer extends StatelessWidget {
  final bool esInicio;
  const AppDrawer({super.key, this.esInicio = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final config = context.watch<ConfiguracionProvider>();
    final secciones = config.seccionesPublicas;
    final puedeVolver = !esInicio;

    Widget itemMenu(IconData icono, String titulo, Widget Function() pantalla) {
      return ListTile(
        leading: Icon(icono, color: AppTheme.azulMedio),
        title: Text(titulo),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => pantalla()));
        },
      );
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
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
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                ],
              ),
            ),
          ),

          // ── Volver ──────────────────────────────────────────────────────────
          if (puedeVolver) ...[
            ListTile(
              leading: const Icon(Icons.arrow_back,
                  color: AppTheme.textoSecundario),
              title: const Text('Volver',
                  style: TextStyle(color: AppTheme.textoSecundario)),
              tileColor: AppTheme.textoSecundario.withValues(alpha: 0.08),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
          ],

          // ── Inicio ──────────────────────────────────────────────────────────
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

          // ── Secciones públicas ───────────────────────────────────────────────
          if (secciones['proyectos'] == true)
            itemMenu(Icons.folder_special_outlined, 'Proyectos',
                () => const ProyectosScreen()),
          if (secciones['ingresos'] == true)
            itemMenu(Icons.swap_vert, 'Movimientos',
                () => const MovimientosScreen()),
          if (secciones['cuentaBancaria'] == true)
            itemMenu(Icons.account_balance, 'Cuenta Bancaria',
                () => const CuentaBancariaScreen()),
          if (secciones['inventario'] == true)
            itemMenu(Icons.inventory_2_outlined, 'Inventario',
                () => const InventarioScreen()),

          // ── Para logueados ───────────────────────────────────────────────────
          if (auth.isLoggedIn) ...[
            const Divider(height: 1),
            itemMenu(Icons.groups, 'Comisión Directiva',
                () => const ComisionDirectivaScreen()),
            itemMenu(Icons.assessment_outlined, 'Informes',
                () => const InformesScreen()),

            // GESTIÓN — Editor y Admin
            if (auth.esEditor || auth.esAdmin) ...[
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                child: Text(
                  'GESTIÓN',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textoSecundario,
                      letterSpacing: 1.2),
                ),
              ),
              itemMenu(Icons.people, 'Socios', () => const SociosScreen()),
              itemMenu(Icons.mail_outline, 'Invitaciones',
                  () => const InvitacionesScreen()),
              itemMenu(Icons.add_circle_outline, 'Nuevo ingreso',
                  () => const AgregarMovimientoScreen(tipoInicial: 'ingreso')),
              itemMenu(Icons.remove_circle_outline, 'Nuevo gasto',
                  () => const AgregarMovimientoScreen(tipoInicial: 'gasto')),
              itemMenu(Icons.savings_outlined, 'Caja Chica',
                  () => const CuentaBancariaScreen()),
            ],

            // ADMINISTRACIÓN — solo Admin
            if (auth.esAdmin) ...[
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                child: Text(
                  'ADMINISTRACIÓN',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textoSecundario,
                      letterSpacing: 1.2),
                ),
              ),
              itemMenu(Icons.admin_panel_settings, 'Panel de administración',
                  () => const AdminPanelScreen()),
              itemMenu(Icons.manage_accounts, 'Usuarios',
                  () => const UsuariosScreen()),
            ],

            // AUDITORÍA — Auditor y Admin
            if (auth.esAuditor || auth.esAdmin) ...[
              const Divider(height: 1),
              itemMenu(Icons.history, 'Log de cambios',
                  () => const LogCambiosScreen()),
            ],

            const Divider(height: 1),
            itemMenu(Icons.person_outline, 'Mi perfil',
                () => const PerfilScreen()),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.rojoGasto),
              title: const Text('Cerrar sesión',
                  style: TextStyle(color: AppTheme.rojoGasto)),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthProvider>().logout();
              },
            ),
          ] else ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.login, color: AppTheme.azulMedio),
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
