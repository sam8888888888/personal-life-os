/// FR-139 — Search Everything: pencarian satu pintu lintas modul.
///
/// KEPUTUSAN RANCANGAN
/// 1. Pencarian memakai SQL `LIKE` pada kolom teks yang memang diisi pengguna
///    (nama, catatan, nomor, pemilik). Tidak ada tabel indeks pencarian
///    terpisah: datanya kecil (satu pengguna, satu perangkat), sehingga
///    pencarian langsung lebih jujur — tidak ada indeks yang bisa basi.
/// 2. Setiap tabel dibatasi jumlah barisnya ([batasPerModul]) supaya satu
///    tabel yang besar (mis. transaksi) tidak menenggelamkan modul lain.
/// 3. Pencarian TIDAK mengubah data apa pun (baca saja).
/// 4. Kata kunci pendek (1 huruf) tetap dilayani, tetapi hasil dibatasi
///    supaya layar tidak berat.
library;

import 'package:drift/drift.dart';

import '../../core/pencarian/model_hasil_cari.dart';
import '../database/database.dart';

class PencarianRepository {
  PencarianRepository(this.db);

  final AppDatabase db;

  /// Panjang minimal kata kunci yang dilayani.
  static const int panjangMinimal = 1;

  /// Batas hasil per tabel/modul.
  static const int batasPerModul = 8;

  /// Batas seluruh hasil dalam satu pencarian.
  static const int batasTotal = 80;

