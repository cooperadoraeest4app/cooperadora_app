import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/ingresos/presentation/providers/movimientos_provider.dart';
import 'features/ingresos/presentation/screens/movimientos_screen.dart';

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
        ChangeNotifierProvider(create: (_) => MovimientosProvider()),
      ],
      child: MaterialApp(
        title: 'Cooperadora App',
        theme: AppTheme.lightTheme(),
        home: const MovimientosScreen(),
      ),
    );
  }
}