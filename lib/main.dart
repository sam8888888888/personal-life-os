import 'package:flutter/services.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_router.dart';
import 'core/notifikasi/kerja_latar.dart';
import 'core/notifikasi/layanan_notifikasi_lokal.dart';
import 'core/notifikasi/pemantau_pengingat.dart';
import 'core/theme/app_tema.dart';
import 'features/pengaturan/mata_uang_pengaturan.dart';
import 'features/pengaturan/mode_tema_pengaturan.dart';
import 'features/pengaturan/penjaga_cadangan_otomatis.dart';
import 'data/repository/demo_seeder.dart';

/// A2: kanal aksi cepat dari ikon aplikasi (shortcut Android).
const MethodChannel _kanalRute = MethodChannel('lifeos/rute');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FR-67 — dua locale: Indonesia (bawaan) & Malaysia (saat mata uang Ringgit).
  await initializeDateFormatting('id_ID');
  await initializeDateFormatting('ms_MY');
  await seedDemoJikaDiminta(); // hanya aktif bila dibangun dengan --dart-define=DEMO_SEED=true
  // F3: siapkan notifikasi + pekerja latar (tidak memblokir tampilan).
  unawaited(siapkanPengingatSaatMulai());
  // A2: bila aplikasi dibuka dari aksi cepat saat sudah berjalan.
  _kanalRute.setMethodCallHandler((panggilan) async {
    if (panggilan.method == 'ruteBaru' && panggilan.arguments is String) {
      appRouter.go(panggilan.arguments as String);
    }
    return null;
  });
  runApp(const ProviderScope(
      child: PenjagaCadanganOtomatis(
          child: PemantauPengingat(
              child: MuatMataUang(
                  child: MuatModeTema(child: PersonalLifeOsApp()))))));
  // A2: bila aplikasi dibuka dari aksi cepat dari kondisi tertutup.
  try {
    final rute = await _kanalRute.invokeMethod<String>('ruteAwal');
    if (rute != null && rute.isNotEmpty) appRouter.go(rute);
  } catch (e) {
    debugPrint('ruteAwal gagal: $e');
  }
}

/// Siapkan layanan notifikasi & daftarkan pekerja latar Workmanager.
Future<void> siapkanPengingatSaatMulai() async {
  try {
    await initializeDateFormatting('id_ID');
    await initializeDateFormatting('ms_MY');
    await LayananNotifikasiLokal().siapkan();
    // FR-63 & FR-87: daftarkan pengingat ibadah di isolate utama.
    daftarkanSumberPengingatUtama();
    await daftarkanKerjaLatar();
  } catch (e) {
    debugPrint('siapkanPengingatSaatMulai gagal: $e');
  }
}

class PersonalLifeOsApp extends ConsumerWidget {
  const PersonalLifeOsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FR-21 — terang / gelap / ikut sistem. Ukuran teks tetap mengikuti
    // pengaturan sistem perangkat.
    final modeTema = ref.watch(modeTemaProvider).value ?? ModeTema.sistem;
    return MaterialApp.router(
      title: 'Personal Life OS',
      debugShowCheckedModeBanner: false,
      theme: AppTema.terang(),
      darkTheme: AppTema.gelap(),
      themeMode: modeTema.mode,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
    );
  }
}
