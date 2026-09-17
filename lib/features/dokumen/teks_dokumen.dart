/// Kalimat & format teks modul Dokumen (FR-128) — murni, tanpa I/O.
///
/// Dipisah dari layar supaya dipakai bersama oleh daftar, form, dan pengujian
/// tanpa saling mengimpor layar.
///
/// Nada bahasa mengikuti PRD §III-11: menyebut keadaan apa adanya
/// ("berakhir 12 hari lagi", "sudah lewat 3 hari"), bukan menilai pengguna.
library;

import '../../core/utils/tanggal_utils.dart';

/// "12/09/2026" gaya isian Indonesia (dd/mm/yyyy).
String teksTanggalIsian(DateTime t) =>
    '${t.day.toString().padLeft(2, '0')}/'
    '${t.month.toString().padLeft(2, '0')}/${t.year}';

/// Kalimat masa berlaku sebuah dokumen pada saat [sekarang].
///
/// [berlakuSampai] kosong → dokumen memang belum punya tanggal berakhir.
String kalimatMasaBerlaku(DateTime? berlakuSampai, DateTime sekarang) {
  if (berlakuSampai == null) return 'Tanggal berakhir belum dicatat';
  final sisa = selisihHari(sekarang, berlakuSampai);
  if (sisa > 0) return 'Berakhir $sisa hari lagi';
  if (sisa == 0) return 'Berakhir hari ini';
  return 'Sudah lewat ${-sisa} hari';
}

/// Kalimat lengkap tanggal berakhir untuk daftar.
String kalimatTanggalBerlaku(DateTime? berlakuSampai, DateTime sekarang) {
  if (berlakuSampai == null) return 'Tanggal berakhir belum dicatat';
  return 'Berlaku sampai ${fmtTanggalId(berlakuSampai)} · '
      '${kalimatMasaBerlaku(berlakuSampai, sekarang)}';
}
