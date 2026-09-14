/// Tema aplikasi Personal Life OS — Material 3, warna hijau tenang,
/// kontras cukup untuk pengguna 24–45 tahun (termasuk yang pakai kacamata).
library;

import 'package:flutter/material.dart';

class AppTema {
  static const seed = Color(0xFF2E7D32);

  static ThemeData terang() {
    final skema = ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      colorScheme: skema,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7FBF1),
      appBarTheme: AppBarTheme(
        backgroundColor: skema.surface,
        foregroundColor: skema.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: skema.outlineVariant),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 6),
      fontFamilyFallback: const ['Roboto', 'Segoe UI', 'Arial'],
    );
  }
}
