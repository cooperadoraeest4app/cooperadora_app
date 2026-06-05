import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // --- Paleta de colores ---
  static const Color azulOscuro = Color(0xFF1A3A5C);
  static const Color azulMedio = Color(0xFF2E6DA4);
  static const Color celesteAccento = Color(0xFF8bcbe6);
  static const Color celesteFondo = Color(0xFFd6eff9);
  static const Color celesteBorde = Color(0xFFb0dff0);
  static const Color verdeTeal = Color(0xFF2E9E7A);
  static const Color verdeIngreso = Color(0xFF27AE60);
  static const Color rojoGasto = Color(0xFFE74C3C);
  static const Color amarilloAlerta = Color(0xFFF39C12);
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color textoPrincipal = Color(0xFF1A1A2E);
  static const Color textoSecundario = Color(0xFF6B7A99);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: azulOscuro,
        secondary: celesteAccento,
        surface: blanco,
        onPrimary: blanco,
        onSecondary: azulOscuro,
        onSurface: textoPrincipal,
      ),
      scaffoldBackgroundColor: celesteFondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: azulOscuro,
        foregroundColor: blanco,
        iconTheme: IconThemeData(color: blanco),
        titleTextStyle: TextStyle(
          color: blanco,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: blanco,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: celesteBorde),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: verdeTeal,
          foregroundColor: blanco,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: azulMedio,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: azulMedio,
          side: BorderSide(color: azulMedio),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: blanco,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: celesteBorde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: celesteBorde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: azulOscuro, width: 2),
        ),
        labelStyle: TextStyle(color: textoSecundario),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textoPrincipal),
        bodyMedium: TextStyle(color: textoPrincipal),
        bodySmall: TextStyle(color: textoSecundario),
        titleLarge: TextStyle(color: textoPrincipal, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textoPrincipal, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: textoSecundario),
      ),
      dividerTheme: const DividerThemeData(
        color: celesteBorde,
        thickness: 1,
      ),
    );
  }
}
