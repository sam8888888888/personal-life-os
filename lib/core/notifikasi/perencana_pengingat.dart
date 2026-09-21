/// Perencana waktu pengingat — logika murni tanpa plugin/platform.
///
/// Dipakai bersama oleh aplikasi, pekerja latar (Workmanager), dan uji unit.
/// Aturan yang dilayani:
///  - FR-10 lead time kustom per tagihan (H-60 … H-0) pada jam pilihan pengguna
///  - FR-12 anti-bising: maksimum N pengingat per tagihan per siklus
///  - FR-16 pengingat "terlambat" sekali per hari
///  - FR-15 ringkasan mingguan Senin pagi
library;

import '../../data/database/database.dart';
import '../utils/tanggal_utils.dart';
import '../utils/uang_utils.dart';
import 'model_pengingat.dart';

/// Rentang ID khusus (jauh di atas rentang ID tagihan, lihat [idNotifikasi]).
const int batasIdKhusus = 1999000000;

/// ID tetap untuk notifikasi ringkasan mingguan.
const int idRingkasanMingguan = batasIdKhusus + 1;

/// ID tetap untuk notifikasi uji mandiri (dipakai layar Pengingat).
const int idUjiNotifikasi = batasIdKhusus + 2;

/// Batas jumlah pengingat lead per tagihan per siklus (FR-12).
const int maksPengingatPerSiklus = 7;

/// Batas notifikasi "terlambat" per tagihan (hari) — sekali per hari (FR-16).
const int maksHariTerlambat = 7;

/// Jam ringkasan mingguan (Senin pagi).
const int jamRingkasanMingguan = 8;

// ---------------------------------------------------------------------------
// FR-63 briefing pagi & FR-87 pengingat sholat (momok tambahan)
// ---------------------------------------------------------------------------
//
// ID memakai rentang cadangan (>= batasIdKhusus) supaya tidak pernah bentrok
// dengan ID tagihan — sama pola dengan ringkasan mingguan & notifikasi uji.

/// Jam briefing pagi bawaan (FR-63).
const String jamBriefingBawaan = '06:00';

/// Berapa hari ke depan briefing dijadwalkan sekaligus.
const int hariBriefingKeDepan = 7;

/// Berapa hari ke depan pengingat sholat dijadwalkan sekaligus.
///
/// Sengaja dibatasi: pekerja latar + sinkronisasi saat aplikasi dibuka
/// menyegarkan jadwal, sedangkan menumpuk ratusan alarm (35 hari × 5 waktu)
/// berisiko ditolak sistem. 7 hari × 5 waktu = 35 alarm per pilihan mode.
const int hariSholatKeDepan = 7;

/// ID briefing pagi untuk hari ke-[i] (i = 0 … [hariBriefingKeDepan] − 1).
int idBriefingPagiKe(int i) => batasIdKhusus + 10 + i;

/// ID pengingat sholat ke-[i] (i = 0 … jumlah waktu × [hariSholatKeDepan] − 1).
int idSholatKe(int i) => batasIdKhusus + 100 + i;

/// Pilihan mode pengingat per waktu sholat (FR-87).
enum ModePengingatSholat {
  sebelum('sebelum'),
  tepat('tepat'),
  sesudah('sesudah');

  const ModePengingatSholat(this.nilaiDb);
  final String nilaiDb;

  static ModePengingatSholat dariDb(String? v) => ModePengingatSholat.values
      .firstWhere((e) => e.nilaiDb == v, orElse: () => ModePengingatSholat.tepat);

  String get label => switch (this) {
        ModePengingatSholat.sebelum => 'Sebelum waktu',
        ModePengingatSholat.tepat => 'Saat masuk waktu',
        ModePengingatSholat.sesudah => 'Setelah waktu',
      };
}

/// Satu waktu sholat yang ingin diingatkan — data disiapkan modul fitur
/// (nama waktu, jam menurut perhitungannya, dan pilihan mode pengguna).
class JadwalPengingatSholat {
  const JadwalPengingatSholat({
    required this.nama,
    required this.jam,
    this.mode = ModePengingatSholat.tepat,
    this.menitGeser = 0,
  });

  /// Nama waktu, mis. "Subuh".
  final String nama;

  /// Jam masuk waktu `HH:mm` (waktu lokal) menurut perhitungan aplikasi.
  final String jam;

  final ModePengingatSholat mode;

  /// Menit geser (0–120) untuk mode [ModePengingatSholat.sebelum]
  /// (mis. 5 = lima menit sebelum) dan [ModePengingatSholat.sesudah].
  final int menitGeser;

