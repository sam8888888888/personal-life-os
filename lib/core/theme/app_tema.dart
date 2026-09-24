/// Tema aplikasi Personal Life OS — arah "Editorial Modern".
///
/// Prinsip (disetujui Papi 24 Sep 2026):
/// - Latar seperti kertas hangat pada tema terang; arang lembut pada tema gelap
///   (bukan hitam pekat) supaya nyaman dipakai malam.
/// - Satu warna aksen tenang (hijau sage) untuk tindakan & progres. Amber hanya
///   untuk hal yang perlu perhatian, merah hanya untuk hal mendesak.
/// - Ruang lega, sudut membulat secukupnya, bayangan tipis. Tanpa gradasi,
///   tanpa efek kaca.
/// - Kontras dijaga untuk pembaca 24–45 tahun (termasuk yang memakai kacamata).
///
/// Kelas & nama method tetap (`AppTema.terang()` / `AppTema.gelap()`) supaya
/// seluruh aplikasi ikut berubah tampilan tanpa menyentuh pemanggilnya.
library;

import 'package:flutter/material.dart';

class AppTema {
  /// Warna benih — hijau sage. Dipakai juga oleh layar yang mencari warna aksen.
  static const seed = Color(0xFF4F7361);

  // ---- Token tema terang -------------------------------------------------
  static const kertas = Color(0xFFF5F3EE); // latar halaman
  static const permukaan = Color(0xFFFFFEFA); // kartu
  static const permukaanLembut = Color(0xFFF0EFE9); // kartu sekunder / kolom isi
  static const tinta = Color(0xFF1F2421); // teks utama
  static const tintaRedup = Color(0xFF6E7A72); // teks pendukung
  static const garis = Color(0xFFE4E7E0);
  static const sageTerang = Color(0xFFE7EFE8); // latar kartu utama terang

  // ---- Token tema gelap --------------------------------------------------
  static const kertasGelap = Color(0xFF141815);
  static const permukaanGelap = Color(0xFF1C211D);
  static const permukaanLembutGelap = Color(0xFF232923);
  static const tintaGelap = Color(0xFFF1F2EC);
  static const tintaRedupGelap = Color(0xFFA6B0A8);
  static const garisGelap = Color(0xFF333B35);
  static const sageGelap = Color(0xFFA9C9B1);

  // ---- Warna semantik (arti tetap, bukan sekadar hiasan) -----------------
  static const positif = Color(0xFF3F6B55);
  static const perhatian = Color(0xFFA9762F);
  static const urgensi = Color(0xFFA64B45);
  static const positifGelap = Color(0xFFAFD3B8);
  static const perhatianGelap = Color(0xFFE0BC86);
  static const urgensiGelap = Color(0xFFE0938C);

