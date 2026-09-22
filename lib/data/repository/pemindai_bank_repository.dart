/// FR-39 (+ dasar FR-59) — repositori hasil pemindaian SMS bank.
///
/// Tabel: `pemindaian_bank`. Isi pesan disimpan LOKAL supaya pengguna bisa
/// memeriksa ulang usulannya; tidak ada yang dikirim ke jaringan.
library;

import 'dart:math' show Random;

import 'package:drift/drift.dart';

import '../../core/parsing/pemindai_bank.dart';
import '../database/database.dart';

/// Status tindak lanjut satu hasil pindai.
enum StatusPindai {
  baru('baru', 'Belum diperiksa'),
  dicatat('dicatat', 'Sudah dicatat'),
  ditandaiLunas('lunas', 'Tagihan ditandai lunas'),
  diabaikan('abaikan', 'Diabaikan');

  const StatusPindai(this.kode, this.label);

  final String kode;
  final String label;

  static StatusPindai dariKode(String? kode) {
    for (final s in values) {
      if (s.kode == kode) return s;
    }
    return StatusPindai.baru;
  }
}

class PemindaiBankRepository {
  PemindaiBankRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _jam;
  static final _acak = Random();

  String _uid() => 'pbn${_jam().microsecondsSinceEpoch.toRadixString(36)}'
      '${_acak.nextInt(1 << 20).toRadixString(36)}';

  /// Saklar izin pemindaian (disimpan di tabel `pengaturan`, bawaan MATI).
  Future<bool> izinMenyala() async {
    final baris = await (db.select(db.pengaturan)
          ..where((t) => t.kunci.equals(kunciIzinPemindaiBank)))
        .getSingleOrNull();
    final nilai = baris?.nilai.trim().toLowerCase();
    return nilai == '1' || nilai == 'true' || nilai == 'ya';
  }

  Future<void> setIzin(bool menyala) async {
    final ada = await (db.select(db.pengaturan)
          ..where((t) => t.kunci.equals(kunciIzinPemindaiBank)))
        .getSingleOrNull();
    if (ada == null) {
      await db.into(db.pengaturan).insert(PengaturanCompanion.insert(
            kunci: kunciIzinPemindaiBank,
            nilai: menyala ? '1' : '0',
          ));
      return;
    }
    await (db.update(db.pengaturan)
          ..where((t) => t.kunci.equals(kunciIzinPemindaiBank)))
        .write(PengaturanCompanion(nilai: Value(menyala ? '1' : '0')));
  }

  /// ID pesan yang sudah pernah disimpan (supaya tidak diproses dua kali).
  Future<Set<int>> idSudahDiproses() async {
    final baris = await (db.select(db.pemindaianBank)
          ..where((t) => t.pesanId.isNotNull()))
        .get();
    return {
      for (final b in baris)
        if (b.pesanId != null) b.pesanId!,
    };
  }

  /// Simpan kumpulan hasil pindai; yang sudah pernah ada dilewati.
  /// Mengembalikan jumlah baris BARU yang tersimpan.
  Future<int> simpanHasil(List<HasilPindaiBank> hasil) async {
    if (hasil.isEmpty) return 0;
    final sudah = await idSudahDiproses();
    var tersimpan = 0;
    await db.transaction(() async {
      for (final h in hasil) {
        final pesanId = h.pesan.id;
        if (pesanId != null && sudah.contains(pesanId)) continue;
        if (pesanId == null) {
          final kembar = await (db.select(db.pemindaianBank)
                ..where((t) =>
                    t.sumber.equals(h.pesan.sumber) &
                    t.teks.equals(h.pesan.teks) &
                    t.waktuPesan.equals(h.pesan.waktu)))
              .getSingleOrNull();
          if (kembar != null) continue;
        }
        await db.into(db.pemindaianBank).insert(PemindaianBankCompanion.insert(
              uid: Value(_uid()),
              pesanId: Value(pesanId),
              sumber: h.pesan.sumber,
              teks: h.pesan.teks,
              waktuPesan: h.pesan.waktu,
              nominalSen: Value(h.nominalSen),
              jenis: Value(h.jenis.kode),
              keterangan: Value(h.keterangan),
              saldoSen: Value(h.saldoSen),
              keyakinan: Value(h.keyakinan),
              status: Value(StatusPindai.baru.kode),
              diubahPada: Value(_jam()),
            ));
        tersimpan++;
      }
    });
    return tersimpan;
  }

  Future<List<PemindaianBankData>> daftar({int batas = 100}) {
    return (db.select(db.pemindaianBank)
          ..orderBy([(t) => OrderingTerm.desc(t.waktuPesan)])
          ..limit(batas))
        .get();
  }

  Stream<List<PemindaianBankData>> pantau({int batas = 100}) {
    return (db.select(db.pemindaianBank)
          ..orderBy([(t) => OrderingTerm.desc(t.waktuPesan)])
          ..limit(batas))
        .watch();
  }

  Future<void> tandai(int id, StatusPindai status, {String? tagihanUid}) async {
    await (db.update(db.pemindaianBank)..where((t) => t.id.equals(id)))
        .write(PemindaianBankCompanion(
      status: Value(status.kode),
      tagihanUid: tagihanUid == null ? const Value.absent() : Value(tagihanUid),
      diubahPada: Value(_jam()),
    ));
  }

  Future<void> hapus(int id) async {
    await (db.delete(db.pemindaianBank)..where((t) => t.id.equals(id))).go();
  }

  /// Tagihan yang belum lunas — calon pasangan untuk usulan pencocokan.
  Future<List<KandidatTagihan>> kandidatTagihan() async {
    final baris = await (db.select(db.tagihan)
          ..where((t) => t.lunas.equals(false) & t.statusAktif.equals(true)))
        .get();
    return [
      for (final t in baris)
        if ((t.jumlahSen ?? 0) > 0)
          KandidatTagihan(
            nama: t.nama,
            jumlahSen: t.jumlahSen!,
            jatuhTempo: t.jatuhTempo,
          ),
    ];
  }

  /// ID tagihan untuk sebuah [KandidatTagihan] (dipakai saat menandai lunas).
  Future<int?> idTagihanDari(KandidatTagihan kandidat) async {
    final baris = await (db.select(db.tagihan)
          ..where((t) =>
              t.nama.equals(kandidat.nama) &
              t.lunas.equals(false) &
              t.statusAktif.equals(true)))
        .getSingleOrNull();
    return baris?.id;
  }

  /// Ubah baris basis data menjadi mesin murni (untuk ringkasan di layar).
  HasilPindaiBank keMesin(PemindaianBankData b) {
    final jenis = JenisPesanBank.values.firstWhere(
      (j) => j.kode == b.jenis,
      orElse: () => JenisPesanBank.tidakDikenali,
    );
    return HasilPindaiBank(
      pesan: PesanBank(
        sumber: b.sumber,
        teks: b.teks,
        waktu: b.waktuPesan,
        id: b.pesanId,
      ),
      jenis: jenis,
      nominalSen: b.nominalSen,
      keterangan: b.keterangan,
      saldoSen: b.saldoSen,
      keyakinan: b.keyakinan,
      alasan: const [],
    );
  }

  Future<RingkasPindaiBank> ringkas({int batas = 100}) async {
    final baris = await daftar(batas: batas);
    return ringkasPindaiBank([for (final b in baris) keMesin(b)],
        sekarang: _jam());
  }
}
