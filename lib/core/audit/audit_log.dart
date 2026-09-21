/// FR-138 — Audit log lokal: satu pintu untuk mencatat perubahan penting.
///
/// Prinsip berkas ini:
/// 1. **Lokal, tanpa telemetri.** Catatan hanya ditulis ke tabel `audit_log`
///    di perangkat pengguna. Tidak ada pengiriman ke mana pun.
/// 2. **Apa adanya.** [ringkas] adalah kalimat siap tampil yang menyebut
///    kejadian (mis. "Tagihan #18 ditandai lunas"), bukan penilaian atas
///    kebiasaan pengguna (PRD §III-11).
/// 3. **Waktu dari satu sumber.** Waktu baris memakai [waktuSekarang], jadi
///    perilakunya bisa diuji dan tidak bergantung `DateTime.now()` langsung.
/// 4. **Tidak menghambat aksi pengguna.** Bila pencatatan bermasalah, aksi
///    utama tetap berjalan — pakai [catatAuditAman] pada jalur layar.
library;

import 'package:drift/drift.dart';

import '../../data/database/database.dart';
import '../utils/waktu.dart';

/// Nama modul yang dipakai lintas fitur.
///
/// Nilainya sengaja berupa teks pendek supaya bisa disaring di layar dan
/// dicari di berkas ekspor tanpa peta tambahan.
abstract final class ModulAudit {
  static const String tagihan = 'tagihan';
  static const String transaksi = 'transaksi';
  static const String langganan = 'langganan';
  static const String aset = 'aset';
  static const String kewajiban = 'kewajiban';
  static const String anggaran = 'anggaran';
  static const String kategori = 'kategori';
  static const String tugas = 'tugas';
  static const String kebiasaan = 'kebiasaan';
  static const String kesehatan = 'kesehatan';
  static const String ibadah = 'ibadah';
  static const String pengetahuan = 'pengetahuan';
  static const String dokumen = 'dokumen';
  static const String pengaturan = 'pengaturan';
  static const String notifikasi = 'notifikasi';
  static const String lain = 'lain';

  /// Seluruh modul yang dikenal (dipakai untuk menyusun saringan di layar).
  static const List<String> semua = [
    tagihan,
    transaksi,
    langganan,
    aset,
    kewajiban,
    anggaran,
    kategori,
    tugas,
    kebiasaan,
    kesehatan,
    ibadah,
    pengetahuan,
    dokumen,
    pengaturan,
    notifikasi,
    lain,
  ];
}

/// Nama aksi yang dipakai lintas fitur.
abstract final class AksiAudit {
  static const String buat = 'buat';
  static const String ubah = 'ubah';
  static const String hapus = 'hapus';
  static const String tandai = 'tandai';
  static const String tunda = 'tunda';
  static const String pulihkan = 'pulihkan';
  static const String ekspor = 'ekspor';
  static const String impor = 'impor';
  static const String bersihkan = 'bersihkan';
}

/// Sumber catatan: dari mana baris ini ditulis.
abstract final class SumberAudit {
  static const String layar = 'layar';
  static const String pengingat = 'pengingat';
  static const String kerjaLatar = 'kerja_latar';
  static const String impor = 'impor';
}

/// Tulis satu baris ke tabel `audit_log`. Mengembalikan id baris baru.
///
/// [sebelum]/[sesudah] berupa teks supaya bisa memuat nominal, tanggal, atau
/// status tanpa kolom tambahan. Teks [ringkas] wajib: itulah yang dibaca
/// pengguna di layar Catatan Aktivitas.
Future<int> catatAudit(
  AppDatabase db, {
  required String modul,
  required String aksi,
  String? entitas,
  String? entitasId,
  String? sebelum,
  String? sesudah,
  required String ringkas,
  String sumber = 'layar',
}) {
  return db.into(db.auditLog).insert(AuditLogCompanion.insert(
        waktu: waktuSekarang(),
        modul: modul,
        aksi: aksi,
        entitas: Value(entitas),
        entitasId: Value(entitasId),
        nilaiSebelum: Value(sebelum),
        nilaiSesudah: Value(sesudah),
        ringkas: ringkas,
        sumber: Value(sumber),
      ));
}

/// Sama seperti [catatAudit], tetapi tidak pernah melempar galat.
///
/// Dipakai pada jalur layar: catatan yang tidak tersimpan tidak boleh membuat aksi
/// pengguna (menandai lunas, menunda pengingat) ikut berhenti. Mengembalikan
/// id baris, atau null bila baris tidak tersimpan.
Future<int?> catatAuditAman(
  AppDatabase db, {
  required String modul,
  required String aksi,
  String? entitas,
  String? entitasId,
  String? sebelum,
  String? sesudah,
  required String ringkas,
  String sumber = 'layar',
}) async {
  try {
    return await catatAudit(
      db,
      modul: modul,
      aksi: aksi,
      entitas: entitas,
      entitasId: entitasId,
      sebelum: sebelum,
      sesudah: sesudah,
      ringkas: ringkas,
      sumber: sumber,
    );
  } catch (_) {
    return null;
  }
}

/// Kalimat ringkas untuk perubahan satu nilai — **murni**, tanpa I/O.
///
/// Bentuk: "Nominal diubah 300.000 → 325.000". Bila nilai lama belum ada,
/// memakai "ditetapkan"; bila nilai baru dikosongkan, memakai "dikosongkan".
String ringkasPerubahan({
  required String label,
  String? sebelum,
  String? sesudah,
}) {
  final lama = (sebelum == null || sebelum.trim().isEmpty) ? null : sebelum.trim();
  final baru = (sesudah == null || sesudah.trim().isEmpty) ? null : sesudah.trim();
  if (lama == null && baru == null) return '$label tidak berubah';
  if (lama == null) return '$label ditetapkan: $baru';
  if (baru == null) return '$label dikosongkan (sebelumnya $lama)';
  if (lama == baru) return '$label tidak berubah: $lama';
  return '$label diubah $lama \u2192 $baru';
}
