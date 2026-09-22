/// FR-56 — repositori Sub-Akses Keluarga.
///
/// Tabel: `izin_keluarga` (izin per anggota × modul). Anggota memakai tabel
/// `anggota_keluarga` yang sudah ada — tidak ada tabel orang kedua.
///
/// Penegakan izin ada di sini (lapisan data), bukan hanya menyembunyikan menu:
/// [bolehLihat] / [bolehTambah] bisa dipanggil siapa pun yang menyajikan data.
library;

import 'dart:convert';
import 'dart:math' show Random;

import 'package:drift/drift.dart';

import '../../core/keluarga/sub_akses.dart';
import '../database/database.dart';

/// Versi berkas paket berbagi (agar berkas lama tidak salah baca).
const int versiPaketBerbagi = 1;

class SubAksesRepository {
  SubAksesRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _jam;
  static final _acak = Random();

  String _uid() => 'izn${_jam().microsecondsSinceEpoch.toRadixString(36)}'
      '${_acak.nextInt(1 << 20).toRadixString(36)}';

  /// Anggota keluarga yang bisa diberi akses (dari FR-56/keluarga).
  Future<List<AnggotaKeluargaData>> anggota({bool termasukArsip = false}) {
    final q = db.select(db.anggotaKeluarga);
    if (!termasukArsip) q.where((t) => t.arsip.equals(false));
    q.orderBy([(t) => OrderingTerm.asc(t.nama)]);
    return q.get();
  }

  Future<List<IzinSubAksesKeluargaData>> izin({int? anggotaId}) {
    final q = db.select(db.izinSubAksesKeluarga);
    if (anggotaId != null) q.where((t) => t.anggotaId.equals(anggotaId));
    q.orderBy([(t) => OrderingTerm.asc(t.anggotaId)]);
    return q.get();
  }

  Stream<List<IzinSubAksesKeluargaData>> pantau() {
    return (db.select(db.izinSubAksesKeluarga)
          ..orderBy([(t) => OrderingTerm.asc(t.anggotaId)]))
        .watch();
  }

  /// Simpan/ubah izin satu anggota untuk satu modul.
  Future<void> simpanIzin({
    required int anggotaId,
    required ModulKeluarga modul,
    bool bolehLihat = true,
    bool bolehTambah = false,
    bool aktif = true,
  }) async {
    final ada = await (db.select(db.izinSubAksesKeluarga)
          ..where((t) =>
              t.anggotaId.equals(anggotaId) & t.modul.equals(modul.kode)))
        .getSingleOrNull();
    if (ada == null) {
      await db.into(db.izinSubAksesKeluarga).insert(IzinSubAksesKeluargaCompanion.insert(
            uid: Value(_uid()),
            anggotaId: anggotaId,
            modul: modul.kode,
            bolehLihat: Value(bolehLihat),
            bolehTambah: Value(bolehTambah),
            aktif: Value(aktif),
            diubahPada: Value(_jam()),
          ));
      return;
    }
    await (db.update(db.izinSubAksesKeluarga)..where((t) => t.id.equals(ada.id)))
        .write(IzinSubAksesKeluargaCompanion(
      bolehLihat: Value(bolehLihat),
      bolehTambah: Value(bolehTambah),
      aktif: Value(aktif),
      diubahPada: Value(_jam()),
    ));
  }

  Future<void> hapusIzin({
    required int anggotaId,
    required ModulKeluarga modul,
  }) async {
    await (db.delete(db.izinSubAksesKeluarga)
          ..where((t) =>
              t.anggotaId.equals(anggotaId) & t.modul.equals(modul.kode)))
        .go();
  }

  /// Semua izin dimatikan untuk satu anggota (tombol "cabut akses").
  Future<void> cabutSemua(int anggotaId) async {
    await (db.update(db.izinSubAksesKeluarga)..where((t) => t.anggotaId.equals(anggotaId)))
        .write(IzinSubAksesKeluargaCompanion(
      aktif: const Value(false),
      bolehLihat: const Value(false),
      bolehTambah: const Value(false),
      diubahPada: Value(_jam()),
    ));
  }

  // ── penegakan izin (dipakai lapisan data lain) ───────────────────────────

  Future<bool> bolehLihat(int anggotaId, ModulKeluarga modul) async {
    final nama = await _nama(anggotaId);
    if (nama == null) return false;
    final daftar = await _izinMesin(anggotaId, nama: nama);
    return bolehLihatModul(daftar, anggota: nama, modul: modul);
  }

  Future<bool> bolehTambah(int anggotaId, ModulKeluarga modul) async {
    final nama = await _nama(anggotaId);
    if (nama == null) return false;
    final daftar = await _izinMesin(anggotaId, nama: nama);
    return bolehTambahModul(daftar, anggota: nama, modul: modul);
  }

  Future<String?> _nama(int anggotaId) async {
    final a = await (db.select(db.anggotaKeluarga)
          ..where((t) => t.id.equals(anggotaId)))
        .getSingleOrNull();
    return a?.nama;
  }

  /// Susun daftar izin untuk mesin murni. [nama] wajib diisi supaya
  /// pemeriksaan izin memakai NAMA anggota (bukan id) — kalau tidak, izin
  /// seorang anggota bisa tampak berlaku untuk anggota lain.
  Future<List<IzinKeluarga>> _izinMesin(int? anggotaId, {String? nama}) async {
    final baris = await izin(anggotaId: anggotaId);
    final namaPakai = nama ?? anggotaId?.toString() ?? '';
    final hasil = <IzinKeluarga>[];
    for (final b in baris) {
      final modul = ModulKeluarga.dariKode(b.modul);
      if (modul == null) continue;
      hasil.add(IzinKeluarga(
        anggota: namaPakai,
        modul: modul,
        bolehLihat: b.bolehLihat,
        bolehTambah: b.bolehTambah,
        aktif: b.aktif,
      ));
    }
    return hasil;
  }

