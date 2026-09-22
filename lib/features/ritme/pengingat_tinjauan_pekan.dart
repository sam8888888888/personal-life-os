/// FR-144 — pengingat tinjauan pekan (Weekly Life Review).
///
/// Kriteria terima PRD: "Tersedia setiap pekan; dapat dikirim sebagai notifikasi
/// ringkas." Modul ini **tidak** menyentuh mesin penjadwalan tagihan: ia hanya
/// menyerahkan satu [Pengingat] lewat [SumberPengingatTambahan], pola yang sama
/// dengan pengingat perawatan (FR-125) dan dokumen (FR-129).
///
/// ID notifikasi memakai rentang cadangan `batasIdKhusus + 9000000` supaya tidak
/// bentrok dengan tagihan, briefing (+10), sholat (+100), dokumen (+1000),
/// obat (+3000000), maupun janji (+4000000).
library;

import 'package:drift/drift.dart' show Value;

import '../../core/notifikasi/model_pengingat.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../core/notifikasi/sumber_pengingat_tambahan.dart';
import '../../data/database/database.dart';

/// Jam pengingat tinjauan pekan (Minggu malam, saat orang biasanya tenang).
const int jamTinjauanPekan = 20;

/// Batas ID pengingat tinjauan pekan.
const int batasIdTinjauanPekan = batasIdKhusus + 9000000;

/// ID notifikasi tinjauan pekan ke-[i].
int idTinjauanPekanKe(int i) => batasIdTinjauanPekan + i;

/// Senin awal pekan dari [t] (tanpa jam).
DateTime awalPekanRitme(DateTime t) {
  final hari = DateTime(t.year, t.month, t.day);
  return hari.subtract(Duration(days: hari.weekday - DateTime.monday));
}

/// Waktu tinjauan pekan berikutnya: **Minggu [jamTinjauanPekan]:00**.
///
/// Bila sekarang masih sebelum waktu itu pada pekan berjalan → pekan ini;
/// kalau sudah lewat → pekan depan.
DateTime waktuTinjauanBerikutnya(DateTime sekarang,
    {int jam = jamTinjauanPekan}) {
  final senin = awalPekanRitme(sekarang);
  final minggu = senin.add(const Duration(days: 6));
  final target = DateTime(minggu.year, minggu.month, minggu.day, jam);
  if (target.isAfter(sekarang)) return target;
  return target.add(const Duration(days: 7));
}

/// Tanggal ringkas tanpa locale, mis. "21 Sep 2026".
String fmtTanggalRingkasRitme(DateTime d) {
  const bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${d.day} ${bulan[d.month - 1]} ${d.year}';
}

/// Susun pengingat tinjauan pekan.
///
/// [sudahSelesai] = pekan yang bersangkutan sudah diisi pengguna → tidak
/// diingatkan lagi (tidak mengganggu). Fungsi ini **murni** (hanya membaca
/// argumen) supaya bisa diuji langsung dan aman dipanggil tiap sinkronisasi.
List<Pengingat> pengingatTinjauanPekanUntuk(
  DateTime sekarang, {
  bool sudahSelesai = false,
  int jam = jamTinjauanPekan,
}) {
  if (sudahSelesai) return const [];
  final waktu = waktuTinjauanBerikutnya(sekarang, jam: jam);
  final pekan = awalPekanRitme(waktu);
  return [
    Pengingat(
      id: idTinjauanPekanKe(0),
      tagihanId: 0,
      waktu: waktu,
      kanal: KanalNotifikasi.ringkasan,
      judul: 'Tinjauan pekan siap diisi',
      isi: 'Tinjauan pekan: lihat apa yang membaik dan apa yang perlu '
          'perhatian pekan ini, lalu tetapkan fokus pekan depan '
          '(pekan ${fmtTanggalRingkasRitme(pekan)}).',
      hariSebelum: 0,
      terlambat: false,
    ),
  ];
}

/// Cara membuka basis data (bisa diganti saat pengujian).
typedef PembukaBasisRitme = AppDatabase Function();

/// Sumber pengingat tambahan milik modul ritme hidup.
class SumberPengingatTinjauanPekan implements SumberPengingatTambahan {
  SumberPengingatTinjauanPekan({
    PembukaBasisRitme? pembukaBasisData,
    this.tutupBasisData = true,
    this.jam = jamTinjauanPekan,
  }) : buka = pembukaBasisData ?? AppDatabase.new;

  final PembukaBasisRitme buka;
  final bool tutupBasisData;
  final int jam;

  @override
  Future<List<Pengingat>> pengingatTambahan(DateTime sekarang) async {
    final AppDatabase db = buka();
    try {
      final pekan = awalPekanRitme(waktuTinjauanBerikutnya(sekarang, jam: jam));
      final uid = 'tw_${pekan.year}-${pekan.month.toString().padLeft(2, '0')}'
          '-${pekan.day.toString().padLeft(2, '0')}';
      final baris = await (db.select(db.tinjauanMingguan)
            ..where((t) => t.uid.equals(uid))
            ..limit(1))
          .getSingleOrNull();
      return pengingatTinjauanPekanUntuk(
        sekarang,
        sudahSelesai: baris?.selesai ?? false,
        jam: jam,
      );
    } finally {
      if (tutupBasisData) await db.close();
    }
  }
}

/// Daftarkan sumber pengingat tinjauan pekan.
///
/// WAJIB dipanggil di **dua** tempat: `main.dart` (isolate utama lewat
/// `daftarkanSumberPengingatUtama`) dan `kerja_latar.dart`
/// (`daftarkanSumberPengingatLatar`) — isolate latar tidak mewarisi variabel
/// statis isolate utama.
void daftarkanSumberPengingatTinjauanPekan() {
  RegistriSumberPengingat.daftarkan(SumberPengingatTinjauanPekan());
}

/// Dipakai uji & layar: apakah tinjauan pekan [pekanMulai] sudah diisi?
Future<bool> tinjauanPekanSelesai(AppDatabase db, DateTime pekanMulai) async {
  final uid = 'tw_${pekanMulai.year}-'
      '${pekanMulai.month.toString().padLeft(2, '0')}-'
      '${pekanMulai.day.toString().padLeft(2, '0')}';
  final baris = await (db.select(db.tinjauanMingguan)
        ..where((t) => t.uid.equals(uid))
        ..limit(1))
      .getSingleOrNull();
  return baris?.selesai ?? false;
}

/// Dipakai uji: tulis satu baris tinjauan tanpa lewat repositori.
Future<void> tulisTinjauanUji(
  AppDatabase db,
  DateTime pekanMulai, {
  bool selesai = true,
}) async {
  final uid = 'tw_${pekanMulai.year}-'
      '${pekanMulai.month.toString().padLeft(2, '0')}-'
      '${pekanMulai.day.toString().padLeft(2, '0')}';
  await db.into(db.tinjauanMingguan).insert(TinjauanMingguanCompanion.insert(
        uid: Value(uid),
        pekanMulai: pekanMulai,
        selesai: Value(selesai),
      ));
}
