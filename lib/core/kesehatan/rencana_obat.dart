/// FR-54 — mesin rencana pengingat obat/suplemen.
///
/// MEMAKAI ULANG modul obat yang sudah ada (FR-106/107): tabel `obat`,
/// `jadwal_obat`, `minum_obat`, serta `ObatRepository`. Berkas ini HANYA
/// menambah lapisan rencana pengingat (jam berikutnya + teks pengingat) supaya
/// tidak ada tabel atau layar obat kedua.
library;

import 'dart:math' as math;

/// Satu jam minum yang sudah diratakan dari `obat` + `jadwal_obat`.
class JadwalRingkas {
  const JadwalRingkas({
    required this.obatId,
    required this.jadwalId,
    required this.nama,
    required this.jam,
    this.dosis = '',
    this.aktif = true,
    this.mulai,
    this.selesai,
  });

  final int obatId;
  final int jadwalId;
  final String nama;

  /// "HH:mm".
  final String jam;
  final String dosis;
  final bool aktif;
  final DateTime? mulai;
  final DateTime? selesai;
}

/// Satu slot minum yang direncanakan (waktu nyata, bukan teks).
class SlotObat {
  const SlotObat({
    required this.obatId,
    required this.jadwalId,
    required this.nama,
    required this.dosis,
    required this.waktu,
  });

  final int obatId;
  final int jadwalId;
  final String nama;
  final String dosis;
  final DateTime waktu;

  String get jam => jamDariMenit(waktu.hour * 60 + waktu.minute);
}

/// Ubah "HH:mm" (atau "H:mm", "HH.mm") menjadi menit sejak tengah malam.
/// Mengembalikan `null` bila jam tidak masuk akal — pemanggil tidak boleh
/// menebak.
int? menitDariJam(String? teks) {
  final t = (teks ?? '').trim().replaceAll('.', ':').replaceAll(' ', '');
  if (t.isEmpty) return null;
  final pisah = t.split(':');
  if (pisah.length != 2) return null;
  final jam = int.tryParse(pisah[0]);
  final menit = int.tryParse(pisah[1]);
  if (jam == null || menit == null) return null;
  if (jam < 0 || jam > 23) return null;
  if (menit < 0 || menit > 59) return null;
  return jam * 60 + menit;
}

/// Menit sejak tengah malam → "HH:mm".
String jamDariMenit(int menit) {
  final m = ((menit % 1440) + 1440) % 1440;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

/// Slot minum yang jatuh di jendela [sekarang, sekarang + jendela).
///
/// Melewati jadwal nonaktif, jam tidak sah, dan obat yang belum mulai /
/// sudah selesai pada hari itu.
List<SlotObat> slotMendatang(
  List<JadwalRingkas> daftar,
  DateTime sekarang, {
  Duration jendela = const Duration(hours: 24),
}) {
  final batas = sekarang.add(jendela);
  final hasil = <SlotObat>[];
  for (final j in daftar) {
    if (!j.aktif) continue;
    final menit = menitDariJam(j.jam);
    if (menit == null) continue;
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final hariBatas = DateTime(batas.year, batas.month, batas.day);
    for (var hari = hariIni;
        !hari.isAfter(hariBatas);
        hari = hari.add(const Duration(days: 1))) {
      final waktu = hari.add(Duration(minutes: menit));
      if (waktu.isBefore(sekarang) || !waktu.isBefore(batas)) continue;
      if (j.mulai != null && waktu.isBefore(j.mulai!)) continue;
      if (j.selesai != null && waktu.isAfter(_akhirHari(j.selesai!))) continue;
      hasil.add(SlotObat(
        obatId: j.obatId,
        jadwalId: j.jadwalId,
        nama: j.nama,
        dosis: j.dosis,
        waktu: waktu,
      ));
    }
  }
  hasil.sort((a, b) => a.waktu.compareTo(b.waktu));
  return hasil;
}

DateTime _akhirHari(DateTime t) => DateTime(t.year, t.month, t.day, 23, 59, 59);

/// ID notifikasi yang stabil untuk satu obat + urutan slot.
///
/// Dipisah dari sumber pengingat lain (`batasIdKhusus + 300000`).
int idPengingatObat(int idDasar, int obatId, int urutan) =>
    idDasar + obatId * 100 + (urutan % 100);

/// Judul & isi pemberitahuan minum obat (bahasa manusia, tanpa penilaian).
({String judul, String isi}) teksPengingatObat(SlotObat slot) {
  final dosis = slot.dosis.trim();
  final isi = dosis.isEmpty
      ? 'Waktunya pukul ${slot.jam}. Buka aplikasi untuk menandai '
          'sudah minum atau terlewat.'
      : '$dosis — waktunya pukul ${slot.jam}. Buka aplikasi untuk menandai '
          'sudah minum atau terlewat.';
  return (judul: 'Waktunya minum ${slot.nama}', isi: isi);
}

/// Ringkasan untuk layar: slot yang akan datang hari ini & berikutnya.
class RingkasPengingatObat {
  const RingkasPengingatObat({
    required this.slot,
    required this.sekarang,
    this.jumlahHariIni = 0,
  });

  final List<SlotObat> slot;
  final DateTime sekarang;
  final int jumlahHariIni;

  bool get ada => slot.isNotEmpty;

  SlotObat? get berikutnya => slot.isEmpty ? null : slot.first;

  /// "Berikutnya 08.00 — Amlodipin" atau keterangan belum ada jadwal.
  String get kalimatBerikutnya {
    final b = berikutnya;
    if (b == null) return 'Belum ada jam minum berikutnya.';
    return 'Berikutnya ${b.jam} — ${b.nama}.';
  }

  double? get kemajuanHariIni {
    final semua = jumlahHariIni;
    if (semua <= 0) return null;
    final lewat = slot.where((s) => s.waktu.isBefore(sekarang)).length;
    return math.min(1, lewat / semua);
  }
}

/// Susun ringkasan pengingat dari jam-jam minum yang sudah tercatat.
RingkasPengingatObat ringkasPengingatObat(
  List<SlotObat> slot,
  DateTime sekarang, {
  Set<String> sudahDicatat = const {},
}) {
  final bersih = slot
      .where((s) => !sudahDicatat.contains(kunciSlot(s)))
      .toList()
    ..sort((a, b) => a.waktu.compareTo(b.waktu));
  final hariIni = bersih.where((s) => _hariSama(s.waktu, sekarang)).length;
  return RingkasPengingatObat(
    slot: bersih,
    sekarang: sekarang,
    jumlahHariIni: hariIni,
  );
}

/// Kunci slot untuk menandai "sudah ada catatannya" (obat + waktu rencana).
String kunciSlot(SlotObat slot) =>
    '${slot.obatId}@${slot.waktu.toIso8601String().substring(0, 16)}';

bool _hariSama(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
