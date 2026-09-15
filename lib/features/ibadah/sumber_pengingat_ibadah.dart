/// Adaptor pengingat ibadah — penghubung modul Ibadah ke jadwal notifikasi
/// (FR-63 ringkasan pagi, FR-87 pengingat waktu sholat).
///
/// **Cara kerja:** kerangka notifikasi (`lib/core/notifikasi/**`) hanya tahu
/// tagihan. Modul Ibadah menyerahkan pengingatnya lewat
/// [SumberPengingatTambahan]; adaptor ini satu-satunya jembatannya.
///
/// **Kenapa tagihan dibaca lagi di sini:** isi ringkasan pagi harus menyebut
/// jumlah & total tagihan 7 hari ke depan yang NYATA. Perencana hanya bisa
/// menghitungnya kalau diberi daftar tagihan. Karena itu daftar tagihan
/// diserahkan ke perencana, lalu pengingat berkanal tagihan **dibuang** dari
/// hasil — pengingat itu sudah dibuat sekali oleh penyinkron tagihan. Aturan
/// "jangan sampai pengingat dobel" diuji di `test/pengingat_ibadah_test.dart`.
///
/// **Batas yang jujur:** jam sholat untuk 7 hari ke depan memakai perhitungan
/// hari ini. Pergeseran matahari mengubah waktu sekitar 0–1 menit per hari,
/// jadi hari terjauh bisa berbeda beberapa menit. Jadwal dihitung ulang setiap
/// aplikasi dibuka dan oleh pekerja latar.
library;

import '../../core/ibadah/model_sholat.dart';
import '../../core/ibadah/penghitung_sholat.dart';
import '../../core/ibadah/penyimpanan_jadwal.dart';
import '../../core/notifikasi/model_pengingat.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../core/notifikasi/sumber_pengingat_tambahan.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/pengaturan_repository.dart';
import '../../data/repository/tagihan_repository.dart';
import 'pengaturan_ibadah.dart';

/// Cara membuka basis data (bisa diganti saat pengujian).
typedef PembukaBasisData = AppDatabase Function();

/// Sumber pengingat tambahan milik modul Ibadah.
class SumberPengingatIbadah implements SumberPengingatTambahan {
  SumberPengingatIbadah({
    PembukaBasisData? pembukaBasisData,
    this.tutupBasisData = true,
    PenyimpananJadwal? penyimpananJadwal,
    this.perencana = const PerencanaPengingat(sertakanRingkasanMingguan: false),
    DateTime Function()? jamSekarang,
  })  : _buka = pembukaBasisData ?? AppDatabase.new,
        _penyimpanan = penyimpananJadwal ?? PenyimpananJadwal(),
        _jamSekarang = jamSekarang ?? waktuSekarang;

  final PembukaBasisData _buka;

  /// Tutup basis data setelah dipakai (pekerja latar: ya; pengujian: tidak).
  final bool tutupBasisData;

  final PenyimpananJadwal _penyimpanan;
  final PerencanaPengingat perencana;
  final DateTime Function() _jamSekarang;

  @override
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang) async {
    final AppDatabase db = _buka();
    try {
      final PengaturanIbadah setelan =
          PengaturanIbadah.dariRepository(PengaturanRepository(db));
      final bool briefing = await setelan.briefingAktif();
      final bool sholat = await setelan.pengingatSholatAktif();
      // Kedua saklar mati: tidak ada satu pun pengingat tambahan. Tidak perlu
      // membaca tagihan/jadwal sama sekali.
      if (!briefing && !sholat) return const <Pengingat>[];

      final List<JadwalPengingatSholat> jadwalSholat =
          sholat ? await _jadwalSholatHariIni(sekarang, setelan) : const [];
      final String jamBriefing = await setelan.jamBriefing();
      final List<TagihanData> tagihan = await TagihanRepository(db).ambilSemua();

      final List<Pengingat> rencana = perencana.rencanakan(
        tagihan: tagihan,
        sekarang: sekarang,
        sertakanBriefingPagi: briefing,
        jamBriefingPagi: jamBriefing,
        jadwalSholat: jadwalSholat,
      );

      // Hanya pengingat tambahan yang dikembalikan; pengingat tagihan sudah
      // dipasang oleh penyinkron tagihan (mencegah notifikasi dobel).
      return rencana
          .where((Pengingat p) =>
              p.kanal == KanalNotifikasi.briefing ||
              p.kanal == KanalNotifikasi.sholat)
          .toList(growable: false);
    } finally {
      if (tutupBasisData) await db.close();
    }
  }

  /// Lima waktu sholat hari ini menurut setelan pengguna.
  ///
  /// Cache `PenyimpananJadwal` dipakai lebih dulu supaya hitung ulang tidak
  /// perlu; bila belum ada, dihitung lalu dikembalikan (tanpa menulis berkas —
  /// penulisan tetap tugas layar Jadwal Sholat).
  Future<List<JadwalPengingatSholat>> _jadwalSholatHariIni(
    DateTime sekarang,
    PengaturanIbadah setelan,
  ) async {
    final KotaSholat kota = await setelan.kota();
    final MetodeHitungSholat metode = await setelan.metode();
    final bool hanafi = await setelan.asharHanafi();
    final int ihtiyati = await setelan.ihtiyatiMenit();
    final Map<WaktuSholat, int> koreksi = <WaktuSholat, int>{
      for (final WaktuSholat w in WaktuSholat.values) w: ihtiyati,
    };
    final DateTime hariIni =
        DateTime.utc(sekarang.year, sekarang.month, sekarang.day);

    JadwalSholatHarian? jadwal;
    try {
      jadwal = await _penyimpanan.ambil(
        tanggal: hariIni,
        kota: kota,
        kodeMetode: metode.kode,
        asharHanafi: hanafi,
        koreksiMenit: koreksi,
      );
    } catch (_) {
      jadwal = null; // cache tidak wajib; hitung sendiri di bawah
    }
    jadwal ??= hitungJadwal(
      kota: kota,
      tanggal: hariIni,
      metode: metode,
      asharHanafi: hanafi,
      koreksiMenit: koreksi,
    );

    final List<JadwalPengingatSholat> hasil = <JadwalPengingatSholat>[];
    for (final WaktuSholat w in WaktuSholat.wajibSaja) {
      final DateTime? jam = jadwal.waktuLokalAtauNull(w);
      if (jam == null) continue;
      hasil.add(JadwalPengingatSholat(
        nama: w.label,
        jam: teksJam(jam),
        mode: await setelan.mode(w),
        menitGeser: await setelan.geser(w),
      ));
    }
    return hasil;
  }

  /// Waktu "sekarang" menurut sumber waktu aplikasi (untuk pemanggil lain).
  DateTime sekarang() => _jamSekarang();
}
