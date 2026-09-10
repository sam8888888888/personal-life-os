/// Penyinkron jadwal: hitung ulang seluruh pengingat lalu pasang ke sistem.
/// Dipanggil saat aplikasi dibuka, setelah data berubah, dan dari pekerja latar.
library;

import '../../data/repository/tagihan_repository.dart';
import 'jejak.dart';
import 'layanan_notifikasi.dart';
import 'model_pengingat.dart';
import 'perencana_pengingat.dart';

class HasilSinkron {
  const HasilSinkron({
    required this.jumlahTerjadwal,
    required this.jumlahPengingatLead,
    required this.jumlahTerlambat,
    required this.waktu,
    this.galat,
  });

  final int jumlahTerjadwal;
  final int jumlahPengingatLead;
  final int jumlahTerlambat;
  final DateTime waktu;
  final String? galat;

  bool get berhasil => galat == null;

  @override
  String toString() => 'HasilSinkron(terjadwal=$jumlahTerjadwal, '
      'lead=$jumlahPengingatLead, terlambat=$jumlahTerlambat, galat=$galat)';
}

class PenyinkronPengingat {
  const PenyinkronPengingat({
    required this.repo,
    required this.layanan,
    this.perencana = const PerencanaPengingat(),
  });

  final TagihanRepository repo;
  final LayananNotifikasi layanan;
  final PerencanaPengingat perencana;

  /// Hitung & pasang jadwal. Tidak melempar: kegagalan dikembalikan di [HasilSinkron].
  Future<HasilSinkron> sinkron({DateTime? sekarang}) async {
    final kini = sekarang ?? DateTime.now();
    try {
      final semua = await repo.ambilSemua();
      final daftar = perencana.rencanakan(tagihan: semua, sekarang: kini);
      await layanan.pasangJadwal(daftar);
      final hasil = HasilSinkron(
        jumlahTerjadwal: daftar.length,
        jumlahPengingatLead: daftar
            .where((p) => p.kanal == KanalNotifikasi.tagihan)
            .length,
        jumlahTerlambat: daftar.where((p) => p.terlambat).length,
        waktu: kini,
      );
      await catatJejak({
        'jenis': 'sinkron',
        'terjadwal': hasil.jumlahTerjadwal,
        'lead': hasil.jumlahPengingatLead,
        'terlambat': hasil.jumlahTerlambat,
      });
      return hasil;
    } catch (e) {
      final hasil = HasilSinkron(
        jumlahTerjadwal: 0,
        jumlahPengingatLead: 0,
        jumlahTerlambat: 0,
        waktu: kini,
        galat: '$e',
      );
      await catatJejak({'jenis': 'sinkron', 'galat': hasil.galat});
      return hasil;
    }
  }

  /// Daftar pengingat berikutnya (untuk ditampilkan di layar Pengingat).
  Future<List<Pengingat>> pratinjau({DateTime? sekarang, int maks = 20}) async {
    final kini = sekarang ?? DateTime.now();
    final semua = await repo.ambilSemua();
    final daftar = perencana.rencanakan(tagihan: semua, sekarang: kini);
    return daftar.take(maks).toList(growable: false);
  }
}
