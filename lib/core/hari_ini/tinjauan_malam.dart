/// FR-64 — Tinjauan malam ("Evening Review"). **MURNI**: tanpa basis data.
///
/// Isi mengikuti PRD: apa yang selesai hari ini, apa yang belum, dan **satu
/// pertanyaan refleksi**. Nada bahasa bebas kata menghakimi (PRD §III-11):
/// yang belum tercatat disebut "belum", bukan "gagal".
library;

import 'package:intl/intl.dart';

/// Judul + nominal ringkas untuk daftar tinjauan.
class JudulNominal {
  const JudulNominal({required this.judul, this.nominalSen});

  final String judul;
  final int? nominalSen;
}

/// Satu baris hasil tinjauan.
class BarisTinjauan {
  const BarisTinjauan({
    required this.judul,
    required this.keterangan,
    this.selesai = false,
  });

  final String judul;
  final String keterangan;
  final bool selesai;
}

/// Kebiasaan yang dipromosikan ke Today beserta statusnya hari ini.
class KebiasaanHariIni {
  const KebiasaanHariIni({required this.nama, required this.ditandai});

  final String nama;
  final bool ditandai;
}

/// Isi tinjauan satu hari.
class IsiTinjauanMalam {
  const IsiTinjauanMalam({
    required this.tanggal,
    required this.pertanyaan,
    required this.selesai,
    required this.belum,
  });

  final DateTime tanggal;
  final String pertanyaan;
  final List<BarisTinjauan> selesai;
  final List<BarisTinjauan> belum;

  int get jumlahSelesai => selesai.length;
  int get jumlahBelum => belum.length;

  /// Ada sesuatu untuk dibaca? Kalau tidak, layar tetap jujur menyebut kosong.
  bool get adaIsi => selesai.isNotEmpty || belum.isNotEmpty;
}

/// Pertanyaan refleksi yang berputar per hari.
///
/// Sengaja lima pertanyaan pendek yang tidak menilai, supaya pengguna tidak
/// mendapat pertanyaan yang sama terus-menerus.
const List<String> daftarPertanyaanMalam = [
  'Satu hal apa yang hari ini terasa melegakan?',
  'Apa yang bisa dibuat lebih ringan besok?',
  'Apa satu hal kecil yang cukup dikerjakan besok?',
  'Apa yang berjalan lebih lancar dibanding hari kemarin?',
  'Siapa yang perlu Anda kabari besok?',
];

/// Pertanyaan untuk [hari] — berputar menurut urutan hari dalam setahun.
String pertanyaanMalam(DateTime hari) {
  final awalTahun = DateTime(hari.year, 1, 1);
  final indeks = hari.difference(awalTahun).inDays % daftarPertanyaanMalam.length;
  return daftarPertanyaanMalam[indeks];
}

/// Susun isi tinjauan malam.
///
/// Semua masukan datang dari data nyata (riwayat pembayaran hari itu, tugas
/// selesai hari itu, catatan air) — tidak ada angka yang dikarang di sini.
IsiTinjauanMalam susunTinjauanMalam({
  required DateTime hari,
  List<JudulNominal> tagihanLunasHariIni = const <JudulNominal>[],
  List<JudulNominal> tagihanBelumSelesai = const <JudulNominal>[],
  List<JudulNominal> tugasSelesaiHariIni = const <JudulNominal>[],
  List<JudulNominal> tugasBelumSelesai = const <JudulNominal>[],
  List<KebiasaanHariIni> kebiasaan = const <KebiasaanHariIni>[],
  int jumlahAirHariIni = 0,
}) {
  final selesai = <BarisTinjauan>[];
  final belum = <BarisTinjauan>[];

  for (final t in tagihanLunasHariIni) {
    selesai.add(BarisTinjauan(
      judul: t.judul,
      keterangan: 'Tagihan ditandai lunas hari ini.',
      selesai: true,
    ));
  }
  for (final t in tugasSelesaiHariIni) {
    selesai.add(BarisTinjauan(
      judul: t.judul,
      keterangan: 'Tugas ditandai selesai hari ini.',
      selesai: true,
    ));
  }
  final ditandai = kebiasaan.where((k) => k.ditandai).toList();
  if (ditandai.isNotEmpty) {
    selesai.add(BarisTinjauan(
      judul: 'Kebiasaan',
      keterangan: 'Ditandai hari ini: '
          '${ditandai.map((k) => k.nama).join(', ')}.',
      selesai: true,
    ));
  }
  if (jumlahAirHariIni > 0) {
    selesai.add(BarisTinjauan(
      judul: 'Catatan air',
      keterangan: '$jumlahAirHariIni catatan air hari ini.',
      selesai: true,
    ));
  }

  for (final t in tagihanBelumSelesai) {
    belum.add(BarisTinjauan(
      judul: t.judul,
      keterangan: 'Tagihan belum ditandai lunas.',
    ));
  }
  for (final t in tugasBelumSelesai) {
    belum.add(BarisTinjauan(
      judul: t.judul,
      keterangan: 'Tugas belum ditandai selesai.',
    ));
  }
  final belumDitandai = kebiasaan.where((k) => !k.ditandai).toList();
  if (belumDitandai.isNotEmpty) {
    belum.add(BarisTinjauan(
      judul: 'Kebiasaan belum ditandai',
      keterangan: belumDitandai.map((k) => k.nama).join(', '),
    ));
  }

  return IsiTinjauanMalam(
    tanggal: DateTime(hari.year, hari.month, hari.day),
    pertanyaan: pertanyaanMalam(hari),
    selesai: selesai,
    belum: belum,
  );
}

/// Label tanggal siap tampil (dipakai layar & uji).
String labelHariTinjauan(DateTime hari) {
  final d = DateTime(hari.year, hari.month, hari.day);
  return DateFormat('d MMMM yyyy', 'id_ID').format(d);
}
