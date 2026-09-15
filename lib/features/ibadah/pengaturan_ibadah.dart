/// Setelan ibadah yang dipakai bersama oleh layar & adaptor pengingat.
///
/// **Kenapa satu berkas:** kunci penyimpanan (tabel `pengaturan`, kunci-nilai)
/// harus sama persis antara layar Pengingat Ibadah, adaptor pengingat, dan
/// layar Jadwal Sholat. Menulis kunci di dua tempat pernah jadi sumber salah
/// baca; di sini kunci hanya didefinisikan sekali.
library;

import '../../core/ibadah/kota_indonesia.dart';
import '../../core/ibadah/model_sholat.dart';
import '../../core/ibadah/penghitung_sholat.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../data/repository/pengaturan_repository.dart';

/// FR-63: ringkasan pagi aktif/mati.
const String kunciBriefingPagi = 'briefing.pagi';

/// FR-63: jam ringkasan pagi, bentuk `HH:mm`.
const String kunciJamBriefing = 'briefing.jam';

/// FR-87: pengingat waktu sholat aktif/mati.
const String kunciPengingatSholat = 'sholat.pengingat.aktif';

/// FR-86: kota yang dipakai menghitung jadwal.
const String kunciKotaSholat = 'sholat.kota';

/// FR-86: metode perhitungan (kode, lihat [MetodeHitungSholat.kode]).
const String kunciMetodeSholat = 'sholat.metode';

/// FR-86: Ashar menurut madzhab Hanafi.
const String kunciAsharHanafi = 'sholat.ashar.hanafi';

/// FR-86: koreksi ihtiyati (menit) untuk semua waktu.
const String kunciIhtiyatiSholat = 'sholat.ihtiyati';

/// Kunci mode pengingat satu waktu sholat (FR-87).
String kunciModeSholat(WaktuSholat w) => 'sholat.${w.name}.mode';

/// Kunci geser menit pengingat satu waktu sholat (FR-87).
String kunciGeserSholat(WaktuSholat w) => 'sholat.${w.name}.geser';

/// Kota bawaan bila pengguna belum memilih (sama dengan layar Jadwal Sholat).
const String kotaSholatBawaan = 'Jakarta';

/// Menit ihtiyati tertinggi yang ditawarkan antarmuka.
const int ihtiyatiMaksimal = 3;

/// Menit ihtiyati terendah (koreksi boleh maju) — layar Jadwal Sholat
/// menawarkan -3..+3, jadi simpanan harus menerima nilai negatif juga.
const int ihtiyatiMinimal = -3;

/// Menit geser tertinggi yang ditawarkan antarmuka (batas rencana: 120).
const int geserMaksimal = 120;

