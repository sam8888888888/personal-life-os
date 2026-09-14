/// Morning Briefing (FR-63) — penyusun isi & teks, murni tanpa Flutter.
library;

import '../utils/uang_utils.dart';
import 'model_hari_ini.dart';
import 'penyusun_hari_ini.dart';

const String teksCuacaOffline = 'Offline — cuaca tidak tersedia';
const int maksAgendaBriefing = 4;
const int maksTagihanBriefing = 3;

/// Susun isi briefing dari data yang sudah ada di perangkat.
/// [hijriah] diserahkan pemanggil karena konversi Hijriah ada di modul Ibadah.
IsiBriefing susunBriefing(
  DataHariIni data, {
  required String hijriah,
  String? sholatBerikutnya,
  DateTime? jam,
}) {
  final agenda = agendaHariIni(data.tagihan, data.sekarang);
  final tujuh = tagihanTujuhHari(data.tagihan, data.sekarang);
  var total = 0;
  for (final b in tujuh) {
    total += b.nominalSen ?? 0;
  }
  return IsiBriefing(
    sapaan: 'Assalamualaikum, ${data.namaPanggilan}',
    tanggal: data.sekarang,
    hijriah: hijriah,
    jam: jam ?? data.sekarang,
    agenda: peringkatEnamBaris(agenda, maks: maksAgendaBriefing),
    tagihanTujuhHari: peringkatEnamBaris(tujuh, maks: maksTagihanBriefing),
    totalTagihanSen: total,
    sholatBerikutnya: sholatBerikutnya,
    cuaca: data.cuaca,
    sumberCuaca: data.sumberCuaca,
    daring: data.daring,
  );
}

/// Sesuaikan isi briefing dengan keadaan jaringan (§6.4 rancangan):
/// saat offline blok cuaca dihilangkan, bukan ditampilkan sebagai angka lama.
IsiBriefing disesuaikanJaringan(IsiBriefing isi, {required bool daring}) => IsiBriefing(
      sapaan: isi.sapaan,
      tanggal: isi.tanggal,
      hijriah: isi.hijriah,
      jam: isi.jam,
      agenda: isi.agenda,
      tagihanTujuhHari: isi.tagihanTujuhHari,
      totalTagihanSen: isi.totalTagihanSen,
      sholatBerikutnya: isi.sholatBerikutnya,
      cuaca: daring ? isi.cuaca : null,
      sumberCuaca: daring ? isi.sumberCuaca : '',
      daring: daring,
    );

/// Baris teks briefing (dipakai layar, notifikasi, dan uji).
/// Tidak ada kalimat menakut-nakuti dan tidak ada angka yang bukan milik pengguna.
List<String> barisBriefing(IsiBriefing isi, {required bool daring}) {
  final i = disesuaikanJaringan(isi, daring: daring);
  final baris = <String>[
    i.sapaan,
    '${fmtTanggalSingkatAman(i.tanggal)} · ${i.hijriah}',
  ];

  if (i.agenda.isEmpty) {
    baris.add('Agenda hari ini: belum ada butir');
  } else {
    baris.add('Agenda hari ini (${i.agenda.length})');
    for (final b in i.agenda) {
      baris.add('- ${b.judul} · ${b.alasan}');
    }
  }

  if (i.tagihanTujuhHari.isEmpty) {
    baris.add('Tagihan 7 hari ke depan: belum ada');
  } else {
    baris.add('Tagihan 7 hari ke depan (${i.tagihanTujuhHari.length})'
        ' · total ${fmtRpDariSen(i.totalTagihanSen)}');
    for (final b in i.tagihanTujuhHari) {
      baris.add('- ${b.judul} · ${b.alasan}');
    }
  }

  if (i.sholatBerikutnya != null) {
    baris.add('Waktu sholat berikutnya: ${i.sholatBerikutnya}');
  }

  if (daring) {
    if (i.cuaca != null && i.cuaca!.isNotEmpty) {
      baris.add('Cuaca: ${i.cuaca}${i.sumberCuaca.isEmpty ? '' : ' (${i.sumberCuaca})'}');
    }
  } else {
    baris.add(teksCuacaOffline);
  }
  return baris;
}

/// Teks satu blok untuk notifikasi/kalimat ringkas.
String teksBriefingRingkas(IsiBriefing isi, {required bool daring}) =>
    barisBriefing(isi, daring: daring).join('\n');

/// Tanggal singkat Indonesia tanpa intl: "Sen, 14 Sep 2026".
String fmtTanggalSingkatAman(DateTime t) {
  const hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Ahd'];
  return '${hari[t.weekday - 1]}, ${tanggalSingkat(t)} ${t.year}';
}