  /// Cari [kata] di seluruh modul. Kata kosong -> hasil kosong (bukan semua).
  Future<RingkasanCari> cari(String kata, {int? batasTotal}) async {
    final kunci = kata.trim();
    if (kunci.length < panjangMinimal) {
      return RingkasanCari(kata: kunci, hasil: const <HasilCari>[]);
    }
    final pola = '%${_lolosLike(kunci)}%';
    final batas = batasTotal ?? PencarianRepository.batasTotal;
    final hasil = <HasilCari>[];

    Future<void> tarik(
      String sql,
      ModulHasil modul, {
      required String Function(QueryRow) judul,
      required String Function(QueryRow) keterangan,
      String? Function(QueryRow)? rute,
    }) async {
      if (hasil.length >= batas) return;
      final baris = await db
          .customSelect(sql,
              variables: <Variable<Object>>[
                for (var i = 0; i < '?'.allMatches(sql).length; i++)
                  Variable<String>(pola),
              ])
          .get();
      for (final r in baris) {
        if (hasil.length >= batas) return;
        hasil.add(HasilCari(
          modul: modul,
          judul: judul(r),
          keterangan: keterangan(r),
          rute: rute?.call(r),
          idSumber: r.data['id'] is int ? r.data['id'] as int : null,
        ));
      }
    }

    final l = ' LIKE ? ESCAPE \'\\\'';

    // --- Tagihan & dokumen -------------------------------------------------
    await tarik(
      'SELECT id, nama, jenis, COALESCE(catatan, \'\') AS catatan FROM tagihan '
      'WHERE nama$l OR COALESCE(catatan, \'\')$l LIMIT $batasPerModul',
      ModulHasil.tagihan,
      judul: (r) => r.read<String>('nama'),
      keterangan: (r) =>
          r.read<String>('jenis') == 'dokumen' ? 'Dokumen' : 'Tagihan',
      rute: (_) => '/tagihan',
    );
    await tarik(
      'SELECT id, nama, COALESCE(nomor, \'\') AS nomor, '
      'COALESCE(pemilik, \'\') AS pemilik FROM dokumen '
      'WHERE nama$l OR COALESCE(nomor, \'\')$l OR COALESCE(pemilik, \'\')$l '
      'LIMIT $batasPerModul',
      ModulHasil.tagihan,
      judul: (r) => r.read<String>('nama'),
      keterangan: (r) {
        final nomor = r.read<String>('nomor');
        final pemilik = r.read<String>('pemilik');
        final bagian = <String>['Dokumen'];
        if (nomor.isNotEmpty) bagian.add('nomor $nomor');
        if (pemilik.isNotEmpty) bagian.add('milik $pemilik');
        return bagian.join(' · ');
      },
      rute: (_) => '/dokumen',
    );

    // --- Uang --------------------------------------------------------------
    await tarik(
      'SELECT id, nama FROM kategori_transaksi WHERE nama$l LIMIT $batasPerModul',
      ModulHasil.uang,
      judul: (r) => r.read<String>('nama'),
      keterangan: (_) => 'Kategori transaksi',
      rute: (_) => '/uang/transaksi',
    );
    await tarik(
      'SELECT id, COALESCE(catatan, \'\') AS catatan, tanggal FROM transaksi '
      'WHERE COALESCE(catatan, \'\')$l LIMIT $batasPerModul',
      ModulHasil.uang,
      judul: (r) => r.read<String>('catatan'),
      keterangan: (r) => 'Transaksi ${_tgl(r.read<int>('tanggal'))}',
      rute: (_) => '/uang/transaksi',
    );
    await tarik(
      'SELECT id, nama FROM langganan WHERE nama$l LIMIT $batasPerModul',
      ModulHasil.uang,
      judul: (r) => r.read<String>('nama'),
      keterangan: (_) => 'Langganan',
      rute: (_) => '/uang/langganan',
    );
    await tarik(
      'SELECT id, nama, COALESCE(institusi, \'\') AS institusi FROM aset '
      'WHERE nama$l OR COALESCE(institusi, \'\')$l LIMIT $batasPerModul',
      ModulHasil.uang,
      judul: (r) => r.read<String>('nama'),
      keterangan: (r) {
        final inst = r.read<String>('institusi');
        return inst.isEmpty ? 'Aset' : 'Aset · $inst';
      },
      rute: (_) => '/uang/kekayaan',
    );
    await tarik(
      'SELECT id, nama FROM kewajiban WHERE nama$l LIMIT $batasPerModul',
      ModulHasil.uang,
      judul: (r) => r.read<String>('nama'),
      keterangan: (_) => 'Kewajiban',
      rute: (_) => '/uang/kekayaan',
    );
    await tarik(
      'SELECT id, nama, tanggal FROM pengeluaran_terencana '
      'WHERE nama$l LIMIT $batasPerModul',
      ModulHasil.uang,
      judul: (r) => r.read<String>('nama'),
      keterangan: (r) => 'Rencana ${_tgl(r.read<int>('tanggal'))}',
      rute: (_) => '/uang/kalender',
    );

    // --- Aksi & tujuan -----------------------------------------------------
    await tarik(
      'SELECT id, nama, area FROM tujuan '
      'WHERE nama$l OR COALESCE(catatan, \'\')$l LIMIT $batasPerModul',
      ModulHasil.aksi,
      judul: (r) => r.read<String>('nama'),
      keterangan: (r) => 'Tujuan · ${r.read<String>('area')}',
      rute: (_) => '/aksi/tujuan',
    );
    await tarik(
      'SELECT id, nama FROM proyek WHERE nama$l LIMIT $batasPerModul',
      ModulHasil.aksi,
      judul: (r) => r.read<String>('nama'),
      keterangan: (_) => 'Proyek',
      rute: (_) => '/aksi/tujuan',
    );
    await tarik(
      'SELECT id, nama, COALESCE(jatuh_tempo, 0) AS jatuh_tempo FROM tugas '
      'WHERE nama$l OR COALESCE(catatan, \'\')$l LIMIT $batasPerModul',
      ModulHasil.aksi,
      judul: (r) => r.read<String>('nama'),
      keterangan: (r) {
        final jt = r.read<int>('jatuh_tempo');
        return jt == 0 ? 'Tugas' : 'Tugas · ${_tgl(jt)}';
      },
      rute: (_) => '/aksi/tugas',
    );
    await tarik(
      'SELECT id, nama FROM kebiasaan WHERE nama$l LIMIT $batasPerModul',
      ModulHasil.aksi,
      judul: (r) => r.read<String>('nama'),
      keterangan: (_) => 'Kebiasaan',
      rute: (_) => '/aksi/kebiasaan',
    );
    await tarik(
      'SELECT id, nama, berikutnya FROM perawatan '
      'WHERE nama$l OR COALESCE(catatan, \'\')$l LIMIT $batasPerModul',
      ModulHasil.aksi,
      judul: (r) => r.read<String>('nama'),
      keterangan: (r) => 'Perawatan · berikutnya ${_tgl(r.read<int>('berikutnya'))}',
      rute: (_) => '/aksi/perawatan',
    );

    // --- Kesehatan ---------------------------------------------------------
    await tarik(
      'SELECT id, nama FROM obat '
      'WHERE nama$l OR COALESCE(catatan, \'\')$l LIMIT $batasPerModul',
      ModulHasil.kesehatan,
      judul: (r) => r.read<String>('nama'),
      keterangan: (_) => 'Obat/vitamin',
      rute: (_) => '/kesehatan/obat',
    );
    await tarik(
      'SELECT id, jenis, tanggal FROM aktivitas '
      'WHERE jenis$l OR COALESCE(catatan, \'\')$l LIMIT $batasPerModul',
      ModulHasil.kesehatan,
      judul: (r) => r.read<String>('jenis'),
      keterangan: (r) => 'Aktivitas ${_tgl(r.read<int>('tanggal'))}',
      rute: (_) => '/kesehatan/aktivitas',
    );
    await tarik(
      'SELECT id, COALESCE(catatan, \'\') AS catatan, tanggal FROM ukuran_tubuh '
      'WHERE COALESCE(catatan, \'\')$l LIMIT $batasPerModul',
      ModulHasil.kesehatan,
      judul: (r) => r.read<String>('catatan'),
      keterangan: (r) => 'Catatan ukuran ${_tgl(r.read<int>('tanggal'))}',
      rute: (_) => '/kesehatan',
    );

    // --- Ibadah ------------------------------------------------------------
    await tarik(
      'SELECT id, jenis, tanggal FROM log_puasa '
      'WHERE COALESCE(catatan, \'\')$l OR jenis$l LIMIT $batasPerModul',
      ModulHasil.ibadah,
      judul: (r) => r.read<String>('jenis').replaceAll('_', ' '),
      keterangan: (r) => 'Puasa ${_tgl(r.read<int>('tanggal'))}',
      rute: (_) => '/ibadah/puasa',
    );
    await tarik(
      'SELECT id, COALESCE(bagian, \'\') AS bagian, tanggal FROM log_quran '
      'WHERE COALESCE(bagian, \'\')$l OR COALESCE(catatan, \'\')$l '
      'LIMIT $batasPerModul',
      ModulHasil.ibadah,
      judul: (r) {
        final bagian = r.read<String>('bagian');
        return bagian.isEmpty ? 'Catatan Quran' : bagian;
      },
      keterangan: (r) => 'Quran ${_tgl(r.read<int>('tanggal'))}',
      rute: (_) => '/ibadah/quran',
    );
    await tarik(
      'SELECT id, nama FROM log_dzikir '
      'WHERE nama$l OR COALESCE(catatan, \'\')$l LIMIT $batasPerModul',
      ModulHasil.ibadah,
      judul: (r) => r.read<String>('nama'),
      keterangan: (_) => 'Dzikir',
      rute: (_) => '/ibadah/dzikir',
    );
    await tarik(
      'SELECT id, COALESCE(catatan, \'\') AS catatan, tanggal '
      'FROM refleksi_muhasabah WHERE COALESCE(catatan, \'\')$l '
      'LIMIT $batasPerModul',
      ModulHasil.ibadah,
      judul: (r) => r.read<String>('catatan'),
      keterangan: (r) => 'Muhasabah ${_tgl(r.read<int>('tanggal'))}',
      rute: (_) => '/ibadah/muhasabah',
    );

    return RingkasanCari(kata: kunci, hasil: hasil);
  }

  /// Buang aksara pengubah LIKE supaya kata kunci dicari apa adanya.
  static String _lolosLike(String kata) =>
      kata.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');

  /// Drift menyimpan `dateTime()` sebagai detik Unix (INTEGER).
  static String _tgl(int detik) {
    final d = DateTime.fromMillisecondsSinceEpoch(detik * 1000);
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${dua(d.day)}/${dua(d.month)}/${d.year}';
  }
}