  /// Waktu pengingat pada hari [hari] (jam pada [hari] diabaikan).
  DateTime waktuPada(DateTime hari) {
    final (j, m) = jamDariTeks(jam);
    final dasar = DateTime(hari.year, hari.month, hari.day, j, m);
    final geser = menitGeser.clamp(0, 120);
    return switch (mode) {
      ModePengingatSholat.sebelum => dasar.subtract(Duration(minutes: geser)),
      ModePengingatSholat.tepat => dasar,
      ModePengingatSholat.sesudah => dasar.add(Duration(minutes: geser)),
    };
  }

  /// Judul notifikasi — menyebut fakta, tidak menilai (PRD §III-11).
  String get judul => switch (mode) {
        ModePengingatSholat.sebelum => menitGeser > 0
            ? '$menitGeser menit lagi $nama'
            : 'Menjelang $nama',
        ModePengingatSholat.tepat => 'Waktu $nama $jam',
        ModePengingatSholat.sesudah => 'Sudah masuk waktu $nama',
      };

  /// Isi notifikasi — selalu menyebut "menurut hitungan aplikasi", tanpa
  /// kata menghakimi seperti "belum sholat".
  String get isi => switch (mode) {
        ModePengingatSholat.sebelum =>
          'Menurut hitungan aplikasi, $nama masuk pukul $jam.',
        ModePengingatSholat.tepat =>
          'Menurut hitungan aplikasi, $nama masuk pukul $jam.',
        /// FR-86 kejujuran: jadwal ini hasil perhitungan aplikasi, bukan
        /// jadwal resmi — disebut juga pada notifikasi mode sesudah.
        ModePengingatSholat.sesudah =>
          'Menurut hitungan aplikasi, $nama masuk pukul $jam. '
              'Catat bila sudah Anda lakukan.',
      };
}

/// Ubah "ID tagihan + slot" menjadi ID notifikasi Android yang stabil.
///
/// Rentang hasil: 0 … 1.000.000.099 (slot 0…99), selalu di bawah
/// [batasIdKhusus] sehingga tidak pernah bentrok dengan ID ringkasan/uji.
int idNotifikasi(int tagihanId, int slot) => (tagihanId % 10000000) * 100 + slot;

/// Slot untuk pengingat terlambat hari ke-N.
int slotTerlambat(int hariKe) => 90 + (hariKe % 10);

/// Slot untuk pengingat yang ditunda 1 jam (FR-11).
const int slotTunda = 89;

/// PB-04: tentukan ID jadwal yang HARUS dibatalkan saat sinkronisasi.
///
/// Aturan: batalkan hanya jadwal yang tidak ada di rencana. Pengecualian
/// penting — pengingat "Tunda 1 jam" (slot [slotTunda]) milik tagihan yang
/// masih ada di rencana DIPERTAHANKAN, supaya tunda tidak hilang setiap kali
/// jadwal disegarkan (buka aplikasi, ubah tagihan, pekerja latar).
/// Tunda milik tagihan yang sudah tidak ada tetap dibatalkan.
Set<int> idJadwalDibatalkan({
  required Iterable<int> tertunda,
  required Iterable<int> rencana,
  required Iterable<int> tagihanRencana,
}) {
  final idRencana = rencana.toSet();
  final tagihanHidup = tagihanRencana.toSet();
  final buang = <int>{};
  for (final id in tertunda) {
    if (idRencana.contains(id)) continue;
    final slot = id % 100;
    final tagihanId = id ~/ 100;
    if (slot == slotTunda && tagihanHidup.contains(tagihanId)) continue;
    buang.add(id);
  }
  return buang;
}

/// PB-09: ID jadwal yang DIRENCANAKAN tetapi belum benar-benar terpasang.
/// Dipakai sinkronisasi untuk memverifikasi hasil, bukan sekadar mengasumsikan.
List<int> idJadwalGagalTerpasang({
  required Iterable<int> direncanakan,
  required Iterable<int> terpasang,
}) {
  final ada = terpasang.toSet();
  return [for (final id in direncanakan) if (!ada.contains(id)) id];
}

class PerencanaPengingat {
  const PerencanaPengingat({
    this.horizon = const Duration(days: 35),
    this.sertakanRingkasanMingguan = true,
  });

  /// Jauh ke depan yang dijadwalkan sekaligus (disinkronkan ulang tiap app dibuka).
  final Duration horizon;
  final bool sertakanRingkasanMingguan;