/// Ubah [DateTime] menjadi teks `HH:mm` (angka jam/menit apa adanya).
String teksJam(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Apakah teks berbentuk jam `HH:mm` yang sah?
bool jamSah(String? teks) {
  if (teks == null) return false;
  final List<String> bagian = teks.trim().split(':');
  if (bagian.length != 2) return false;
  final int? j = int.tryParse(bagian[0]);
  final int? m = int.tryParse(bagian[1]);
  if (j == null || m == null) return false;
  return j >= 0 && j <= 23 && m >= 0 && m <= 59;
}

/// Kontrak penyimpanan kunci-nilai setelan.
///
/// Dipisahkan dari [PengaturanRepository] supaya pengujian layar bisa memakai
/// penyimpanan sederhana di memori (tanpa basis data) — dan supaya modul ini
/// tidak bergantung pada rincian lapisan data.
abstract class PenyimpananSetelan {
  Future<String?> baca(String kunci);
  Future<void> simpan(String kunci, String nilai);
  Future<String> bacaTeks(String kunci, String bawaan);
  Future<int> bacaAngka(String kunci, int bawaan);
  Future<bool> bacaSaklar(String kunci, {bool bawaan});
}

/// Penyimpanan setelan memakai tabel `pengaturan` di basis data aplikasi.
class SetelanBasisData implements PenyimpananSetelan {
  SetelanBasisData(this.repo);

  final PengaturanRepository repo;

  @override
  Future<String?> baca(String kunci) => repo.baca(kunci);

  @override
  Future<void> simpan(String kunci, String nilai) => repo.simpan(kunci, nilai);

  @override
  Future<String> bacaTeks(String kunci, String bawaan) =>
      repo.bacaTeks(kunci, bawaan);

  @override
  Future<int> bacaAngka(String kunci, int bawaan) =>
      repo.bacaAngka(kunci, bawaan);

  @override
  Future<bool> bacaSaklar(String kunci, {bool bawaan = false}) =>
      repo.bacaSaklar(kunci, bawaan: bawaan);
}

/// Setelan ibadah: pembungkus tipis di atas penyimpanan kunci-nilai.
///
/// Semua nilai punya bawaan yang aman; isi yang hilang atau tidak sah tidak
/// pernah menghasilkan galat, hanya kembali ke bawaan.
class PengaturanIbadah {
  PengaturanIbadah(this.simpanan);

  /// Setelan pada basis data aplikasi (jalur normal aplikasi).
  PengaturanIbadah.dariRepository(PengaturanRepository repo)
      : simpanan = SetelanBasisData(repo);

  final PenyimpananSetelan simpanan;

  // --- FR-63 ringkasan pagi ------------------------------------------------

  /// Bawaan **aktif**: ringkasan pagi adalah janji fitur V1.5 dan terbatas
  /// satu kali sehari (PRD III-11: notifikasi tidak boleh tak terbatas).
  Future<bool> briefingAktif() =>
      simpanan.bacaSaklar(kunciBriefingPagi, bawaan: true);

  Future<void> simpanBriefingAktif(bool aktif) =>
      simpanan.simpan(kunciBriefingPagi, aktif ? 'true' : 'false');

  Future<String> jamBriefing() async {
    final String teks = await simpanan.bacaTeks(kunciJamBriefing, jamBriefingBawaan);
    return jamSah(teks) ? teks : jamBriefingBawaan;
  }

  Future<void> simpanJamBriefing(String jam) => simpanan.simpan(
      kunciJamBriefing, jamSah(jam) ? jam : jamBriefingBawaan);

  // --- FR-87 pengingat waktu sholat ---------------------------------------

  /// Bawaan **mati**: pengingat sholat berbunyi 5 kali sehari, jadi harus
  /// dinyalakan sendiri oleh pengguna.
  Future<bool> pengingatSholatAktif() => simpanan.bacaSaklar(kunciPengingatSholat);

  Future<void> simpanPengingatSholatAktif(bool aktif) =>
      simpanan.simpan(kunciPengingatSholat, aktif ? 'true' : 'false');

  Future<ModePengingatSholat> mode(WaktuSholat w) async =>
      ModePengingatSholat.dariDb(await simpanan.baca(kunciModeSholat(w)));

  Future<void> simpanMode(WaktuSholat w, ModePengingatSholat m) =>
      simpanan.simpan(kunciModeSholat(w), m.nilaiDb);

  Future<int> geser(WaktuSholat w) async {
    final int menit = await simpanan.bacaAngka(kunciGeserSholat(w), 0);
    return menit < 0 ? 0 : (menit > geserMaksimal ? geserMaksimal : menit);
  }

  Future<void> simpanGeser(WaktuSholat w, int menit) => simpanan.simpan(
      kunciGeserSholat(w), '${menit < 0 ? 0 : (menit > geserMaksimal ? geserMaksimal : menit)}');

  // --- FR-86 kota & cara hitung -------------------------------------------

  Future<String> namaKota() =>
      simpanan.bacaTeks(kunciKotaSholat, kotaSholatBawaan);

  Future<KotaSholat> kota() async {
    final String nama = await namaKota();
    return daftarKotaIndonesia.firstWhere(
      (KotaSholat k) => k.nama == nama,
      orElse: () => daftarKotaIndonesia.firstWhere(
          (KotaSholat k) => k.nama == kotaSholatBawaan),
    );
  }

  Future<void> simpanKota(KotaSholat k) => simpanan.simpan(kunciKotaSholat, k.nama);

  Future<MetodeHitungSholat> metode() async =>
      MetodeHitungSholat.dariKode(await simpanan.bacaTeks(kunciMetodeSholat,
          MetodeHitungSholat.kemenag.kode));

  Future<void> simpanMetode(MetodeHitungSholat m) =>
      simpanan.simpan(kunciMetodeSholat, m.kode);

  Future<bool> asharHanafi() => simpanan.bacaSaklar(kunciAsharHanafi);

  Future<void> simpanAsharHanafi(bool hanafi) =>
      simpanan.simpan(kunciAsharHanafi, hanafi ? 'true' : 'false');

  Future<int> ihtiyatiMenit() async =>
      _batasiIhtiyati(await simpanan.bacaAngka(kunciIhtiyatiSholat, 0));

  Future<void> simpanIhtiyatiMenit(int menit) =>
      simpanan.simpan(kunciIhtiyatiSholat, '${_batasiIhtiyati(menit)}');

  static int _batasiIhtiyati(int menit) => menit < ihtiyatiMinimal
      ? ihtiyatiMinimal
      : (menit > ihtiyatiMaksimal ? ihtiyatiMaksimal : menit);
}