  /// Ringkasan untuk layar (nama asli, bukan id).
  Future<RingkasSubAkses> ringkas() async {
    final daftarAnggota = await anggota();
    final semuaIzin = <IzinKeluarga>[];
    for (final a in daftarAnggota) {
      for (final b in await izin(anggotaId: a.id)) {
        final modul = ModulKeluarga.dariKode(b.modul);
        if (modul == null) continue;
        semuaIzin.add(IzinKeluarga(
          anggota: a.nama,
          modul: modul,
          bolehLihat: b.bolehLihat,
          bolehTambah: b.bolehTambah,
          aktif: b.aktif,
        ));
      }
    }
    return ringkasSubAkses(
      semuaIzin,
      anggotaTerdaftar: [for (final a in daftarAnggota) a.nama],
    );
  }

  // ── paket berbagi (berkas yang dikirim pengguna sendiri) ────────────────

  /// Susun paket berbagi berisi IZIN + JUMLAH baris per modul.
  ///
  /// Sengaja HANYA berisi ringkasan angka, bukan isi catatan pribadi: supaya
  /// berkas ini tidak membocorkan data keuangan/kesehatan bila salah kirim.
  Future<String> paketBerbagi(int anggotaId) async {
    final nama = await _nama(anggotaId);
    if (nama == null) throw ArgumentError('Anggota tidak ditemukan.');
    final izinKu = await _izinMesin(anggotaId, nama: nama);
    final modulTerbuka = <String>[];
    for (final m in ModulKeluarga.values) {
      if (bolehLihatModul(izinKu, anggota: nama, modul: m)) {
        modulTerbuka.add(m.kode);
      }
    }
    final ringkasan = <String, int>{};
    for (final m in modulTerbuka) {
      final n = await hitungModul(ModulKeluarga.dariKode(m)!);
      if (n != null) ringkasan[m] = n;
    }
    return const JsonEncoder.withIndent('  ').convert({
      'versi': versiPaketBerbagi,
      'dibuat': _jam().toIso8601String(),
      'anggota': nama,
      'kodeBerbagi': kodeBerbagiKeluarga(_jam().microsecondsSinceEpoch ~/ 1000),
      'modul': modulTerbuka,
      'jumlahBaris': ringkasan,
      'catatan': 'Berkas ini hanya berisi DAFTAR IZIN dan JUMLAH baris, '
          'bukan isi catatan. Kosong berarti modul itu belum dipakai.',
    });
  }

  /// Hitung jumlah baris satu modul (null bila modulnya belum punya sumber
  /// hitung yang jelas — lebih baik mengaku belum ada daripada menebak).
  Future<int?> hitungModul(ModulKeluarga modul) {
    switch (modul) {
      case ModulKeluarga.tagihan:
        return _hitung(db.tagihan, db.tagihan.id);
      case ModulKeluarga.transaksi:
        return _hitung(db.transaksi, db.transaksi.id);
      case ModulKeluarga.perawatan:
        return _hitung(db.perawatan, db.perawatan.id);
      case ModulKeluarga.dokumen:
        return _hitung(db.dokumen, db.dokumen.id);
      case ModulKeluarga.rumah:
        return _hitung(db.kasInformal, db.kasInformal.id);
      case ModulKeluarga.kesehatan:
      case ModulKeluarga.anggaran:
      case ModulKeluarga.perjalanan:
        return Future.value(null);
    }
  }

  Future<int> _hitung(TableInfo tabel, Column<int> kolom) async {
    final ekspresi = kolom.count();
    final q = db.selectOnly(tabel)..addColumns([ekspresi]);
    final baris = await q.getSingle();
    return baris.read(ekspresi) ?? 0;
  }

  /// Baca berkas paket berbagi (tidak menyimpan apa pun — ditampilkan dulu).
  Map<String, dynamic> bacaPaket(String isi) {
    final dynamic data = jsonDecode(isi);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Berkas paket berbagi tidak dikenali.');
    }
    final versi = data['versi'];
    if (versi is! int || versi != versiPaketBerbagi) {
      throw FormatException('Versi paket berbagi tidak cocok '
          '(butuh $versiPaketBerbagi, berkas berisi $versi).');
    }
    return data;
  }

  /// Ringkas isi paket untuk ditampilkan (jujur apa adanya).
  String ringkasPaket(Map<String, dynamic> paket) {
    final anggota = paket['anggota'] ?? '-';
    final modul = (paket['modul'] as List?)?.map((e) => '$e').toList() ?? const [];
    final jumlah = (paket['jumlahBaris'] as Map?) ?? const {};
    final kode = paket['kodeBerbagi'] ?? '-';
    if (modul.isEmpty) {
      return 'Paket dari $anggota (kode $kode) belum berisi modul apa pun.';
    }
    final rincian = [
      for (final m in modul)
        '${ModulKeluarga.dariKode(m)?.label ?? m}'
            '${jumlah[m] == null ? '' : ' (${jumlah[m]} baris)'}',
    ];
    return 'Paket dari $anggota (kode $kode): ${rincian.join(', ')}.';
  }
}
