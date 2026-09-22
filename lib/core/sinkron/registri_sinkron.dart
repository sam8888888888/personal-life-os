/// Sinkron SEMUA MODUL (FR-150, tahap 3) — Aaron, 22 Sep 2026.
///
/// Kenapa dirancang begini (dan bukan menambah kode sinkron di tiap repositori):
/// - Jalur tulis lama (tagihan, kesehatan, pengetahuan, …) TIDAK disentuh sama
///   sekali — tidak ada risiko mengubah perilaku yang sudah teruji, dan tidak
///   ada hutang teknis berupa “ingat menandai kotor” di setiap penulisan baru.
/// - Perubahan dikenali dengan MEMBANDINGKAN SIDIK ISI BARIS terhadap catatan
///   sidik terakhir (`sinkron_sidik`). Jadi jalur apa pun yang mengubah data
///   (termasuk lunas/nonaktifkan yang tidak lewat repositori) ikut terbawa.
/// - Pengenal antar HP = kolom `uid` (bukan id angka yang bisa bentrok).
/// - Kaitan antar tabel (foreign key) dikirim sebagai **uid induk**, lalu
///   dipetakan kembali ke id lokal di HP penerima. Bila induknya belum turun,
///   kaitan ditahan di `sinkron_tautan_belum` — supaya tidak pernah dipasang ke
///   baris induk yang salah.
///
/// Batas yang Ron sadari: tabel obat/jadwal_obat/minum_obat serta tabel turunan
/// (audit, notifikasi) belum ikut; rencana menambahkannya cukup dengan menambah
/// satu baris di registri.
library;

import 'package:drift/drift.dart';

import '../../data/database/database.dart';

/// Satu jalur sinkron: satu tabel + kolom uid + kaitan ke induknya.
class JalurSinkron {
  const JalurSinkron({
    required this.nama,
    required this.tabel,
    required this.kolomUid,
    this.kolomKunci,
    this.kolomDiubah,
    this.kaitan = const <String, String>{},
    this.saring,
  });

  /// Nama tabel di SQLite sekaligus nama di server.
  final String nama;
  final TableInfo<Table, dynamic> tabel;

  /// Kolom pengenal stabil antar HP.
  final GeneratedColumn<String> kolomUid;

  /// Kolom kunci angka (autoIncrement). Tidak dikirim; penerima memakai id lokal.
  final GeneratedColumn<int>? kolomKunci;

  /// Kolom waktu diubah (dipakai sebagai waktu kirim bila ada).
  final GeneratedColumn<DateTime>? kolomDiubah;

  /// Kolom foreign key → nama jalur induk. Nilai dikirim sebagai uid induk.
  final Map<String, String> kaitan;

  /// Penyaring opsional: baris yang TIDAK ikut sinkron. Dipakai untuk baris
  /// bawaan sistem yang sudah ada di setiap HP (mis. kategori kas bawaan) —
  /// kalau ikut disinkronkan, kategori bawaan akan berlipat ganda.
  final bool Function(Map<String, Object?> baris)? saring;
}