  /// Susun seluruh pengingat untuk [tagihan] pada saat [sekarang].
  ///
  /// [sertakanBriefingPagi] menyalakan briefing pagi harian (FR-63);
  /// [jadwalSholat] berisi pengingat waktu sholat (FR-87) — keduanya opsional
  /// supaya pemanggil lama tidak berubah perilakunya.
  List<Pengingat> rencanakan({
    required List<TagihanData> tagihan,
    required DateTime sekarang,
    bool sertakanBriefingPagi = false,
    String jamBriefingPagi = jamBriefingBawaan,
    List<JadwalPengingatSholat> jadwalSholat = const [],
    Map<int, int> leadPintar = const {},
  }) {
    final batasAwal = sekarang.add(const Duration(minutes: 1));
    final batasAkhir = sekarang.add(horizon);
    final hasil = <Pengingat>[];

    for (final t in tagihan) {
      if (!t.statusAktif || t.lunas) continue;
      final jam = jamDariTeks(t.pengingatJam);
      hasil.addAll(_pengingatLead(t, jam, batasAwal, batasAkhir,
          leadTambahan: leadPintar[t.id]));
      hasil.addAll(_pengingatTerlambat(t, jam, sekarang, batasAwal, batasAkhir));
    }

    if (sertakanRingkasanMingguan) {
      final r = _ringkasanMingguan(tagihan, sekarang, batasAkhir);
      if (r != null) hasil.add(r);
    }

    // FR-63 & FR-87: pengingat tambahan dari modul fitur.
    if (sertakanBriefingPagi) {
      hasil.addAll(
          _briefingPagi(tagihan, sekarang, batasAwal, batasAkhir, jamBriefingPagi));
    }
    hasil.addAll(_pengingatSholat(jadwalSholat, sekarang, batasAwal, batasAkhir));

    hasil.sort((a, b) => a.waktu.compareTo(b.waktu));
    return hasil;
  }

  /// FR-63: satu notifikasi briefing per hari pada [jamBriefing] (bawaan 06:00).
  ///
  /// Isinya sengaja pendek: jumlah & total tagihan 7 hari ke depan. Menyentuh
  /// notifikasi ini membuka aplikasi (aksi "buka"), tidak pernah menandai lunas
  /// — payload-nya konteks saja (`tagihanId = 0`).
  List<Pengingat> _briefingPagi(
    List<TagihanData> tagihan,
    DateTime sekarang,
    DateTime batasAwal,
    DateTime batasAkhir,
    String jamBriefing,
  ) {
    final (j, m) = jamDariTeks(jamBriefing);
    final hasil = <Pengingat>[];
    for (var i = 0; i < hariBriefingKeDepan; i++) {
      final hari = DateTime(sekarang.year, sekarang.month, sekarang.day + i);
      final waktu = DateTime(hari.year, hari.month, hari.day, j, m);
      if (waktu.isBefore(batasAwal) || waktu.isAfter(batasAkhir)) continue;
      final besok = DateTime(hari.year, hari.month, hari.day + 1);
      final (jumlahHariIni, totalHariIni) = _tagihanDalam(
        tagihan,
        DateTime(hari.year, hari.month, hari.day),
        besok,
      );
      final (jumlahBesok, totalBesok) = _tagihanDalam(
        tagihan,
        besok,
        DateTime(besok.year, besok.month, besok.day + 1),
      );
      final (jumlahTujuhHari, totalTujuhHari) = _tagihanDalam(
        tagihan,
        DateTime(hari.year, hari.month, hari.day),
        DateTime(hari.year, hari.month, hari.day + 7),
      );
      hasil.add(Pengingat(
        id: idBriefingPagiKe(i),
        tagihanId: 0,
        waktu: waktu,
        kanal: KanalNotifikasi.briefing,
        judul: 'Ringkasan pagi siap',
        isi: _isiRingkasanPagi(
          jumlahHariIni: jumlahHariIni,
          totalHariIni: totalHariIni,
          jumlahBesok: jumlahBesok,
          totalBesok: totalBesok,
          jumlahTujuhHari: jumlahTujuhHari,
          totalTujuhHari: totalTujuhHari,
        ),
      ));
    }
    return hasil;
  }

