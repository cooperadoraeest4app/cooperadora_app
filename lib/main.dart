import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/presentation/providers/categoria_provider.dart';
import 'features/cuenta_bancaria/presentation/providers/cuenta_bancaria_provider.dart';
import 'features/admin/presentation/providers/configuracion_provider.dart';
import 'features/admin/presentation/providers/invitacion_provider.dart';
import 'features/admin/presentation/providers/metodo_pago_provider.dart';
import 'features/admin/presentation/providers/usuarios_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/ingresos/presentation/providers/movimientos_provider.dart';
import 'features/proyectos/presentation/providers/proyecto_provider.dart';
import 'features/home/presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        ChangeNotifierProvider(create: (_) => UsuariosProvider()),
        ChangeNotifierProvider(create: (_) => CategoriaProvider()),
        ChangeNotifierProvider(create: (_) => MetodoPagoProvider()),
        ChangeNotifierProvider(create: (_) => CuentaBancariaProvider()),
        ChangeNotifierProvider(create: (_) => ProyectoProvider()),
      ],
      child: MaterialApp(
        title: 'Cooperadora App',
        theme: AppTheme.lightTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}