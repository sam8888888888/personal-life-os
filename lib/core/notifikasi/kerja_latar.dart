/// Pekerja latar Android (Workmanager) — menjaga jadwal pengingat tetap segar
/// walau aplikasi jarang dibuka (FR-13), mis. setelah HP di-reboot.
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/database/database.dart';
import '../../data/repository/tagihan_repository.dart';
import 'jejak.dart';
import 'layanan_notifikasi_lokal.dart';
import 'penyinkron_pengingat.dart';

/// Nama unik pekerjaan berkala.
const String tugasSinkronPengingat = 'plo.pengingat.sinkron';

/// Titik masuk pekerja latar (wajib anotasi agar tidak dibuang saat build rilis).
@pragma('vm:entry-point')
void pengirimPengingatLatar() {
  Workmanager().executeTask((tugas, data) async {
    DartPluginRegistrant.ensureInitialized();
    // Isolate latar tidak menjalankan main(): siapkan format tanggal sendiri.
    await initializeDateFormatting('id_ID');
    final layanan = LayananNotifikasiLokal();
    AppDatabase? db;
    try {
      await layanan.siapkan();
      db = AppDatabase();
      final repo = TagihanRepository(db);
      final hasil =
          await PenyinkronPengingat(repo: repo, layanan: layanan).sinkron();
      debugPrint('kerja latar $tugas: $hasil');
      return hasil.berhasil;
    } catch (e) {
      await catatJejak({'jenis': 'kerja_latar', 'galat': '$e'});
      return false;
    } finally {
      await db?.close();
    }
  });
}

/// Daftarkan pekerjaan berkala setiap 6 jam. Aman dipanggil berulang.
Future<void> daftarkanKerjaLatar() async {
  try {
    await Workmanager().initialize(pengirimPengingatLatar);
    await Workmanager().registerPeriodicTask(
      tugasSinkronPengingat,
      tugasSinkronPengingat,
      frequency: const Duration(hours: 6),
      initialDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  } catch (e) {
    debugPrint('daftarkanKerjaLatar gagal: $e');
  }
}
