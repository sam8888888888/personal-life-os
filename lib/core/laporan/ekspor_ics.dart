/// FR-41 — Ekspor tagihan mendatang ke kalender (.ics, bisa diimpor ke
/// Google Kalender / Apple Kalender / Outlook). Murni: tanpa I/O.
library;

import '../../data/database/database.dart';
import '../../data/model/enums.dart';
import '../utils/uang_utils.dart';
import '../utils/tanggal_utils.dart';

/// Hasil penyusunan berkas kalender.
class HasilIcs {
  const HasilIcs({
    required this.isi,
    required this.jumlahAcara,
    required this.jumlahTagihan,
  });

  final String isi;
  final int jumlahAcara;
  final int jumlahTagihan;
}

/// Ubah teks agar aman dipakai di dalam .ics (RFC 5545 §3.3.11).
String lombokIcs(String teks) => teks
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n');

/// Lipat baris panjang pada 75 oktet (RFC 5545 §3.1) — penerima kalender
/// mewajibkannya, walau banyak yang tetap toleran.
String lipatIcs(String baris) {
  const maks = 75;
  if (baris.length <= maks) return baris;
  final hasil = <String>[];
  var sisa = baris;
  hasil.add(sisa.substring(0, maks));
  sisa = sisa.substring(maks);
  while (sisa.isNotEmpty) {
    final potong = sisa.length <= maks - 1 ? sisa.length : maks - 1;
    hasil.add(' ${sisa.substring(0, potong)}');
    sisa = sisa.substring(potong);
  }
  return hasil.join('\r\n');
}

String _capWaktu(DateTime w) {
  final u = w.toUtc();
  String dua(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${dua(u.month)}${dua(u.day)}T${dua(u.hour)}'
      '${dua(u.minute)}${dua(u.second)}Z';
}

String _capTanggal(DateTime d) {
  String dua(int n) => n.toString().padLeft(2, '0');
  return '${d.year}${dua(d.month)}${dua(d.day)}';
}

/// Pengingat kalender yang dipakai: lead hari terkecil milik tagihan (minimal 1
/// hari sebelumnya), supaya jadwal kalender sejalan dengan pengingat aplikasi.
int leadKalender(TagihanData t) {
  final lead = teksKeLead(t.pengingatLeadHari).where((h) => h > 0).toList();
  if (lead.isEmpty) return 1;
  lead.sort();
  return lead.first;
}

/// Susun berkas .ics untuk tagihan mendatang dalam rentang [dari, sampai].
///
/// Tagihan berulang diperluas sesuai frekuensinya, dibatasi [batasPerTagihan]
/// acara per tagihan agar berkas tidak membengkak (bawaan 24 = 2 tahun bulanan).
HasilIcs susunIcsTagihan(
  List<TagihanData> tagihan, {
  required DateTime dari,
  required DateTime sampai,
  DateTime? dibuat,
  int batasPerTagihan = 24,
}) {
  final stempel = dibuat ?? DateTime.now();
  final baris = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Personal Life OS//Tagihan//ID',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:Tagihan Personal Life OS',
  ];

  var jumlahAcara = 0;
  var jumlahTagihan = 0;

  for (final t in tagihan) {
    if (!t.statusAktif || t.lunas) continue;
    final f = Frekuensi.dariDb(t.frekuensi);
    final acara = <DateTime>[];
    var lanjut = true;
    var jadwal = t.jatuhTempo;
    var putaran = 0;
    while (lanjut && putaran < batasPerTagihan) {
      putaran++;
      if (!jadwal.isAfter(sampai)) {
        if (!jadwal.isBefore(dari)) acara.add(jadwal);
      } else {
        break;
      }
      if (!f.berulang) break;
      final berikut = periodeBerikutnya(jadwal, f, kustomHariN: t.kustomHariN);
      // Penjaga: bila periode tidak maju (data aneh), hentikan supaya tidak
      // terjadi perulangan tanpa akhir.
      if (!berikut.isAfter(jadwal)) break;
      jadwal = berikut;
      if (jadwal.isAfter(sampai)) lanjut = false;
    }

    if (acara.isEmpty) continue;
    jumlahTagihan++;

    for (final tanggal in acara) {
      jumlahAcara++;
      final nominal = t.jumlahSen == null || t.jumlahSen == 0
          ? 'nominal belum diisi'
          : fmtRpDariSen(t.jumlahSen!);
      final isi = <String>[
        if (t.catatan != null && t.catatan!.trim().isNotEmpty)
          t.catatan!.trim(),
        'Frekuensi: ${f.nilaiDb.replaceAll('_', ' ')}',
        'Dibuat oleh Personal Life OS',
      ].join(' — ');

      final uid = 'tagihan-${t.uid ?? t.id}-${_capTanggal(tanggal)}'
          '@personal-life-os';

      baris.addAll([
        'BEGIN:VEVENT',
        'UID:$uid',
        'DTSTAMP:${_capWaktu(stempel)}',
        'DTSTART;VALUE=DATE:${_capTanggal(tanggal)}',
        'DTEND;VALUE=DATE:${_capTanggal(tanggal.add(const Duration(days: 1)))}',
        lipatIcs('SUMMARY:${lombokIcs('Bayar ${t.nama} — $nominal')}'),
        lipatIcs('DESCRIPTION:${lombokIcs(isi)}'),
        'CATEGORIES:TAGIHAN',
        'TRANSP:TRANSPARENT',
        'BEGIN:VALARM',
        'TRIGGER:-P${leadKalender(t)}D',
        'ACTION:DISPLAY',
        lipatIcs('DESCRIPTION:${lombokIcs('Pengingat bayar ${t.nama}')}'),
        'END:VALARM',
        'END:VEVENT',
      ]);
    }
  }

  baris.add('END:VCALENDAR');
  return HasilIcs(
    isi: '${baris.join('\r\n')}\r\n',
    jumlahAcara: jumlahAcara,
    jumlahTagihan: jumlahTagihan,
  );
}

/// Nama berkas bawaan (dipakai layar ekspor).
const String namaBerkasIcs = 'tagihan-personal-life-os.ics';
