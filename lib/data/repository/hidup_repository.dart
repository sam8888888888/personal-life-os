/// Pengumpul data untuk batch 7 — "ritme hidup":
///
/// * FR-132 Kalender Keluarga — [agendaKeluarga]
/// * FR-140 Life Timeline   — [peristiwa]
/// * FR-141 Personal Analytics, FR-144 Weekly Review, FR-145 Monthly Report
///   — [bahan] (satu pintu, supaya ketiganya memakai angka yang sama)
///
/// Semua penilaian/penyusunan tetap di `lib/core/...`; berkas ini hanya
/// mengambil baris basis data lalu menyerahkannya dalam bentuk yang seragam.
library;

import 'package:drift/drift.dart';

import '../../core/analitik/bahan_analitik.dart';
import '../../core/keluarga/kalender_keluarga.dart';
import '../../core/timeline/lini_masa.dart';
import '../../core/utils/waktu.dart';
import '../database/database.dart';
import '../model/enums.dart';
import 'aset_repository.dart';
import 'langganan_repository.dart';
import '../../core/notifikasi/jejak.dart';

class HidupRepository {
  HidupRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;
  final DateTime Function() _jam;

  /// Batas aman jumlah baris per sumber pada lini masa (layar menggulir,
  /// bukan mesin pencari — pengguna tidak butuh ribuan baris).
  static const int batasPerSumber = 400;

  // ══════════════════════════════════════════════════════════════════════════
  // FR-132 — Kalender Keluarga
  // ══════════════════════════════════════════════════════════════════════════

  /// Agenda semua anggota pada rentang [dari]–[sampai]:
  /// tagihan, tugas, janji kesehatan, jadwal perawatan, dan ulang tahun.
  Future<List<AgendaKeluarga>> agendaKeluarga({
    required DateTime dari,
    required DateTime sampai,
  }) async {
    final awal = _awalHari(dari);
    final akhir = _akhirHari(sampai);
    final hasil = <AgendaKeluarga>[];

    // 1. Tagihan belum lunas
    final tagihan = await (db.select(db.tagihan)
          ..where((t) => t.statusAktif.equals(true))
          ..where((t) => t.lunas.equals(false))
          ..where((t) => t.jatuhTempo.isBiggerOrEqualValue(awal))
          ..where((t) => t.jatuhTempo.isSmallerOrEqualValue(akhir)))
        .get();
    for (final t in tagihan) {
      hasil.add(AgendaKeluarga(
        tanggal: t.jatuhTempo,
        judul: 'Tagihan ${t.nama}',
        modul: 'tagihan',
        keterangan: '${t.kodeMataUang} ${((t.jumlahSen ?? 0) / 100).round()}',
        anggotaId: t.pemilikId,
      ));
    }

    // 2. Tugas belum selesai
    final tugas = await (db.select(db.tugas)
          ..where((t) => t.selesai.equals(false))
          ..where((t) => t.jatuhTempo.isNotNull())
          ..where((t) => t.jatuhTempo.isBiggerOrEqualValue(awal))
          ..where((t) => t.jatuhTempo.isSmallerOrEqualValue(akhir)))
        .get();
    for (final t in tugas) {
      hasil.add(AgendaKeluarga(
        tanggal: t.jatuhTempo!,
        judul: t.nama,
        modul: 'tugas',
        keterangan: t.prioritas,
        anggotaId: t.pemilikId,
      ));
    }

    // 3. Janji kesehatan
    final janji = await (db.select(db.janjiKesehatan)
          ..where((j) => j.selesai.equals(false))
          ..where((j) => j.waktu.isBiggerOrEqualValue(awal))
          ..where((j) => j.waktu.isSmallerOrEqualValue(akhir)))
        .get();
    for (final j in janji) {
      final jam = j.waktu.hour.toString().padLeft(2, '0');
      final menit = j.waktu.minute.toString().padLeft(2, '0');
      hasil.add(AgendaKeluarga(
        tanggal: j.waktu,
        judul: j.judul,
        modul: 'janji',
        keterangan: '$jam:$menit${(j.tempat ?? '').isEmpty ? '' : ' · ${j.tempat}'}',
      ));
    }

    // 4. Jadwal perawatan rumah/aset
    final rawat = await (db.select(db.perawatan)
          ..where((p) => p.aktif.equals(true))
          ..where((p) => p.berikutnya.isBiggerOrEqualValue(awal))
          ..where((p) => p.berikutnya.isSmallerOrEqualValue(akhir)))
        .get();
    for (final p in rawat) {
      hasil.add(AgendaKeluarga(
        tanggal: p.berikutnya,
        judul: p.nama,
        modul: 'perawatan',
        keterangan: p.kategori,
      ));
    }

    // 5. Ulang tahun anggota keluarga (untuk tiap tahun yang tersentuh rentang)
    final anggota = await (db.select(db.anggotaKeluarga)
          ..where((a) => a.arsip.equals(false)))
        .get();
    final tahun = <int>{awal.year, akhir.year};
    for (final t in tahun) {
      hasil.addAll(ulangTahunAnggota(
        anggota: anggota.map((a) => (
              id: a.id,
              nama: a.nama,
              lahir: a.tanggalLahir,
            )),
        tahun: t,
      ));
    }
    return hasil;
  }

