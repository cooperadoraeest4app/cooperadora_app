import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/providers/cargo_provider.dart';
import 'features/admin/presentation/providers/categoria_provider.dart';
import 'features/admin/presentation/providers/curso_provider.dart';
import 'features/cuenta_bancaria/presentation/providers/cuenta_bancaria_provider.dart';
import 'features/admin/presentation/providers/configuracion_provider.dart';
import 'features/admin/presentation/providers/invitacion_provider.dart';
import 'features/admin/presentation/providers/metodo_pago_provider.dart';
import 'features/admin/presentation/providers/persona_provider.dart';
import 'features/admin/presentation/providers/usuarios_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/ingresos/presentation/providers/frecuencia_provider.dart';
import 'features/ingresos/presentation/providers/movimientos_provider.dart';
import 'features/proyectos/presentation/providers/proyecto_provider.dart';
import 'features/admin/presentation/providers/rubro_provider.dart';
import 'features/informes/presentation/providers/informes_provider.dart';
import 'features/inventario/presentation/providers/inventario_provider.dart';
import 'features/socios/presentation/providers/cuota_provider.dart';
import 'features/socios/presentation/providers/socio_provider.dart';
import 'core/navigation/app_navigator.dart';
import 'features/home/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MovimientosProvider()),
        ChangeNotifierProvider(create: (_) => ConfiguracionProvider()),
        ChangeNotifierProvider(create: (_) => InvitacionProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UsuariosProvider>(
          create: (_) => UsuariosProvider(),
          update: (_, auth, usuarios) {
            if (auth.currentUser != null) {
              usuarios!.iniciarSiNecesario();
            } else {
              usuarios!.limpiar();
            }
            return usuarios;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, PersonaProvider>(
          create: (_) => PersonaProvider(),
          update: (_, auth, personas) {
            if (auth.currentUser != null) {
              personas!.iniciarSiNecesario();
            } else {
              personas!.limpiar();
            }
            return personas;
          },
        ),
        ChangeNotifierProvider(create: (_) => CargoProvider()),
        ChangeNotifierProvider(create: (_) => CategoriaProvider()),
        ChangeNotifierProvider(create: (_) => CursoProvider()),
        ChangeNotifierProvider(create: (_) => MetodoPagoProvider()),
        ChangeNotifierProvider(create: (_) => CuentaBancariaProvider()),
        ChangeNotifierProvider(create: (_) => ProyectoProvider()),
        ChangeNotifierProvider(create: (_) => SocioProvider()),
        ChangeNotifierProvider(create: (_) => CuotaProvider()),
        ChangeNotifierProvider(create: (_) => FrecuenciaProvider()),
        ChangeNotifierProvider(create: (_) => InventarioProvider()),
        ChangeNotifierProvider(create: (_) => RubroProvider()),
        ChangeNotifierProvider(create: (_) => InformesProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Cooperadora App',
        theme: AppTheme.lightTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}