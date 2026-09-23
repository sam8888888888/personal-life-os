/// FR-138 — Repositori audit log: baca, saring per modul, ekspor berkas, dan
/// bersihkan catatan lama **atas permintaan pengguna**.
///
/// Catatan kejujuran data (PRD §III-11):
/// * Catatan ini hidup di perangkat pengguna. Tidak ada pengiriman otomatis.
/// * Pembersihan TIDAK pernah berjalan sendiri — hanya lewat [bersihkan] yang
///   dipanggil dari tombol di layar, dengan lama simpan yang disebut apa adanya.
/// * Ekspor menulis berkas di folder dokumen aplikasi, dan berkas itu berisi
///   seluruh kolom baris yang diekspor (tanpa penyuntingan).
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/audit/audit_log.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Batas jumlah baris sekali ekspor.
///
/// Bila jumlah baris melebihi batas ini, berkas tetap dibuat — tetapi diberi
/// tanda `terpotong: true` agar pengguna tahu isinya bukan seluruh catatan.
const int maksBarisEksporAudit = 5000;

/// Lama simpan bawaan catatan aktivitas (hari) — dipakai tombol bersihkan.
const int lamaSimpanAuditHari = 365;

/// Batas waktu satu pembacaan penyimpanan (aturan platform, 5 detik).
const Duration batasBacaAudit = Duration(seconds: 5);

/// Penentu folder berkas ekspor (bisa diganti saat pengujian).
typedef PenentuFolderAudit = Future<Directory> Function();

/// Galat ekspor audit — pesannya sudah siap tampil untuk pengguna.
class GalatEksporAudit implements Exception {
  const GalatEksporAudit(this.pesan);
  final String pesan;

  @override
  String toString() => pesan;
}

/// Hasil satu kali ekspor catatan aktivitas.
class HasilEksporAudit {
  const HasilEksporAudit({
    required this.path,
    required this.namaBerkas,
    required this.dibuatPada,
    required this.format,
    required this.jumlahBaris,
    required this.totalBaris,
  });

  final String path;
  final String namaBerkas;
  final DateTime dibuatPada;

  /// "json" atau "txt".
  final String format;

  /// Jumlah baris yang benar-benar ditulis ke berkas.
  final int jumlahBaris;

  /// Jumlah baris yang cocok dengan saringan (bisa lebih besar dari
  /// [jumlahBaris] bila melewati [maksBarisEksporAudit]).
  final int totalBaris;

  /// True bila berkas tidak memuat seluruh catatan yang cocok saringan.
  bool get terpotong => totalBaris > jumlahBaris;
}

/// Akses data catatan aktivitas (FR-138).
class AuditRepository {
  AuditRepository(this.db, {this.penentuFolder, this.jam});

  final AppDatabase db;

  /// Cara menentukan folder berkas ekspor (null = folder dokumen aplikasi).
  final PenentuFolderAudit? penentuFolder;

  /// Sumber waktu (null = satu sumber waktu aplikasi).
  final DateTime Function()? jam;

  DateTime _sekarang() => (jam ?? waktuSekarang)();