/// Seluruh jalur sinkron, URUT: induk selalu sebelum anak (kalau tidak, kaitan
/// anak tidak menemukan uid induk dan akan tertahan).
List<JalurSinkron> daftarJalurSinkron(AppDatabase db) => <JalurSinkron>[
      // ── uang ──────────────────────────────────────────────────────────────
      JalurSinkron(
        nama: 'tagihan',
        tabel: db.tagihan,
        kolomUid: db.tagihan.uid,
        kolomKunci: db.tagihan.id,
        kolomDiubah: db.tagihan.diubahPada,
        kaitan: <String, String>{
          'pemilik_id': 'anggota_keluarga',
          'penanggung_jawab_id': 'anggota_keluarga',
        },
      ),
      JalurSinkron(
        nama: 'riwayat_pembayaran',
        tabel: db.riwayatPembayaran,
        kolomUid: db.riwayatPembayaran.uid,
        kolomKunci: db.riwayatPembayaran.id,
        kaitan: <String, String>{'tagihan_id': 'tagihan'},
      ),
      JalurSinkron(
        nama: 'kategori_transaksi',
        tabel: db.kategoriTransaksi,
        kolomUid: db.kategoriTransaksi.uid,
        kolomKunci: db.kategoriTransaksi.id,
        // Kategori bawaan sistem sudah ada di tiap HP (dibuat saat basis data
        // pertama dibuka) → tidak ikut disinkronkan supaya tidak berlipat.
        saring: (r) => r['bawaan_sistem'] != 1 && r['bawaan_sistem'] != true,
      ),
      JalurSinkron(
        nama: 'transaksi',
        tabel: db.transaksi,
        kolomUid: db.transaksi.uid,
        kolomKunci: db.transaksi.id,
        kaitan: <String, String>{
          'kategori_id': 'kategori_transaksi',
          'tagihan_id': 'tagihan',
        },
      ),
      JalurSinkron(
        nama: 'pemasukan_bulanan',
        tabel: db.pemasukanBulanan,
        kolomUid: db.pemasukanBulanan.uid,
        kolomKunci: db.pemasukanBulanan.id,
      ),
      JalurSinkron(
        nama: 'anggaran_bulanan',
        tabel: db.anggaranBulanan,
        kolomUid: db.anggaranBulanan.uid,
        kolomKunci: db.anggaranBulanan.id,
        kaitan: <String, String>{'kategori_id': 'kategori_transaksi'},
      ),
      JalurSinkron(
        nama: 'langganan',
        tabel: db.langganan,
        kolomUid: db.langganan.uid,
        kolomKunci: db.langganan.id,
        kaitan: <String, String>{
          'tagihan_id': 'tagihan',
          'kategori_id': 'kategori_transaksi',
        },
      ),
      JalurSinkron(
        nama: 'pengeluaran_terencana',
        tabel: db.pengeluaranTerencana,
        kolomUid: db.pengeluaranTerencana.uid,
        kolomKunci: db.pengeluaranTerencana.id,
      ),

      // ── kekayaan (aset & kewajiban) ───────────────────────────────────────
      JalurSinkron(
        nama: 'aset',
        tabel: db.aset,
        kolomUid: db.aset.uid,
        kolomKunci: db.aset.id,
        kolomDiubah: db.aset.diubahPada,
      ),
      JalurSinkron(
        nama: 'nilai_aset_bulanan',
        tabel: db.nilaiAsetBulanan,
        kolomUid: db.nilaiAsetBulanan.uid,
        kolomKunci: db.nilaiAsetBulanan.id,
        kaitan: <String, String>{'aset_id': 'aset'},
      ),
      JalurSinkron(
        nama: 'kewajiban',
        tabel: db.kewajiban,
        kolomUid: db.kewajiban.uid,
        kolomKunci: db.kewajiban.id,
        kolomDiubah: db.kewajiban.diubahPada,
      ),
      JalurSinkron(
        nama: 'nilai_kewajiban_bulanan',
        tabel: db.nilaiKewajibanBulanan,
        kolomUid: db.nilaiKewajibanBulanan.uid,
        kolomKunci: db.nilaiKewajibanBulanan.id,
        kaitan: <String, String>{'kewajiban_id': 'kewajiban'},
      ),
      JalurSinkron(
        nama: 'pembayaran_kewajiban',
        tabel: db.pembayaranKewajiban,
        kolomUid: db.pembayaranKewajiban.uid,
        kolomKunci: db.pembayaranKewajiban.id,
        kaitan: <String, String>{'kewajiban_id': 'kewajiban'},
      ),
      JalurSinkron(
        nama: 'kas_informal',
        tabel: db.kasInformal,
        kolomUid: db.kasInformal.uid,
        kolomKunci: db.kasInformal.id,
      ),

      // ── rumah & aset nyata ────────────────────────────────────────────────
      JalurSinkron(
        nama: 'perawatan',
        tabel: db.perawatan,
        kolomUid: db.perawatan.uid,
        kolomKunci: db.perawatan.id,
        kolomDiubah: db.perawatan.diubahPada,
        // Jadwal perawatan berkala BAWAAN (FR-83) sudah dibuat di tiap HP →
        // tidak ikut disinkronkan supaya tidak berlipat ganda.
        saring: (r) =>
            r['template_kode'] == null || '${r['template_kode']}'.isEmpty,
      ),

      // ── hidup: visi → area → tujuan → proyek → tugas ──────────────────────
      JalurSinkron(
        nama: 'visi',
        tabel: db.visi,
        kolomUid: db.visi.uid,
        kolomKunci: db.visi.id,
      ),
      JalurSinkron(
        nama: 'area_hidup',
        tabel: db.areaHidup,
        kolomUid: db.areaHidup.uid,
        kolomKunci: db.areaHidup.id,
        kaitan: <String, String>{'visi_id': 'visi'},
      ),
      JalurSinkron(
        nama: 'tujuan',
        tabel: db.tujuan,
        kolomUid: db.tujuan.uid,
        kolomKunci: db.tujuan.id,
        kaitan: <String, String>{'area_id': 'area_hidup'},
      ),
      JalurSinkron(
        nama: 'proyek',
        tabel: db.proyek,
        kolomUid: db.proyek.uid,
        kolomKunci: db.proyek.id,
        kaitan: <String, String>{'tujuan_id': 'tujuan'},
      ),
      JalurSinkron(
        nama: 'tugas',
        tabel: db.tugas,
        kolomUid: db.tugas.uid,
        kolomKunci: db.tugas.id,
        kaitan: <String, String>{
          'tujuan_id': 'tujuan',
          'proyek_id': 'proyek',
          'pemilik_id': 'anggota_keluarga',
          'penanggung_jawab_id': 'anggota_keluarga',
        },
      ),
      JalurSinkron(
        nama: 'kebiasaan',
        tabel: db.kebiasaan,
        kolomUid: db.kebiasaan.uid,
        kolomKunci: db.kebiasaan.id,
      ),
      JalurSinkron(
        nama: 'log_kebiasaan',
        tabel: db.logKebiasaan,
        kolomUid: db.logKebiasaan.uid,
        kolomKunci: db.logKebiasaan.id,
        kaitan: <String, String>{'kebiasaan_id': 'kebiasaan'},
      ),

      // ── kesehatan (mencatat, tidak menilai — PRD §7.4) ────────────────────
      JalurSinkron(
        nama: 'ukuran_tubuh',
        tabel: db.ukuranTubuh,
        kolomUid: db.ukuranTubuh.uid,
        kolomKunci: db.ukuranTubuh.id,
      ),
      JalurSinkron(
        nama: 'catatan_air',
        tabel: db.catatanAir,
        kolomUid: db.catatanAir.uid,
        kolomKunci: db.catatanAir.id,
      ),
      JalurSinkron(
        nama: 'aktivitas',
        tabel: db.aktivitas,
        kolomUid: db.aktivitas.uid,
        kolomKunci: db.aktivitas.id,
      ),
      JalurSinkron(
        nama: 'tidur',
        tabel: db.tidur,
        kolomUid: db.tidur.uid,
        kolomKunci: db.tidur.id,
      ),
      JalurSinkron(
        nama: 'catatan_kesehatan',
        tabel: db.catatanKesehatan,
        kolomUid: db.catatanKesehatan.uid,
        kolomKunci: db.catatanKesehatan.id,
      ),
      JalurSinkron(
        nama: 'janji_kesehatan',
        tabel: db.janjiKesehatan,
        kolomUid: db.janjiKesehatan.uid,
        kolomKunci: db.janjiKesehatan.id,
      ),
      JalurSinkron(
        nama: 'catatan_makan',
        tabel: db.catatanMakan,
        kolomUid: db.catatanMakan.uid,
        kolomKunci: db.catatanMakan.id,
      ),
      JalurSinkron(
        nama: 'suasana_hati',
        tabel: db.suasanaHati,
        kolomUid: db.suasanaHati.uid,
        kolomKunci: db.suasanaHati.id,
      ),

      // ── dokumen ───────────────────────────────────────────────────────────
      JalurSinkron(
        nama: 'dokumen',
        tabel: db.dokumen,
        kolomUid: db.dokumen.uid,
        kolomKunci: db.dokumen.id,
      ),

      // ── pengetahuan (FR-118…FR-123) ───────────────────────────────────────
      JalurSinkron(
        nama: 'catatan_pengetahuan',
        tabel: db.catatanPengetahuan,
        kolomUid: db.catatanPengetahuan.uid,
        kolomKunci: db.catatanPengetahuan.id,
      ),
      JalurSinkron(
        nama: 'keputusan',
        tabel: db.keputusan,
        kolomUid: db.keputusan.uid,
        kolomKunci: db.keputusan.id,
      ),
      JalurSinkron(
        nama: 'pembelajaran',
        tabel: db.pembelajaran,
        kolomUid: db.pembelajaran.uid,
        kolomKunci: db.pembelajaran.id,
      ),
      JalurSinkron(
        nama: 'kartu_ulangan',
        tabel: db.kartuUlangan,
        kolomUid: db.kartuUlangan.uid,
        kolomKunci: db.kartuUlangan.id,
      ),
      JalurSinkron(
        nama: 'bacaan',
        tabel: db.bacaan,
        kolomUid: db.bacaan.uid,
        kolomKunci: db.bacaan.id,
      ),
      JalurSinkron(
        nama: 'tautan_pengetahuan',
        tabel: db.tautanPengetahuan,
        kolomUid: db.tautanPengetahuan.uid,
        kolomKunci: db.tautanPengetahuan.id,
      ),

      // ── ibadah ────────────────────────────────────────────────────────────
      JalurSinkron(
        nama: 'hafalan',
        tabel: db.hafalan,
        kolomUid: db.hafalan.uid,
        kolomKunci: db.hafalan.id,
      ),
      JalurSinkron(
        nama: 'zakat_sedekah',
        tabel: db.zakatSedekah,
        kolomUid: db.zakatSedekah.uid,
        kolomKunci: db.zakatSedekah.id,
      ),

      // ── keluarga & kesehatan lanjutan (batch 6) ───────────────────────────
      // Anggota keluarga lebih dulu supaya kaitan pemilik/penanggung jawab pada
      // tagihan & tugas bisa dipetakan ke uid anggota di HP penerima.
      JalurSinkron(
        nama: 'anggota_keluarga',
        tabel: db.anggotaKeluarga,
        kolomUid: db.anggotaKeluarga.uid,
        kolomKunci: db.anggotaKeluarga.id,
      ),
      JalurSinkron(
        nama: 'profil_kesehatan',
        tabel: db.profilKesehatan,
        kolomUid: db.profilKesehatan.uid,
        kolomKunci: db.profilKesehatan.id,
      ),
      JalurSinkron(
        nama: 'catatan_medis',
        tabel: db.catatanMedis,
        kolomUid: db.catatanMedis.uid,
        kolomKunci: db.catatanMedis.id,
      ),

      // ── ritme hidup (batch 7) ─────────────────────────────────────────────
      JalurSinkron(
        nama: 'tinjauan_mingguan',
        tabel: db.tinjauanMingguan,
        kolomUid: db.tinjauanMingguan.uid,
        kolomKunci: db.tinjauanMingguan.id,
      ),
      JalurSinkron(
        nama: 'arsip_laporan_bulanan',
        tabel: db.arsipLaporanBulanan,
        kolomUid: db.arsipLaporanBulanan.uid,
        kolomKunci: db.arsipLaporanBulanan.id,
      ),

      // ── pintar & ibadah (batch 9) ─────────────────────────────────────────
      // Induk (rencana_ibadah) lebih dulu supaya butir persiapan bisa dipetakan
      // ke uid rencananya di HP penerima.
      JalurSinkron(
        nama: 'rencana_ibadah',
        tabel: db.rencanaIbadah,
        kolomUid: db.rencanaIbadah.uid,
        kolomKunci: db.rencanaIbadah.id,
        kolomDiubah: db.rencanaIbadah.diubahPada,
      ),
      JalurSinkron(
        nama: 'persiapan_ibadah',
        tabel: db.persiapanIbadah,
        kolomUid: db.persiapanIbadah.uid,
        kolomKunci: db.persiapanIbadah.id,
        kaitan: {'rencana_id': 'rencana_ibadah'},
      ),
    ];
