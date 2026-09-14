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

/// Ubah "ID tagihan + slot" menjadi ID notifikasi Android yang stabil.
///
/// Rentang hasil: 0 … 203.0.113.10 (slot 0…99), selalu di bawah
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
  List<Pengingat> rencanakan({
    required List<TagihanData> tagihan,
    required DateTime sekarang,
  }) {
    final batasAwal = sekarang.add(const Duration(minutes: 1));
    final batasAkhir = sekarang.add(horizon);
    final hasil = <Pengingat>[];

    for (final t in tagihan) {
      if (!t.statusAktif || t.lunas) continue;
      final jam = jamDariTeks(t.pengingatJam);
      hasil.addAll(_pengingatLead(t, jam, batasAwal, batasAkhir));
      hasil.addAll(_pengingatTerlambat(t, jam, sekarang, batasAwal, batasAkhir));
    }

    if (sertakanRingkasanMingguan) {
      final r = _ringkasanMingguan(tagihan, sekarang, batasAkhir);
      if (r != null) hasil.add(r);
    }

    hasil.sort((a, b) => a.waktu.compareTo(b.waktu));
    return hasil;
  }

  List<Pengingat> _pengingatLead(
    TagihanData t,
    (int, int) jam,
    DateTime batasAwal,
    DateTime batasAkhir,
  ) {
    var lead = teksKeLead(t.pengingatLeadHari); // urut menurun: H-60 … H-0
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
