/// FR-148 — Snooze / jadwalkan ulang pengingat. **MURNI**: tanpa plugin,
/// tanpa database, tanpa tampilan — supaya bisa diuji apa adanya.
///
/// Aturan yang dipegang berkas ini:
/// 1. **Jatuh tempo asli tidak pernah berubah.** Yang bergeser hanya waktu
///    pengingat. [HasilTunda.jatuhTempoAsli] selalu dikembalikan apa adanya
///    sebagai bukti; tidak ada fungsi di sini yang menghitung ulang tanggal
///    tagihan/tugas.
/// 2. **Maksimum 3 kali tunda per pengingat** ([batasMaksimalTunda]). Sesudah
///    itu pengingat tampil sebagai "mendesak" dan tidak bisa ditunda lagi.
/// 3. **Tidak menilai pengguna** (PRD §III-11). Pesan menyebut keadaan, tanpa
///    kata yang menghakimi.
library;

import '../utils/tanggal_utils.dart';

/// Batas jumlah penundaan untuk satu pengingat.
const int batasMaksimalTunda = 3;

/// Jam untuk pilihan "besok 09:00" (waktu lokal pengguna).
const int jamBesokPagi = 9;

/// Pilihan lama tunda yang dilihat pengguna.
enum PilihanTunda {
  limaBelasMenit('15 menit', Duration(minutes: 15)),
  satuJam('1 jam', Duration(hours: 1)),
  tigaJam('3 jam', Duration(hours: 3)),
  besokSembilan('Besok 09:00', null);

  const PilihanTunda(this.label, this.jarak);

  /// Teks tombol yang siap tampil.
  final String label;

  /// Jarak tetap dari waktu sekarang; null berarti memakai aturan jam khusus
  /// ([jamBesokPagi] pada hari berikutnya).
  final Duration? jarak;
}

/// Waktu pengingat baru menurut [pilihan], dihitung dari [dari].
///
/// * 15 menit, 1 jam, 3 jam: jarak tetap dari [dari].
/// * Besok 09:00: hari berikutnya pukul [jamBesokPagi] waktu lokal.
///
/// Fungsi ini **tidak** menyentuh tanggal jatuh tempo.
DateTime hitungWaktuTunda(PilihanTunda pilihan, DateTime dari) {
  final jarak = pilihan.jarak;
  if (jarak != null) return dari.add(jarak);
  final besok = DateTime(dari.year, dari.month, dari.day)
      .add(const Duration(days: 1));
  return DateTime(besok.year, besok.month, besok.day, jamBesokPagi);
}

/// Galat aturan tunda; pesannya sudah siap tampil untuk pengguna.
class BatasTundaTerlampaui implements Exception {
  const BatasTundaTerlampaui(this.jumlahTunda);

  /// Jumlah tunda yang sudah tercatat (>= [batasMaksimalTunda]).
  final int jumlahTunda;

  String get pesan =>
      'Pengingat ini sudah ditunda $jumlahTunda kali, jadi tidak bisa ditunda '
      'lagi. Tanggal jatuh temponya tidak berubah.';

  @override
  String toString() => pesan;
}

/// Tingkat notifikasi yang dipakai setelah tunda.
///
/// Sesudah batas tercapai, pengingat tampil "mendesak" agar tetap terlihat —
/// bukan untuk menegur pengguna.
String tingkatSetelahTunda(int jumlahTunda) =>
    jumlahTunda >= batasMaksimalTunda ? 'mendesak' : 'biasa';

/// Masih boleh ditunda?
bool bolehDitundaLagi(int jumlahTunda) => jumlahTunda < batasMaksimalTunda;

/// Hasil satu kali penundaan.
class HasilTunda {
  const HasilTunda({
    required this.pengingatId,
    required this.pilihan,
    required this.dihitungPada,
    required this.waktuPengingatBaru,
    required this.waktuPengingatSebelumnya,
    required this.jatuhTempoAsli,
    required this.jumlahTunda,
    this.alasan,
  });

  final int pengingatId;
  final PilihanTunda pilihan;

  /// Waktu perhitungan (dasar pergeseran).
  final DateTime dihitungPada;

  /// Waktu pengingat yang baru (yang benar-benar dipakai menjadwalkan).
  final DateTime waktuPengingatBaru;

  /// Waktu pengingat sebelum ditunda.
  final DateTime waktuPengingatSebelumnya;

  /// **Tanggal jatuh tempo asli** (tanggal tagihan/tugas) — tidak pernah
  /// berubah oleh penundaan.
  final DateTime jatuhTempoAsli;

  /// Jumlah tunda setelah penundaan ini (1 … [batasMaksimalTunda]).
  final int jumlahTunda;

  final String? alasan;

  /// Waktu pengingat benar-benar bergeser (bukan sekadar dikembalikan sama).
  bool get pengingatBergeser =>
      waktuPengingatBaru.difference(waktuPengingatSebelumnya) != Duration.zero;

  /// Jarak pergeseran waktu pengingat.
  Duration get geser => waktuPengingatBaru.difference(waktuPengingatSebelumnya);

  /// Masih bisa ditunda lagi setelah penundaan ini?
  bool get masihBisaDitunda => bolehDitundaLagi(jumlahTunda);

  /// Tingkat yang dipakai untuk baris pengingat sesudah penundaan ini.
  String get tingkat => tingkatSetelahTunda(jumlahTunda);
}

/// Terapkan satu penundaan pengingat — **murni**, tanpa efek samping.
///
/// [jatuhTempoAsli] hanya dibaca dan dikembalikan; [waktuPengingatSekarang]
/// adalah waktu pengingat yang sedang berjalan. Melempar
/// [BatasTundaTerlampaui] bila [jumlahTundaSebelumnya] sudah mencapai
/// [batasMaksimalTunda].
HasilTunda terapkanTunda({
  required int pengingatId,
  required DateTime jatuhTempoAsli,
  required PilihanTunda pilihan,
  required int jumlahTundaSebelumnya,
  required DateTime sekarang,
  DateTime? waktuPengingatSekarang,
  String? alasan,
}) {
  if (!bolehDitundaLagi(jumlahTundaSebelumnya)) {
    throw BatasTundaTerlampaui(jumlahTundaSebelumnya);
  }
  final dasar = waktuPengingatSekarang ?? sekarang;
  return HasilTunda(
    pengingatId: pengingatId,
    pilihan: pilihan,
    dihitungPada: sekarang,
    waktuPengingatBaru: hitungWaktuTunda(pilihan, sekarang),
    waktuPengingatSebelumnya: dasar,
    jatuhTempoAsli: jatuhTempoAsli,
    jumlahTunda: jumlahTundaSebelumnya + 1,
    alasan: alasan,
  );
}

/// Kalimat ringkas siap tampil, mis.
/// "Pengingat ditunda sampai 15 September 2026 09:00".
String ringkasTunda(HasilTunda h) =>
    'Pengingat ditunda sampai ${fmtTanggalAman(h.waktuPengingatBaru)} '
    '${fmtJam(h.waktuPengingatBaru)}';

/// Kalimat yang menyebut dengan jelas bahwa jatuh tempo asli tidak bergeser.
String catatanJatuhTempoTidakBerubah(HasilTunda h) =>
    'Jatuh tempo asli tetap ${fmtTanggalAman(h.jatuhTempoAsli)} — '
    'yang bergeser hanya waktu pengingat.';
