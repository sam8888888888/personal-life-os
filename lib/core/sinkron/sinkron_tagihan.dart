/// Sinkron TAGIHAN antar HP (FR-150, tahap 2) — irisan pertama.
///
/// Cara kerja (bisa dijelaskan singkat):
/// 1. Setiap perubahan lokal (tambah/ubah/hapus) mencatatkan **penanda** di
///    tabel `sinkron_kotor` — jadi tidak ada perubahan yang bergantung pada
///    perbandingan waktu (yang pernah membuat baris terhapus hidup kembali).
/// 2. Semua penanda dikirim ke server; diterima = penanda dibersihkan.
/// 3. Server mengembalikan perubahan yang belum pernah dilihat perangkat ini
///    (lewat nomor revisi), diterapkan dengan mencocokkan **uid** — bukan id
///    angka — sehingga dua HP tidak saling menimpa.
/// 4. Sisa baris yang berubah (jalur ubah lain, mis. lunas/nonaktifkan) ikut
///    disisir sebagai jaring pengaman.
///
/// Batas yang Ron sadari: baru tabel TAGIHAN. Riwayat pembayaran, kategori,
/// dan tabel lain menyusul dengan pola yang sama.
library;

import 'package:drift/drift.dart';

import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';
import '../../data/repository/tagihan_repository.dart';
import '../akun/klien_akun.dart';

/// Ringkasan hasil satu kali sinkron (untuk ditampilkan ke pengguna).
class HasilSinkron {
  const HasilSinkron({
    required this.dikirim,
    required this.diterapkan,
    required this.konflik,
    required this.pesan,
  });

  final int dikirim;
  final int diterapkan;
  final int konflik;
  final String pesan;

  @override
  String toString() => pesan;
}

class SinkronTagihan {
  SinkronTagihan({
    required this.db,
    required this.tagihan,
    required this.pengaturan,
    required this.klien,
  });

  final AppDatabase db;
  final TagihanRepository tagihan;
  final PengaturanRepository pengaturan;
  final KlienAkun klien;

  static const String namaTabel = 'tagihan';
  static const String kunciRevisi = 'sinkron_revisi';
  static const String kunciDorong = 'sinkron_dorong_tagihan';

  Future<HasilSinkron> jalan({required String token}) async {
    final sejak = int.tryParse(await pengaturan.baca(kunciRevisi) ?? '') ?? 0;

    final baris = await tagihan.semuaUntukSinkron();
    final perUid = <String, TagihanData>{
      for (final b in baris)
        if (b.uid != null) b.uid!: b,
    };

    // 1. Semua penanda kotor (tambah/ubah/hapus) — tanpa saringan waktu.
    final penanda = await (db.select(db.sinkronKotor)
          ..where((k) => k.tabel.equals(namaTabel)))
        .get();

    final perubahan = <Map<String, dynamic>>[];
    final terkirim = <String>{};

    for (final k in penanda) {
      final barisnya = perUid[k.uid];
      final hapus = k.hapus || barisnya == null;
      final waktu = hapus ? k.waktu : barisnya!.diubahPada;
      perubahan.add({
        'tabel': namaTabel,
        'id_lokal': k.uid,
        'waktu_klien': waktu.toUtc().toIso8601String(),
        'dihapus': hapus,
        'isi': hapus ? const <String, dynamic>{} : TagihanRepository.kePeta(barisnya),
      });
      terkirim.add(k.uid);
    }

    // 3. Kirim & tarik.
    final jawab = await klien.sinkron(
      token: token,
      sejak: sejak,
      perubahan: perubahan,
    );

    // 4. Terapkan perubahan dari server (cocok lewat uid).
    final tarikan = (jawab['perubahan'] as List?) ?? const [];
    var diterapkan = 0;
    for (final butir in tarikan) {
      final peta = (butir as Map).cast<String, dynamic>();
      final uid = peta['id_lokal'] as String?;
      if (uid == null || uid.isEmpty) continue;
      await tagihan.terapDariServer(
        uid: uid,
        isi: (peta['isi'] as Map?)?.cast<String, dynamic>() ?? const {},
        waktu: DateTime.tryParse(peta['waktu_klien'] as String? ?? '') ??
            DateTime.now(),
        dihapus: peta['dihapus'] == true,
      );
      diterapkan++;
    }

    // 5. Kursor + bersihkan penanda yang sudah diterima server.
    final revisi = (jawab['revisi'] as num?)?.toInt() ?? sejak;
    await pengaturan.simpan(kunciRevisi, '$revisi');
    // Tandai waktu sinkron terakhir (dipakai layar untuk menampilkan keadaan).
    await pengaturan.simpan(kunciDorong, DateTime.now().toIso8601String());
    for (final uid in terkirim) {
      await (db.delete(db.sinkronKotor)
            ..where((k) => k.tabel.equals(namaTabel) & k.uid.equals(uid)))
          .go();
    }

    final konflik = (jawab['konflik'] as num?)?.toInt() ?? 0;
    return HasilSinkron(
      dikirim: perubahan.length,
      diterapkan: diterapkan,
      konflik: konflik,
      pesan: perubahan.isEmpty && diterapkan == 0
          ? 'Sudah sama di semua HP.'
          : 'Terkirim ${perubahan.length} · diterima $diterapkan'
              '${konflik > 0 ? ' · $konflik bentrok (versi lama disimpan di server)' : ''}',
    );
  }
}
