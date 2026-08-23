import 'package:flutter/material.dart';

import '../dominio/modelos.dart';

class Tema {
  static const azul = Color(0xFF0B6FA4);
  static const azulOscuro = Color(0xFF063D5C);
  static const cian = Color(0xFF16A9C7);

  static const verde = Color(0xFF1E8E5A);
  static const ambar = Color(0xFFD98A0B);
  static const rojo = Color(0xFFC0392B);

  static Color color(Clasificacion c) => switch (c) {
        Clasificacion.apto => verde,
        Clasificacion.riesgo => ambar,
        Clasificacion.incumplimiento => rojo,
      };

  static Color fondo(Clasificacion c) => color(c).withValues(alpha: 0.12);

  static IconData icono(Clasificacion c) => switch (c) {
        Clasificacion.apto => Icons.verified_rounded,
        Clasificacion.riesgo => Icons.warning_amber_rounded,
        Clasificacion.incumplimiento => Icons.dangerous_rounded,
      };

  static ThemeData claro() {
    final base = ColorScheme.fromSeed(
      seedColor: azul,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: const Color(0xFFF4F7F9),
      appBarTheme: const AppBarTheme(
        backgroundColor: azulOscuro,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        side: BorderSide.none,
      ),
    );
  }
}