  /// FR-87: satu notifikasi per waktu sholat per hari, maksimum
  /// [hariSholatKeDepan] hari ke depan. Tidak ada pengingat berulang.
  List<Pengingat> _pengingatSholat(
    List<JadwalPengingatSholat> jadwal,
    DateTime sekarang,
    DateTime batasAwal,
    DateTime batasAkhir,
  ) {
    if (jadwal.isEmpty) return const [];
    final hasil = <Pengingat>[];
    for (var hari = 0; hari < hariSholatKeDepan; hari++) {
      final tanggal = DateTime(sekarang.year, sekarang.month, sekarang.day + hari);
      for (var i = 0; i < jadwal.length; i++) {
        final s = jadwal[i];
        final waktu = s.waktuPada(tanggal);
        if (waktu.isBefore(batasAwal) || waktu.isAfter(batasAkhir)) continue;
        hasil.add(Pengingat(
          id: idSholatKe(hari * jadwal.length + i),
          tagihanId: 0,
          waktu: waktu,
          kanal: KanalNotifikasi.sholat,
          judul: s.judul,
          isi: s.isi,
        ));
      }
    }
    return hasil;
  }

  /// FR-32: teks ringkasan pagi — hari ini, besok, dan total 7 hari.
  ///
  /// Sengaja menyebut angka rupiah supaya pengguna tahu besarnya di layar kunci
  /// tanpa membuka aplikasi.
  String _isiRingkasanPagi({
    required int jumlahHariIni,
    required int totalHariIni,
    required int jumlahBesok,
    required int totalBesok,
    required int jumlahTujuhHari,
    required int totalTujuhHari,
  }) {
    if (jumlahHariIni == 0 && jumlahBesok == 0) {
      return jumlahTujuhHari == 0
          ? 'Tidak ada tagihan hari ini atau besok.'
          : 'Hari ini & besok tidak ada tagihan. '
              '$jumlahTujuhHari tagihan dalam 7 hari ke depan '
              '(${fmtRpDariSen(totalTujuhHari)}).';
    }
    final hariIni = jumlahHariIni == 0
        ? 'Hari ini tidak ada tagihan'
        : 'Hari ini $jumlahHariIni tagihan (${fmtRpDariSen(totalHariIni)})';
    final besokTeks = jumlahBesok == 0
        ? 'besok tidak ada tagihan'
        : 'besok $jumlahBesok tagihan (${fmtRpDariSen(totalBesok)})';
    return '$hariIni, $besokTeks. '
        'Total 7 hari: ${fmtRpDariSen(totalTujuhHari)}.';
  }

  /// Jumlah & total tagihan aktif belum lunas dalam rentang [dari, sampai).
  (int, int) _tagihanDalam(
      List<TagihanData> tagihan, DateTime dari, DateTime sampai) {
    var jumlah = 0;
    var total = 0;
    for (final t in tagihan) {
      if (!t.statusAktif || t.lunas) continue;
      if (t.jatuhTempo.isBefore(dari) || !t.jatuhTempo.isBefore(sampai)) continue;
      jumlah++;
      total += t.jumlahSen ?? 0;
    }
    return (jumlah, total);
  }

  /// [leadTambahan] (FR-17) = hari yang biasanya dipakai pengguna membayar,
  /// hasil pembelajaran pola. Bila ada dan belum termasuk, satu pengingat
  /// ditambahkan pada hari itu.
  List<Pengingat> _pengingatLead(
    TagihanData t,
    (int, int) jam,
    DateTime batasAwal,
    DateTime batasAkhir, {
    int? leadTambahan,
  }) {
    var lead = teksKeLead(t.pengingatLeadHari); // urut menurun: H-60 … H-0
    if (leadTambahan != null &&
        leadTambahan >= 0 &&
        !lead.contains(leadTambahan)) {
      lead = [...lead, leadTambahan]..sort((a, b) => b.compareTo(a));
    }
    if (lead.length > maksPengingatPerSiklus) {
      // FR-12: bila lead melebihi batas, buang yang TERJAUH (H-60, H-30, …).
      // Pengingat terdekat (H-1, hari-H) justru yang paling penting.
      lead = lead.sublist(lead.length - maksPengingatPerSiklus);
    }
    final dipakai = lead;
    final hasil = <Pengingat>[];
    for (var slot = 0; slot < dipakai.length; slot++) {
      final h = dipakai[slot];
      final dasar = tanggalPengingat(t.jatuhTempo, h);
      final waktu = DateTime(dasar.year, dasar.month, dasar.day, jam.$1, jam.$2);
      if (waktu.isBefore(batasAwal) || waktu.isAfter(batasAkhir)) continue;
      hasil.add(Pengingat(
        id: idNotifikasi(t.id, slot),
        tagihanId: t.id,
        waktu: waktu,
        kanal: KanalNotifikasi.tagihan,
        judul: _judulLead(t, h),
        isi: _isiLead(t, h),
        hariSebelum: h,
        periode: t.jatuhTempo,
      ));
    }
    return hasil;
  }