  Future<Directory> _folder() async {
    final Directory d =
        await (penentuFolder ?? getApplicationDocumentsDirectory)();
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  // -------------------------------------------------------------------
  // BACA
  // -------------------------------------------------------------------

  /// Daftar catatan terbaru lebih dulu. [modul] null berarti semua modul.
  ///
  /// Urutan: waktu menurun, lalu id menurun (dua baris pada detik yang sama
  /// tetap punya urutan yang pasti).
  Future<List<AuditLogData>> daftar({String? modul, int batas = 200}) {
    final q = db.select(db.auditLog);
    if (modul != null && modul.isNotEmpty) {
      q.where((t) => t.modul.equals(modul));
    }
    q
      ..orderBy([
        (t) => OrderingTerm.desc(t.waktu),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(batas < 1 ? 1 : batas);
    return q.get().timeout(batasBacaAudit);
  }

  /// Versi aliran (stream) untuk layar — ikut berubah saat ada baris baru.
  Stream<List<AuditLogData>> watchDaftar({String? modul, int batas = 200}) {
    final q = db.select(db.auditLog);
    if (modul != null && modul.isNotEmpty) {
      q.where((t) => t.modul.equals(modul));
    }
    q
      ..orderBy([
        (t) => OrderingTerm.desc(t.waktu),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(batas < 1 ? 1 : batas);
    return q.watch();
  }

  /// Jumlah baris catatan (0 berarti "Belum ada data").
  Future<int> jumlah({String? modul}) {
    final q = db.selectOnly(db.auditLog)..addColumns([db.auditLog.id.count()]);
    if (modul != null && modul.isNotEmpty) {
      q.where(db.auditLog.modul.equals(modul));
    }
    return q
        .map((r) => r.read(db.auditLog.id.count()) ?? 0)
        .getSingle()
        .timeout(batasBacaAudit);
  }

  /// Modul yang benar-benar ada di tabel (untuk menyusun saringan di layar).
  ///
  /// Sengaja dibaca dari data, bukan dari daftar tetap, supaya layar tidak
  /// menampilkan pilihan saringan yang belum pernah dipakai.
  Future<List<String>> daftarModul() async {
    final q = db.selectOnly(db.auditLog, distinct: true)
      ..addColumns([db.auditLog.modul])
      ..orderBy([OrderingTerm.asc(db.auditLog.modul)]);
    final baris = await q.get().timeout(batasBacaAudit);
    return baris
        .map((r) => r.read(db.auditLog.modul))
        .whereType<String>()
        .toList(growable: false);
  }

  // -------------------------------------------------------------------
  // EKSPOR
  // -------------------------------------------------------------------

  static String _dua(int a) => a.toString().padLeft(2, '0');

  /// Nama berkas ekspor: `plo_audit_YYYYMMDD_HHMM.json` / `.txt`.
  static String namaBerkas(DateTime t, {required String format}) =>
      'plo_audit_${t.year}${_dua(t.month)}${_dua(t.day)}'
      '_${_dua(t.hour)}${_dua(t.minute)}.$format';

  /// Ekspor catatan ke berkas JSON di folder dokumen. Mengembalikan lokasi
  /// berkas dan jumlah baris yang benar-benar ditulis (bukti, bukan klaim).
  Future<HasilEksporAudit> eksporJson({String? modul, DateTime? pada}) async {
    final waktu = pada ?? _sekarang();
    final total = await jumlah(modul: modul);
    final baris = await daftar(modul: modul, batas: maksBarisEksporAudit);
    final isi = <String, Object?>{
      'format': 'plo-audit',
      'versiSkema': db.schemaVersion,
      'dibuatPada': waktu.toIso8601String(),
      'catatan':
          'Catatan aktivitas ini tersimpan di perangkat pengguna saja, tidak '
              'dikirim ke mana pun.',
      'saringanModul': modul ?? '',
      'jumlahBaris': baris.length,
      'totalBarisCocokSaringan': total,
      'terpotong': total > baris.length,
      'baris': [
        for (final b in baris)
          {
            'id': b.id,
            'waktu': b.waktu.toIso8601String(),
            'modul': b.modul,
            'aksi': b.aksi,
            'entitas': b.entitas,
            'entitasId': b.entitasId,
            'nilaiSebelum': b.nilaiSebelum,
            'nilaiSesudah': b.nilaiSesudah,
            'ringkas': b.ringkas,
            'sumber': b.sumber,
          },
      ],
    };
    final berkas = await _tulis(
        namaBerkas(waktu, format: 'json'),
        const JsonEncoder.withIndent('  ').convert(isi),
        waktu);
    return HasilEksporAudit(
      path: berkas.path,
      namaBerkas: berkas.nama,
      dibuatPada: waktu,
      format: 'json',
      jumlahBaris: baris.length,
      totalBaris: total,
    );
  }

  /// Ekspor catatan ke berkas teks biasa (satu baris per catatan) — mudah
  /// dibaca tanpa aplikasi lain.
  Future<HasilEksporAudit> eksporTeks({String? modul, DateTime? pada}) async {
    final waktu = pada ?? _sekarang();
    final total = await jumlah(modul: modul);
    final baris = await daftar(modul: modul, batas: maksBarisEksporAudit);
    final b = StringBuffer()
      ..writeln('Catatan aktivitas Personal Life OS')
      ..writeln('Dibuat: ${fmtTanggalAman(waktu)} ${fmtJam(waktu)}')
      ..writeln('Saringan modul: ${modul == null || modul.isEmpty ? 'semua' : modul}')
      ..writeln('Jumlah baris di berkas ini: ${baris.length}')
      ..writeln('Jumlah baris cocok saringan: $total')
      ..writeln(baris.length < total
          ? 'Catatan: berkas ini dibatasi $maksBarisEksporAudit baris terbaru.'
          : 'Catatan: seluruh baris cocok saringan ikut ke berkas ini.')
      ..writeln(
          'Catatan ini tersimpan di perangkat Anda saja, tidak dikirim ke mana pun.')
      ..writeln('-' * 72);
    for (final x in baris) {
      b.writeln(barisTeks(x));
    }
    final berkas = await _tulis(
        namaBerkas(waktu, format: 'txt'), b.toString(), waktu);
    return HasilEksporAudit(
      path: berkas.path,
      namaBerkas: berkas.nama,
      dibuatPada: waktu,
      format: 'txt',
      jumlahBaris: baris.length,
      totalBaris: total,
    );
  }

  /// Satu baris teks: "15 September 2026 22:31 · tagihan · tandai · ringkas".
  static String barisTeks(AuditLogData b) => [
        '${fmtTanggalAman(b.waktu)} ${fmtJam(b.waktu)}',
        b.modul,
        b.aksi,
        if (b.entitas != null && b.entitas!.isNotEmpty) b.entitas!,
        b.ringkas,
      ].join(' \u00b7 ');

  Future<BerkasEksporAudit> _tulis(String nama, String isi, DateTime waktu) async {
    try {
      final folder = await _folder();
      final f = File('${folder.path}${Platform.pathSeparator}$nama');
      await f.writeAsString(isi);
      return BerkasEksporAudit(path: f.path, nama: nama);
    } on GalatEksporAudit {
      rethrow;
    } catch (e) {
      throw GalatEksporAudit(
          'Berkas catatan tidak bisa ditulis. Catatan di aplikasi tetap utuh. '
          'Penyebab: $e');
    }
  }

  // -------------------------------------------------------------------
  // PEMBERSIHAN (hanya atas permintaan pengguna)
  // -------------------------------------------------------------------

  /// Hapus catatan yang lebih tua dari [simpanHari] hari.
  ///
  /// Mengembalikan jumlah baris yang benar-benar terhapus. Fungsi ini TIDAK
  /// dipanggil otomatis oleh aplikasi mana pun — hanya dari tombol di layar.
  Future<int> bersihkan({int simpanHari = lamaSimpanAuditHari, DateTime? pada}) {
    final waktu = pada ?? _sekarang();
    final batas = waktu.subtract(Duration(days: simpanHari < 1 ? 1 : simpanHari));
    return (db.delete(db.auditLog)..where((t) => t.waktu.isSmallerThanValue(batas)))
        .go()
        .timeout(batasBacaAudit);
  }
}

/// Keterangan berkas hasil ekspor (dipakai internal repository).
class BerkasEksporAudit {
  const BerkasEksporAudit({required this.path, required this.nama});
  final String path;
  final String nama;
}

/// Modul audit dipakai di layar — diambil ulang dari [ModulAudit] agar layar
/// tidak menulis teks modul sendiri.
List<String> modulAuditDikenal() => ModulAudit.semua;
