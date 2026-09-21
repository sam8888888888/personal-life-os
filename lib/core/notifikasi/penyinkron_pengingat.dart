/// Penyinkron jadwal: hitung ulang seluruh pengingat lalu pasang ke sistem.
/// Dipanggil saat aplikasi dibuka, setelah data berubah, dan dari pekerja latar.
library;

import '../../data/database/database.dart';
import '../../data/repository/tagihan_repository.dart';
import 'jejak.dart';
import 'layanan_notifikasi.dart';
import 'model_pengingat.dart';
import '../../data/repository/pengaturan_repository.dart';
import 'perencana_pengingat.dart';
import '../laporan/pola_bayar.dart';
import 'sumber_pengingat_tambahan.dart';

class HasilSinkron {
  const HasilSinkron({
    required this.jumlahTerjadwal,
    required this.jumlahPengingatLead,
    required this.jumlahTerlambat,
    required this.waktu,
    this.jumlahTambahan = 0,
    this.galatSumberTambahan = const [],
    this.galat,
  });

  final int jumlahTerjadwal;
  final int jumlahPengingatLead;
  final int jumlahTerlambat;
  final DateTime waktu;

  /// FR-63/FR-87: berapa pengingat yang datang dari sumber tambahan
  /// (briefing pagi, pengingat sholat) — dipisahkan supaya jelas.
  final int jumlahTambahan;

  /// Galat dari sumber tambahan (kosong = tidak ada). Sinkronisasi tagihan
  /// tetap dianggap berhasil; ini hanya jejak agar tidak ada kegagalan senyap.
  final List<String> galatSumberTambahan;

  final String? galat;

  bool get berhasil => galat == null;

  @override
  String toString() => 'HasilSinkron(terjadwal=$jumlahTerjadwal, '
      'lead=$jumlahPengingatLead, terlambat=$jumlahTerlambat, '
      'tambahan=$jumlahTambahan'
      '${galatSumberTambahan.isEmpty ? '' : ', galat tambahan=$galatSumberTambahan'}, '
      'galat=$galat)';
}

/// FR-17: saklar "pengingat menyesuaikan pola" (disimpan apa adanya 'true').
const String kunciPengingatPintar = 'pengingat_pintar';

class PenyinkronPengingat {
  const PenyinkronPengingat({
    required this.repo,
    required this.layanan,
    this.perencana = const PerencanaPengingat(),
    this.sumberTambahan,
  });

  final TagihanRepository repo;
  final LayananNotifikasi layanan;
  final PerencanaPengingat perencana;

  /// Sumber pengingat tambahan (FR-63 briefing pagi, FR-87 pengingat sholat).
  ///
  /// `null` (bawaan) = pakai [RegistriSumberPengingat] — modul fitur mendaftar
  /// sendiri lewat `RegistriSumberPengingat.daftarkan(...)`. Daftar eksplisit
  /// dipakai pengujian dan pemanggil yang ingin menyalurkan sumbernya langsung.
  final List<SumberPengingatTambahan>? sumberTambahan;

  /// Kumpulkan pengingat dari sumber tambahan (registri atau daftar eksplisit).
  Future<List<Pengingat>> _pengingatTambahan(
      DateTime kini, List<String> galat) async {
    return RegistriSumberPengingat.kumpulkan(
      kini,
      sumber: sumberTambahan,
      catatGalat: galat.add,
    );
  }

  /// Hitung & pasang jadwal. Tidak melempar: kegagalan dikembalikan di [HasilSinkron].
  ///
  /// PB-09 tetap berlaku: jumlah rencana diverifikasi ke sistem oleh layanan
  /// ([LayananNotifikasi.hasilPasangTerakhir]), bukan dianggap berhasil.
  Future<HasilSinkron> sinkron({DateTime? sekarang}) async {
    final kini = sekarang ?? DateTime.now();
    final galatTambahan = <String>[];
    try {
      final semua = await repo.ambilSemua();
      final tambahan = await _pengingatTambahan(kini, galatTambahan);
      final petaPintar = await _leadPintar(semua);
      final daftar = <Pengingat>[
        ...perencana.rencanakan(tagihan: semua, sekarang: kini,
            leadPintar: petaPintar),
        ...tambahan,
      ]..sort((a, b) => a.waktu.compareTo(b.waktu));
      await layanan.pasangJadwal(daftar);
      final hasil = HasilSinkron(
        jumlahTerjadwal: daftar.length,
        jumlahPengingatLead: daftar
            .where((p) => p.kanal == KanalNotifikasi.tagihan)
            .length,
        jumlahTerlambat: daftar.where((p) => p.terlambat).length,
        jumlahTambahan: tambahan.length,
        galatSumberTambahan: List.unmodifiable(galatTambahan),
        waktu: kini,
      );
      await catatJejak({
        'jenis': 'sinkron',
        'terjadwal': hasil.jumlahTerjadwal,
        'lead': hasil.jumlahPengingatLead,
        'terlambat': hasil.jumlahTerlambat,
        'tambahan': hasil.jumlahTambahan,
        if (galatTambahan.isNotEmpty) 'galatSumberTambahan': galatTambahan,
      });
      return hasil;
    } catch (e) {
      final hasil = HasilSinkron(
        jumlahTerjadwal: 0,
        jumlahPengingatLead: 0,
        jumlahTerlambat: 0,
        galatSumberTambahan: List.unmodifiable(galatTambahan),
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
    final galat = <String>[];
    final tambahan = await _pengingatTambahan(kini, galat);
    final petaPintar = await _leadPintar(semua);
    final daftar = <Pengingat>[
      ...perencana.rencanakan(tagihan: semua, sekarang: kini,
          leadPintar: petaPintar),
      ...tambahan,
    ]..sort((a, b) => a.waktu.compareTo(b.waktu));
    return daftar.take(maks).toList(growable: false);
  }

  /// FR-17: peta tagihanId → lead hari kebiasaan membayar.
  ///
  /// Kosong bila saklar "pengingat menyesuaikan pola" belum dinyalakan, atau
  /// bila pola pembayarannya belum cukup kuat (lihat PolaBayar.cukupBukti).
  Future<Map<int, int>> _leadPintar(List<TagihanData> tagihan) async {
    try {
      final menyala = await PengaturanRepository(repo.db)
          .bacaSaklar(kunciPengingatPintar);
      if (!menyala) return const {};
      final riwayat = await repo.riwayatDenganId();
      final pola = hitungPolaBayar([
        for (final r in riwayat)
          CatatanBayar(
            tagihanId: r.tagihanId,
            namaTagihan: r.nama,
            tanggalBayar: r.tanggalBayar,
            jatuhTempoPeriode: r.periode,
          ),
      ]);
      return leadPintarDariPola(pola,
          tagihanAktif: {
            for (final t in tagihan)
              if (t.statusAktif && !t.lunas) t.id,
          });
    } catch (_) {
      // Pembelajaran pola tidak boleh menggagalkan penjadwalan pengingat.
      return const {};
    }
  }
}