  static ColorScheme _skemaTerang() {
    final dasar = ColorScheme.fromSeed(seedColor: seed);
    return dasar.copyWith(
      primary: seed,
      onPrimary: Colors.white,
      primaryContainer: sageTerang,
      onPrimaryContainer: const Color(0xFF1B3627),
      secondary: const Color(0xFF5E6F62),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE9EDE6),
      onSecondaryContainer: const Color(0xFF232A24),
      error: urgensi,
      onError: Colors.white,
      surface: permukaan,
      onSurface: tinta,
      onSurfaceVariant: tintaRedup,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: permukaanLembut,
      surfaceContainer: permukaanLembut,
      surfaceContainerHigh: const Color(0xFFEBEAE3),
      surfaceContainerHighest: const Color(0xFFE6E5DE),
      outline: const Color(0xFF9AA39B),
      outlineVariant: garis,
      inverseSurface: tinta,
      onInverseSurface: permukaan,
    );
  }

  static ColorScheme _skemaGelap() {
    final dasar = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return dasar.copyWith(
      primary: sageGelap,
      onPrimary: const Color(0xFF15251B),
      primaryContainer: const Color(0xFF2A3A2E),
      onPrimaryContainer: const Color(0xFFD8EBDC),
      secondary: const Color(0xFFB7C4B9),
      onSecondary: const Color(0xFF1B241D),
      secondaryContainer: const Color(0xFF2A322B),
      onSecondaryContainer: const Color(0xFFDCE5DC),
      error: urgensiGelap,
      onError: const Color(0xFF33110D),
      surface: permukaanGelap,
      onSurface: tintaGelap,
      onSurfaceVariant: tintaRedupGelap,
      surfaceContainerLowest: const Color(0xFF111512),
      surfaceContainerLow: permukaanLembutGelap,
      surfaceContainer: permukaanLembutGelap,
      surfaceContainerHigh: const Color(0xFF2A3129),
      surfaceContainerHighest: const Color(0xFF303830),
      outline: const Color(0xFF6E7A70),
      outlineVariant: garisGelap,
      inverseSurface: tintaGelap,
      onInverseSurface: kertasGelap,
    );
  }

  /// Skala huruf: hierarki lebih tegas, teks pendukung lebih tenang.
  static TextTheme _teks(TextTheme dasar, Color tinta, Color redup) {
    return dasar.copyWith(
      headlineLarge: dasar.headlineLarge?.copyWith(
          fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.6, color: tinta),
      headlineMedium: dasar.headlineMedium?.copyWith(
          fontSize: 27, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: tinta),
      headlineSmall: dasar.headlineSmall?.copyWith(
          fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: tinta),
      titleLarge: dasar.titleLarge?.copyWith(
          fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: tinta),
      titleMedium: dasar.titleMedium
          ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: tinta),
      titleSmall: dasar.titleSmall
          ?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: tinta),
      bodyLarge: dasar.bodyLarge?.copyWith(fontSize: 15, height: 1.45, color: tinta),
      bodyMedium: dasar.bodyMedium?.copyWith(fontSize: 13.5, height: 1.45, color: tinta),
      bodySmall: dasar.bodySmall?.copyWith(fontSize: 12, height: 1.4, color: redup),
      labelLarge: dasar.labelLarge
          ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      labelMedium: dasar.labelMedium
          ?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: redup),
      labelSmall: dasar.labelSmall?.copyWith(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: redup),
    );
  }

  static ThemeData terang() => _tema(
        skema: _skemaTerang(),
        latar: kertas,
        tinta: tinta,
        redup: tintaRedup,
      );

  static ThemeData gelap() => _tema(
        skema: _skemaGelap(),
        latar: kertasGelap,
        tinta: tintaGelap,
        redup: tintaRedupGelap,
      );

  static ThemeData _tema({
    required ColorScheme skema,
    required Color latar,
    required Color tinta,
    required Color redup,
  }) {
    final dasar = ThemeData(colorScheme: skema, useMaterial3: true);
    final radiusKartu = BorderRadius.circular(18);
    const radiusKendali = BorderRadius.all(Radius.circular(12));

    return dasar.copyWith(
      scaffoldBackgroundColor: latar,
      canvasColor: latar,
      textTheme: _teks(dasar.textTheme, tinta, redup),
      appBarTheme: AppBarTheme(
        backgroundColor: latar,
        foregroundColor: tinta,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: tinta,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: skema.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radiusKartu,
          side: BorderSide(color: skema.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: skema.outlineVariant,
        thickness: 1,
        space: 20,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: skema.surfaceContainerLow,
        border: const OutlineInputBorder(
          borderRadius: radiusKendali,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusKendali,
          borderSide: BorderSide(color: skema.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusKendali,
          borderSide: BorderSide(color: skema.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // ponytail: lebar minimum 0, TINGGI saja yang dipatok. `Size.fromHeight`
          // berarti lebar tak terhingga dan membuat tombol di dalam Row meledak.
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(borderRadius: radiusKendali),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(borderRadius: radiusKendali),
          side: BorderSide(color: skema.outlineVariant),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: radiusKendali),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: skema.surface,
        side: BorderSide(color: skema.outlineVariant),
        shape: const RoundedRectangleBorder(borderRadius: radiusKendali),
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tinta),
        secondaryLabelStyle: TextStyle(color: skema.onSurfaceVariant),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 6,
        iconColor: skema.onSurfaceVariant,
        titleTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tinta),
        subtitleTextStyle: TextStyle(fontSize: 12, color: redup),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: skema.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: skema.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 22,
            color: s.contains(WidgetState.selected)
                ? skema.primary
                : skema.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? skema.primary
                : skema.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: skema.primary,
        foregroundColor: skema.onPrimary,
        elevation: 2,
        extendedTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: skema.primary,
        linearTrackColor: skema.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: skema.inverseSurface,
        contentTextStyle: TextStyle(color: skema.onInverseSurface, fontSize: 13),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: skema.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: skema.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: skema.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: radiusKendali),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: skema.outlineVariant)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: skema.primary,
        unselectedLabelColor: skema.onSurfaceVariant,
        indicatorColor: skema.primary,
        dividerColor: skema.outlineVariant,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