  List<Pengingat> _pengingatTerlambat(
    TagihanData t,
    (int, int) jam,
    DateTime sekarang,
    DateTime batasAwal,
    DateTime batasAkhir,
  ) {
    final telatHari = selisihHari(t.jatuhTempo, sekarang);
    if (telatHari <= 0) return const [];
    final hasil = <Pengingat>[];
    for (var ke = 0; ke < maksHariTerlambat; ke++) {
      final hari = DateTime(sekarang.year, sekarang.month, sekarang.day + ke);
      final waktu = DateTime(hari.year, hari.month, hari.day, jam.$1, jam.$2);
      if (waktu.isBefore(batasAwal) || waktu.isAfter(batasAkhir)) continue;
      final telatSaatItu = telatHari + ke;
      hasil.add(Pengingat(
        id: idNotifikasi(t.id, slotTerlambat(ke)),
        tagihanId: t.id,
        waktu: waktu,
        kanal: KanalNotifikasi.terlambat,
        judul: 'Tagihan terlambat: ${t.nama}',
        isi: '${t.nama} lewat $telatSaatItu hari dari jatuh tempo '
            '(${fmtTanggalAman(t.jatuhTempo)}). ${_nominal(t)}',
        terlambat: true,
        periode: t.jatuhTempo,
      ));
    }
    return hasil;
  }

  Pengingat? _ringkasanMingguan(
    List<TagihanData> tagihan,
    DateTime sekarang,
    DateTime batasAkhir,
  ) {
    final senin = _seninBerikutnya(sekarang);
    if (senin.isAfter(batasAkhir)) return null;
    final sampai = senin.add(const Duration(days: 7));
    final dekat = tagihan
        .where((t) =>
            t.statusAktif &&
            !t.lunas &&
            !t.jatuhTempo.isBefore(DateTime(senin.year, senin.month, senin.day)) &&
            t.jatuhTempo.isBefore(sampai))
        .toList()
      ..sort((a, b) => a.jatuhTempo.compareTo(b.jatuhTempo));
    if (dekat.isEmpty) return null;
    var totalSen = 0;
    for (final t in dekat) {
      totalSen += t.jumlahSen ?? 0;
    }
    final rincian = dekat
        .take(4)
        .map((t) => '${t.nama} (${fmtTanggalPendekAman(t.jatuhTempo)})')
        .join(', ');
    final sisa = dekat.length > 4 ? ', +${dekat.length - 4} lagi' : '';
    return Pengingat(
      id: idRingkasanMingguan,
      tagihanId: 0,
      waktu: senin,
      kanal: KanalNotifikasi.ringkasan,
      judul: 'Pekan ini: ${dekat.length} tagihan${totalSen > 0 ? ' · ${fmtRpDariSen(totalSen)}' : ''}',
      isi: '$rincian$sisa',
    );
  }

  /// Senin berikutnya pukul [jamRingkasanMingguan] (hari ini bila belum lewat).
  DateTime _seninBerikutnya(DateTime sekarang) {
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day,
        jamRingkasanMingguan);
    final maju = (DateTime.monday - sekarang.weekday) % 7;
    var kandidat = hariIni.add(Duration(days: maju));
    if (!kandidat.isAfter(sekarang)) kandidat = kandidat.add(const Duration(days: 7));
    return kandidat;
  }

  String _judulLead(TagihanData t, int h) => h == 0
      ? 'Hari ini: ${t.nama}'
      : h == 1
          ? 'Besok: ${t.nama}'
          : '$h hari lagi: ${t.nama}';

  String _isiLead(TagihanData t, int h) {
    final nominal = _nominal(t);
    final jatuh = 'jatuh tempo ${fmtTanggalAman(t.jatuhTempo)}';
    if (h == 0) return '$jatuh. $nominal';
    return 'Jatuh tempo ${fmtTanggalAman(t.jatuhTempo)} ($h hari lagi). $nominal';
  }

  String _nominal(TagihanData t) {
    final sen = t.jumlahSen ?? 0;
    return sen > 0 ? fmtRpDariSen(sen) : 'Tanpa nominal';
  }
}

/// Ambil jam & menit dari teks "HH:mm" (default 09:00).
(int, int) jamDariTeks(String? teks) {
  if (teks == null) return (9, 0);
  final bagian = teks.split(':');
  if (bagian.length != 2) return (9, 0);
  final j = int.tryParse(bagian[0].trim());
  final m = int.tryParse(bagian[1].trim());
  if (j == null || m == null) return (9, 0);
  if (j < 0 || j > 23 || m < 0 || m > 59) return (9, 0);
  return (j, m);
}
