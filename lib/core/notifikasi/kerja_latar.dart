/// Pekerja latar Android (Workmanager) — menjaga jadwal pengingat tetap segar
/// walau aplikasi jarang dibuka (FR-13), mis. setelah HP di-reboot.
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:workmanager/workmanager.dart';

import '../../data/database/database.dart';
import '../../data/repository/tagihan_repository.dart';
import '../../features/dokumen/pengingat_dokumen.dart';
import '../../features/ibadah/sumber_pengingat_ibadah.dart';
import '../../features/kesehatan/pengingat_janji.dart';
import '../../features/rumah/pengingat_perawatan.dart';
import '../../features/kesehatan/pengingat_obat_habis.dart';
import 'jejak.dart';
import 'layanan_notifikasi_lokal.dart';
import 'penyinkron_pengingat.dart';
import 'sumber_pengingat_tambahan.dart';
import '../../features/ritme/pengingat_tinjauan_pekan.dart';
import '../../features/perjalanan/pengingat_perjalanan.dart';

/// Nama unik pekerjaan berkala.
const String tugasSinkronPengingat = 'plo.pengingat.sinkron';

/// Titik pendaftaran sumber pengingat **untuk pekerja latar** (FR-63/FR-87).
///
/// Isolate latar tidak mewarisi variabel statis apa pun dari isolate utama,
/// jadi modul fitur yang ingin pengingatnya ikut disegarkan di latar mendaftar
/// di sini — satu baris per modul, mis.:
///
/// ```dart
/// RegistriSumberPengingat.daftarkan(SumberPengingatIbadah());
/// ```
///
/// Tanpa pendaftaran di sini, pengingat tambahan tetap berbunyi untuk jadwal
/// yang sudah terpasang, tetapi tidak diperpanjang oleh pekerja latar.
void daftarkanSumberPengingatLatar() {
  // FR-63 & FR-87: pengingat ibadah (ringkasan pagi + waktu sholat).
  RegistriSumberPengingat.daftarkan(SumberPengingatIbadah());
  // FR-129: pengingat masa berlaku dokumen.
  daftarkanSumberPengingatDokumen();
  // FR-107 & FR-109: sisa obat (H-5/H-1) & janji dokter (7 hari/1 hari/2 jam).
  RegistriSumberPengingat.daftarkan(SumberPengingatObat());
  RegistriSumberPengingat.daftarkan(SumberPengingatJanji());
  // FR-125: jadwal perawatan aset (servis berkala, ganti oli, dsb).
  RegistriSumberPengingat.daftarkan(SumberPengingatPerawatan());
  // FR-144: tinjauan pekan (Minggu malam, dilewati bila sudah diisi).
  RegistriSumberPengingat.daftarkan(SumberPengingatTinjauanPekan());
  // FR-134: pengingat keberangkatan perjalanan (H-7/H-1/H-0).
  daftarkanSumberPengingatPerjalanan();
}

/// Titik pendaftaran sumber pengingat **untuk isolate utama** (aplikasi).
///
/// Dipanggil sekali saat aplikasi mulai. Wajib terpisah dari versi latar:
/// isolate latar tidak mewarisi variabel statis isolate utama, jadi keduanya
/// harus mendaftar sendiri-sendiri.
void daftarkanSumberPengingatUtama() {
  RegistriSumberPengingat.daftarkan(SumberPengingatIbadah());
  // FR-129: pengingat masa berlaku dokumen.
  daftarkanSumberPengingatDokumen();
  // FR-107 & FR-109: sisa obat & janji dokter.
  RegistriSumberPengingat.daftarkan(SumberPengingatObat());
  RegistriSumberPengingat.daftarkan(SumberPengingatJanji());
  // FR-125: jadwal perawatan aset (servis berkala, ganti oli, dsb).
  RegistriSumberPengingat.daftarkan(SumberPengingatPerawatan());
  // FR-144: tinjauan pekan (Minggu malam, dilewati bila sudah diisi).
  RegistriSumberPengingat.daftarkan(SumberPengingatTinjauanPekan());
  // FR-134: pengingat keberangkatan perjalanan (H-7/H-1/H-0).
  daftarkanSumberPengingatPerjalanan();
}

/// Titik masuk pekerja latar (wajib anotasi agar tidak dibuang saat build rilis).
@pragma('vm:entry-point')
void pengirimPengingatLatar() {
  Workmanager().executeTask((tugas, data) async {
    DartPluginRegistrant.ensureInitialized();
    // Isolate latar tidak menjalankan main(): siapkan format tanggal sendiri.
    await initializeDateFormatting('id_ID');
    daftarkanSumberPengingatLatar();
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
