import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/accion_auth_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cuenta_bancaria/presentation/screens/cuenta_bancaria_screen.dart';
import '../../../inventario/presentation/screens/inventario_screen.dart';
import '../../../socios/presentation/screens/socios_screen.dart';
import 'categorias_screen.dart';
import 'configuracion_screen.dart';
import 'cursos_screen.dart';
import 'invitaciones_screen.dart';
import 'log_cambios_screen.dart';
import 'metodos_pago_screen.dart';
import 'usuarios_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  static const _opcionesAdmin = [
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
    _OpcionPanel(
      icono: Icons.account_balance,
      titulo: 'Cuenta Bancaria',
      subtitulo: 'Saldo y resúmenes bancarios',
      esCuentaBancaria: true,
    ),
    _OpcionPanel(
      icono: Icons.family_restroom,
      titulo: 'Socios',
      subtitulo: 'Padrón y cuotas',
      esSocios: true,
    ),
    _OpcionPanel(
      icono: Icons.school,
      titulo: 'Cursos',
      subtitulo: 'Cursos y niveles de la institución',
      esCursos: true,
    ),
    _OpcionPanel(
      icono: Icons.inventory_2,
      titulo: 'Inventario',
      subtitulo: 'Bienes y equipamiento de la Cooperadora',
      esInventario: true,
    ),
    _OpcionPanel(
      icono: Icons.history,
      titulo: 'Log de cambios',
      subtitulo: 'Auditoría de modificaciones',
      esLogCambios: true,
    ),
  ];

  static const _opcionesAuditor = [
    _OpcionPanel(
      icono: Icons.history,
      titulo: 'Log de cambios',
      subtitulo: 'Auditoría de modificaciones',
      esLogCambios: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (!auth.esAdmin && !auth.esAuditor) {
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
    final auth = context.watch<AuthProvider>();
    final opciones = auth.esAdmin ? _opcionesAdmin : _opcionesAuditor;
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
        actions: const [AccionAuthWidget()],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: opciones.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final opcion = opciones[index];
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
                } else if (opcion.esCuentaBancaria) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CuentaBancariaScreen()),
                  );
                } else if (opcion.esSocios) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SociosScreen()),
                  );
                } else if (opcion.esCursos) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CursosScreen()),
                  );
                } else if (opcion.esInventario) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InventarioScreen()),
                  );
                } else if (opcion.esLogCambios) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LogCambiosScreen()),
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
  final bool esCuentaBancaria;
  final bool esSocios;
  final bool esCursos;
  final bool esInventario;
  final bool esLogCambios;

  const _OpcionPanel({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    this.esConfiguracion = false,
    this.esUsuarios = false,
    this.esInvitaciones = false,
    this.esCategorias = false,
    this.esMetodosPago = false,
    this.esCuentaBancaria = false,
    this.esSocios = false,
    this.esCursos = false,
    this.esInventario = false,
    this.esLogCambios = false,
  });
}