  /// Anggota keluarga (untuk saringan & warna di kalender).
  Future<List<AnggotaKeluargaData>> anggotaAktif({bool sertakanArsip = false}) =>
      (db.select(db.anggotaKeluarga)
            ..where((a) => sertakanArsip ? const Constant(true) : a.arsip.equals(false))
            ..orderBy([(a) => OrderingTerm.asc(a.id)]))
          .get();

  // ══════════════════════════════════════════════════════════════════════════
  // FR-140 — Life Timeline
  // ══════════════════════════════════════════════════════════════════════════

  /// Semua kejadian hidup pada rentang [dari]–[sampai], dari data nyata.
  Future<List<PeristiwaHidup>> peristiwa({
    required DateTime dari,
    required DateTime sampai,
  }) async {
    final awal = _awalHari(dari);
    final akhir = _akhirHari(sampai);
    final hasil = <PeristiwaHidup>[];

    void tambah(DateTime? tanggal, String modul, String judul,
        {String keterangan = '', String rujukan = ''}) {
      if (tanggal == null) return;
      if (tanggal.isBefore(awal) || tanggal.isAfter(akhir)) return;
      hasil.add(PeristiwaHidup(
        tanggal: tanggal,
        modul: modul,
        judul: judul,
        keterangan: keterangan,
        rujukan: rujukan,
      ));
    }

    // — uang —
    final tagihanLunas = await (db.select(db.tagihan)
          ..where((t) => t.tanggalLunas.isNotNull())
          ..where((t) => t.tanggalLunas.isBiggerOrEqualValue(awal))
          ..where((t) => t.tanggalLunas.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final t in tagihanLunas) {
      tambah(t.tanggalLunas, 'uang', 'Tagihan dibayar: ${t.nama}',
          keterangan:
              '${t.kodeMataUang} ${((t.jumlahSen ?? 0) / 100).round()}',
          rujukan: 'tagihan#${t.id}');
    }

    final bayar = await (db.select(db.riwayatPembayaran)
          ..where((r) => r.tanggalBayar.isBiggerOrEqualValue(awal))
          ..where((r) => r.tanggalBayar.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final r in bayar) {
      tambah(r.tanggalBayar, 'uang',
          'Pembayaran ${r.periodeJatuhTempo}',
          keterangan: '${r.kodeMataUang} ${(r.jumlahSen / 100).round()}'
              '${r.via.isEmpty ? '' : ' · via ${r.via}'}',
          rujukan: 'riwayat_pembayaran#${r.id}');
    }

    final transaksi = await (db.select(db.transaksi)
          ..where((t) => t.tanggal.isBiggerOrEqualValue(awal))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final t in transaksi) {
      final keluar = JenisArus.dariDb(t.jenis) == JenisArus.pengeluaran;
      tambah(t.tanggal, 'uang', keluar ? 'Pengeluaran dicatat' : 'Pemasukan dicatat',
          keterangan:
              '${t.kodeMataUang} ${(t.jumlahSen / 100).round()}${(t.catatan ?? '').isEmpty ? '' : ' · ${t.catatan}'}',
          rujukan: 'transaksi#${t.id}');
    }

    // — tujuan & tugas —
    final tugasSelesai = await (db.select(db.tugas)
          ..where((t) => t.selesai.equals(true))
          ..where((t) => t.selesaiPada.isBiggerOrEqualValue(awal))
          ..where((t) => t.selesaiPada.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final t in tugasSelesai) {
      tambah(t.selesaiPada, 'tugas', 'Tugas selesai: ${t.nama}',
          rujukan: 'tugas#${t.id}');
    }

    final tujuanSelesai = await (db.select(db.tujuan)
          ..where((t) => t.selesaiPada.isNotNull())
          ..where((t) => t.selesaiPada.isBiggerOrEqualValue(awal))
          ..where((t) => t.selesaiPada.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final t in tujuanSelesai) {
      tambah(t.selesaiPada, 'tugas', 'Tujuan tercapai: ${t.nama}',
          keterangan: t.targetTeks ?? '',
          rujukan: 'tujuan#${t.id}');
    }

    // — kesehatan —
    final medis = await (db.select(db.catatanMedis)
          ..where((c) => c.tanggal.isBiggerOrEqualValue(awal))
          ..where((c) => c.tanggal.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final c in medis) {
      tambah(c.tanggal, 'kesehatan', 'Catatan medis: ${c.judul}',
          keterangan: c.jenis, rujukan: 'catatan_medis#${c.id}');
    }

    final janjiSelesai = await (db.select(db.janjiKesehatan)
          ..where((j) => j.selesai.equals(true))
          ..where((j) => j.waktu.isBiggerOrEqualValue(awal))
          ..where((j) => j.waktu.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final j in janjiSelesai) {
      tambah(j.waktu, 'kesehatan', 'Kunjungan: ${j.judul}',
          keterangan: j.tempat ?? '', rujukan: 'janji_kesehatan#${j.id}');
    }

    final ukuran = await (db.select(db.ukuranTubuh)
          ..where((u) => u.tanggal.isBiggerOrEqualValue(awal))
          ..where((u) => u.tanggal.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final u in ukuran) {
      tambah(u.tanggal, 'kesehatan', 'Ukuran tubuh: ${u.jenis}',
          keterangan: '${u.nilai} ${u.satuan}', rujukan: 'ukuran_tubuh#${u.id}');
    }

    // — pengetahuan —
    final catatan = await (db.select(db.catatanPengetahuan)
          ..where((c) => c.dibuatPada.isBiggerOrEqualValue(awal))
          ..where((c) => c.dibuatPada.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final c in catatan) {
      tambah(c.dibuatPada, 'pengetahuan', 'Catatan: ${c.judul}',
          keterangan: c.kategori, rujukan: 'catatan_pengetahuan#${c.id}');
    }

    final keputusan = await (db.select(db.keputusan)
          ..where((k) => k.diputuskanPada.isBiggerOrEqualValue(awal))
          ..where((k) => k.diputuskanPada.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final k in keputusan) {
      tambah(k.diputuskanPada, 'pengetahuan',
          'Keputusan: ${k.dipilih?.isNotEmpty == true ? k.dipilih! : k.judul}',
          rujukan: 'keputusan#${k.id}');
    }

    final bacaan = await (db.select(db.bacaan)
          ..where((b) => b.selesaiPada.isNotNull())
          ..where((b) => b.selesaiPada.isBiggerOrEqualValue(awal))
          ..where((b) => b.selesaiPada.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final b in bacaan) {
      tambah(b.selesaiPada, 'pengetahuan', 'Bacaan selesai: ${b.judul}',
          keterangan: b.penulis ?? '', rujukan: 'bacaan#${b.id}');
    }

    // — ibadah —
    final zakat = await (db.select(db.zakatSedekah)
          ..where((z) => z.tanggal.isBiggerOrEqualValue(awal))
          ..where((z) => z.tanggal.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final z in zakat) {
      tambah(z.tanggal, 'ibadah',
          z.jenis == 'zakat' ? 'Zakat ditunaikan' : 'Sedekah dicatat',
          keterangan: '${z.kodeMataUang} ${(z.jumlahSen / 100).round()}',
          rujukan: 'zakat_sedekah#${z.id}');
    }

    final hafalan = await (db.select(db.hafalan)
          ..where((h) => h.dibuatPada.isBiggerOrEqualValue(awal))
          ..where((h) => h.dibuatPada.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final h in hafalan) {
      tambah(h.dibuatPada, 'ibadah', 'Hafalan: ${h.nama}',
          keterangan: h.jenis, rujukan: 'hafalan#${h.id}');
    }

    // — rumah & aset —
    final aset = await (db.select(db.aset)
          ..where((a) => a.tanggalBeli.isNotNull())
          ..where((a) => a.tanggalBeli.isBiggerOrEqualValue(awal))
          ..where((a) => a.tanggalBeli.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final a in aset) {
      tambah(a.tanggalBeli, 'rumah', 'Aset dibeli: ${a.nama}',
          keterangan: a.institusi ?? '', rujukan: 'aset#${a.id}');
    }

    final rawat = await (db.select(db.riwayatPerawatanAset)
          ..where((r) => r.tanggal.isBiggerOrEqualValue(awal))
          ..where((r) => r.tanggal.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final r in rawat) {
      tambah(r.tanggal, 'rumah', 'Perawatan: ${r.uraian}',
          rujukan: 'riwayat_perawatan_aset#${r.id}');
    }

    // — dokumen —
    final dokumen = await (db.select(db.dokumen)
          ..where((d) => d.terbit.isNotNull())
          ..where((d) => d.terbit.isBiggerOrEqualValue(awal))
          ..where((d) => d.terbit.isSmallerOrEqualValue(akhir))
          ..limit(batasPerSumber))
        .get();
    for (final d in dokumen) {
      tambah(d.terbit, 'dokumen', 'Dokumen terbit: ${d.nama}',
          keterangan: d.jenis, rujukan: 'dokumen#${d.id}');
    }

    hasil.sort((a, b) => a.tanggal.compareTo(b.tanggal));
    return hasil;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FR-141 / FR-144 / FR-145 — bahan angka satu pintu
  // ══════════════════════════════════════════════════════════════════════════

  /// Semua angka periode [dari]–[sampai] (dipakai analitik, tinjauan pekan,
  /// dan laporan bulanan sekaligus).
  Future<BahanAnalitik> bahan({
    required DateTime dari,
    required DateTime sampai,
    int hari = 0,
  }) async {
    final awal = _awalHari(dari);
    final akhir = _akhirHari(sampai);

    // uang: transaksi (rentang bebas, bukan hanya satu bulan)
    final trx = await (db.select(db.transaksi)
          ..where((t) => t.tanggal.isBiggerOrEqualValue(awal))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(akhir))
          ..limit(5000))
        .get();
    var masuk = 0;
    var keluar = 0;
    for (final t in trx) {
      if (JenisArus.dariDb(t.jenis) == JenisArus.pemasukan) {
        masuk += t.jumlahSen;
      } else {
        keluar += t.jumlahSen;
      }
    }

    final tagihanBaru = await _hitung(
        db.tagihan,
        db.tagihan.dibuatPada.isBiggerOrEqualValue(awal) &
            db.tagihan.dibuatPada.isSmallerOrEqualValue(akhir));
    final nilaiTagihan = await _jumlah(
        db.tagihan,
        db.tagihan.dibuatPada.isBiggerOrEqualValue(awal) &
            db.tagihan.dibuatPada.isSmallerOrEqualValue(akhir),
        db.tagihan.jumlahSen);

    final bayar = await (db.select(db.riwayatPembayaran)
          ..where((r) => r.tanggalBayar.isBiggerOrEqualValue(awal))
          ..where((r) => r.tanggalBayar.isSmallerOrEqualValue(akhir))
          ..limit(5000))
        .get();
    var nilaiBayar = 0;
    for (final r in bayar) {
      nilaiBayar += r.jumlahSen;
    }

    // tujuan & tugas
    final tujuanSelesai = await _hitung(
        db.tujuan,
        db.tujuan.selesaiPada.isNotNull() &
            db.tujuan.selesaiPada.isBiggerOrEqualValue(awal) &
            db.tujuan.selesaiPada.isSmallerOrEqualValue(akhir));
    final tujuanBaru = await _hitung(
        db.tujuan,
        db.tujuan.dibuatPada.isBiggerOrEqualValue(awal) &
            db.tujuan.dibuatPada.isSmallerOrEqualValue(akhir));
    final tugasSelesai = await _hitung(
        db.tugas,
        db.tugas.selesai.equals(true) &
            db.tugas.selesaiPada.isBiggerOrEqualValue(awal) &
            db.tugas.selesaiPada.isSmallerOrEqualValue(akhir));
    final tugasBaru = await _hitung(
        db.tugas,
        db.tugas.dibuatPada.isBiggerOrEqualValue(awal) &
            db.tugas.dibuatPada.isSmallerOrEqualValue(akhir));
    final tugasTerbuka =
        await _hitung(db.tugas, db.tugas.selesai.equals(false));

    // kesehatan
    final aktivitas = await (db.select(db.aktivitas)
          ..where((a) => a.tanggal.isBiggerOrEqualValue(awal))
          ..where((a) => a.tanggal.isSmallerOrEqualValue(akhir))
          ..limit(5000))
        .get();
    final hariAktivitas = <String>{};
    var menitAktivitas = 0;
    for (final a in aktivitas) {
      hariAktivitas.add(_kunciHari(a.tanggal));
      menitAktivitas += a.durasiMenit;
    }

    final tidur = await (db.select(db.tidur)
          ..where((t) => t.tanggal.isBiggerOrEqualValue(awal))
          ..where((t) => t.tanggal.isSmallerOrEqualValue(akhir))
          ..limit(5000))
        .get();
    var menitTidur = 0;
    for (final t in tidur) {
      menitTidur += t.durasiMenit;
    }

    final ukuranTubuh = await _hitung(
        db.ukuranTubuh,
        db.ukuranTubuh.tanggal.isBiggerOrEqualValue(awal) &
            db.ukuranTubuh.tanggal.isSmallerOrEqualValue(akhir));
    final berat = await (db.select(db.ukuranTubuh)
          ..where((u) => u.jenis.equals('berat'))
          ..orderBy([(u) => OrderingTerm.desc(u.tanggal)])
          ..limit(1))
        .get();

    final catatanMedis = await _hitung(
        db.catatanMedis,
        db.catatanMedis.tanggal.isBiggerOrEqualValue(awal) &
            db.catatanMedis.tanggal.isSmallerOrEqualValue(akhir));
    final janjiKesehatan = await _hitung(
        db.janjiKesehatan,
        db.janjiKesehatan.waktu.isBiggerOrEqualValue(awal) &
            db.janjiKesehatan.waktu.isSmallerOrEqualValue(akhir));

    // pengetahuan & ibadah
    final catatanPengetahuan = await _hitung(
        db.catatanPengetahuan,
        db.catatanPengetahuan.dibuatPada.isBiggerOrEqualValue(awal) &
            db.catatanPengetahuan.dibuatPada.isSmallerOrEqualValue(akhir));
    final keputusanBaru = await _hitung(
        db.keputusan,
        db.keputusan.diputuskanPada.isBiggerOrEqualValue(awal) &
            db.keputusan.diputuskanPada.isSmallerOrEqualValue(akhir));
    final bacaanSelesai = await _hitung(
        db.bacaan,
        db.bacaan.selesaiPada.isNotNull() &
            db.bacaan.selesaiPada.isBiggerOrEqualValue(awal) &
            db.bacaan.selesaiPada.isSmallerOrEqualValue(akhir));
    final kartuDiulang = await _hitung(
        db.kartuUlangan,
        db.kartuUlangan.terakhirDiulang.isNotNull() &
            db.kartuUlangan.terakhirDiulang.isBiggerOrEqualValue(awal) &
            db.kartuUlangan.terakhirDiulang.isSmallerOrEqualValue(akhir));
    final hafalanBaru = await _hitung(
        db.hafalan,
        db.hafalan.dibuatPada.isBiggerOrEqualValue(awal) &
            db.hafalan.dibuatPada.isSmallerOrEqualValue(akhir));
    final zakat = await _jumlah(
        db.zakatSedekah,
        db.zakatSedekah.tanggal.isBiggerOrEqualValue(awal) &
            db.zakatSedekah.tanggal.isSmallerOrEqualValue(akhir),
        db.zakatSedekah.jumlahSen);

    // rumah & aset
    final rawat = await (db.select(db.riwayatPerawatanAset)
          ..where((r) => r.tanggal.isBiggerOrEqualValue(awal))
          ..where((r) => r.tanggal.isSmallerOrEqualValue(akhir))
          ..limit(5000))
        .get();
    var biayaRawat = 0;
    for (final r in rawat) {
      biayaRawat += r.biayaSen;
    }

    // dokumen mendekati kedaluwarsa (keadaan saat ini, bukan periode)
    final sekarang = _jam();
    final dokumen = await (db.select(db.dokumen)
          ..where((d) => d.aktif.equals(true))
          ..where((d) => d.berlakuSampai.isNotNull())
          ..where((d) => d.berlakuSampai
              .isBiggerOrEqualValue(_awalHari(sekarang)))
          ..where((d) => d.berlakuSampai.isSmallerOrEqualValue(
              _akhirHari(sekarang.add(const Duration(days: 90))))))
        .get();

    // langganan (keadaan saat ini)
    final langgananRepo = LanggananRepository(db);
    final langgananAktif = await langgananRepo.ambilAktif();
    final biayaLangganan = await langgananRepo.totalBulananSen();

    // kekayaan bersih bulan berjalan (aset − kewajiban) — dihitung repositori aset
    int? asetSen;
    int? kewajibanSen;
    int? bersihSen;
    try {
      final nilai = await AsetRepository(db).nilaiBersih(_kunciBulan(akhir));
      asetSen = nilai.totalAsetSen;
      kewajibanSen = nilai.totalKewajibanSen;
      bersihSen = nilai.bersihSen;
    } catch (e) {
      // Bila modul aset belum dipakai, biarkan kosong (layar menulis
      // "belum ada data") — bukan angka 0 yang menyesatkan. Kegagalannya
      // tetap dicatat supaya tidak hilang tanpa jejak.
      catatGalatTertelan('hidup.nilaiBersihGagal', e);
    }

    return BahanAnalitik(
      dari: awal,
      sampai: akhir,
      hari: hari,
      tagihanBaru: tagihanBaru,
      tagihanLunas: bayar.length,
      totalTagihanSen: nilaiTagihan,
      totalBayarSen: nilaiBayar,
      transaksiBaru: trx.length,
      pengeluaranSen: keluar,
      pemasukanSen: masuk,
      tujuanSelesai: tujuanSelesai,
      tujuanBaru: tujuanBaru,
      tugasSelesai: tugasSelesai,
      tugasBaru: tugasBaru,
      tugasTerbuka: tugasTerbuka,
      hariAktivitas: hariAktivitas.length,
      menitAktivitas: menitAktivitas,
      menitTidur: menitTidur,
      malamTidurTercatat: tidur.length,
      ukuranTubuh: ukuranTubuh,
      beratAkhirGram: berat.isEmpty ? null : berat.first.nilai,
      catatanMedis: catatanMedis,
      janjiKesehatan: janjiKesehatan,
      catatanPengetahuan: catatanPengetahuan,
      keputusanBaru: keputusanBaru,
      bacaanSelesai: bacaanSelesai,
      kartuDiulang: kartuDiulang,
      hafalanBaru: hafalanBaru,
      zakatSen: zakat,
      perawatanAset: rawat.length,
      biayaPerawatanSen: biayaRawat,
      dokumenKedaluwarsa: dokumen.length,
      langgananAktif: langgananAktif.length,
      biayaLanggananSen: biayaLangganan,
      kekayaanBersihSen: bersihSen,
      totalAsetSen: asetSen,
      totalKewajibanSen: kewajibanSen,
    );
  }

  // ── daftar pendukung untuk fokus & laporan ────────────────────────────────

  /// Tujuan aktif yang targetnya paling dekat (maks [batas]).
  Future<List<String>> tujuanTerdekat({int batas = 3, int hari = 60}) async {
    final sampai = _akhirHari(_jam().add(Duration(days: hari)));
    final baris = await (db.select(db.tujuan)
          ..where((t) => t.status.equals('aktif'))
          ..where((t) => t.tanggalTarget.isNotNull())
          ..where((t) => t.tanggalTarget.isSmallerOrEqualValue(sampai))
          ..orderBy([(t) => OrderingTerm.asc(t.tanggalTarget)])
          ..limit(batas))
        .get();
    final kini = _awalHari(_jam());
    return baris.map((t) {
      final sisa = t.tanggalTarget!.difference(kini).inDays;
      final kapan = sisa <= 0 ? 'jatuh tempo' : '$sisa hari lagi';
      return '${t.nama} ($kapan)';
    }).toList();
  }

  /// Tugas terbuka yang paling perlu dikerjakan (maks [batas]).
  Future<List<String>> tugasPenting({int batas = 5}) async {
    final baris = await (db.select(db.tugas)
          ..where((t) => t.selesai.equals(false))
          ..where((t) => t.jatuhTempo.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)])
          ..limit(batas))
        .get();
    final kini = _awalHari(_jam());
    return baris.map((t) {
      final sisa = t.jatuhTempo!.difference(kini).inDays;
      final kapan = sisa < 0 ? 'lewat ${-sisa} hari' : (sisa == 0 ? 'hari ini' : '$sisa hari lagi');
      return '${t.nama} ($kapan)';
    }).toList();
  }

  /// Langganan aktif yang tagihannya jatuh tempo dekat.
  Future<List<String>> langgananDekat({int hari = 30}) async {
    final akhir = _akhirHari(_jam().add(Duration(days: hari)));
    final aktif = await (db.select(db.langganan)
          ..where((l) => l.status.equals('aktif'))
          ..where((l) => l.tagihanId.isNotNull()))
        .get();
    if (aktif.isEmpty) return const [];
    final id = aktif.map((l) => l.tagihanId!).toList();
    final daftar = await (db.select(db.tagihan)
          ..where((t) => t.id.isIn(id))
          ..where((t) => t.lunas.equals(false))
          ..where((t) => t.jatuhTempo.isSmallerOrEqualValue(akhir))
          ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)]))
        .get();
    return daftar.map((t) => '${t.nama} (${_tanggalPendek(t.jatuhTempo)})').toList();
  }

  /// Dokumen aktif yang kedaluwarsa dalam [hari] hari ke depan.
  Future<List<String>> dokumenDekat({int hari = 90}) async {
    final sekarang = _awalHari(_jam());
    final akhir = _akhirHari(sekarang.add(Duration(days: hari)));
    final baris = await (db.select(db.dokumen)
          ..where((d) => d.aktif.equals(true))
          ..where((d) => d.berlakuSampai.isNotNull())
          ..where((d) => d.berlakuSampai.isBiggerOrEqualValue(sekarang))
          ..where((d) => d.berlakuSampai.isSmallerOrEqualValue(akhir))
          ..orderBy([(d) => OrderingTerm.asc(d.berlakuSampai)]))
        .get();
    return baris
        .map((d) => '${d.nama} (${_tanggalPendek(d.berlakuSampai!)})')
        .toList();
  }

  /// Tiga aset terbesar menurut nilai yang tercatat.
  Future<List<String>> asetTerbesar({int batas = 3}) async {
    final baris = await (db.select(db.aset)
          ..where((a) => a.arsip.equals(false))
          ..orderBy([(a) => OrderingTerm.desc(a.nilaiAwalSen)])
          ..limit(batas))
        .get();
    return baris
        .map((a) => '${a.nama} (Rp${_ribuan((a.nilaiAwalSen / 100).round())})')
        .toList();
  }

  // ── bantu ─────────────────────────────────────────────────────────────────

  /// Hitung jumlah baris yang memenuhi [syarat].
  ///
  /// Syarat dibangun pemanggil dari kolom tabelnya sendiri (mis.
  /// `db.tagihan.dibuatPada...`) supaya tipenya pasti cocok.
  Future<int> _hitung(
    TableInfo<Table, dynamic> tabel,
    Expression<bool> syarat,
  ) async {
    final hitung = tabel.rowId.count();
    final q = db.selectOnly(tabel)..addColumns([hitung]);
    q.where(syarat);
    final baris = await q.getSingle();
    return baris.read(hitung) ?? 0;
  }

  /// Jumlahkan [kolom] pada baris yang memenuhi [syarat].
  Future<int> _jumlah(
    TableInfo<Table, dynamic> tabel,
    Expression<bool> syarat,
    Expression<int> kolom,
  ) async {
    final total = kolom.sum();
    final q = db.selectOnly(tabel)..addColumns([total]);
    q.where(syarat);
    final baris = await q.getSingle();
    return baris.read(total) ?? 0;
  }

  DateTime _awalHari(DateTime t) => DateTime(t.year, t.month, t.day);

  DateTime _akhirHari(DateTime t) =>
      DateTime(t.year, t.month, t.day, 23, 59, 59, 999);

  String _kunciHari(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  String _kunciBulan(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}';

  String _tanggalPendek(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';

  String _ribuan(int n) {
    final teks = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < teks.length; i++) {
      if (i > 0 && (teks.length - i) % 3 == 0) b.write('.');
      b.write(teks[i]);
    }
    return '${n < 0 ? '-' : ''}$b';
  }
}
