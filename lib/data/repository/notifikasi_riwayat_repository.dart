/// FR-147 & FR-148 — Riwayat notifikasi (Pusat Notifikasi) dan penundaan
/// pengingat (Snooze).
///
/// Prinsip berkas ini:
/// 1. **Riwayat lokal.** Semua baris hidup di tabel `notifikasi_riwayat` di
///    perangkat pengguna. Tidak ada pengiriman ke mana pun.
/// 2. **Tingkat tidak menghakimi** (PRD §III-11). Tingkat hanya menandai mana
///    yang perlu dilihat lebih dulu, bukan penilaian atas perilaku pengguna.
/// 3. **Jatuh tempo asli tidak pernah disentuh.** Tabel `tunda_pengingat`
///    hanya menyimpan waktu pengingat yang digeser; tanggal tagihan/tugas
///    tetap di tabelnya sendiri (FR-148).
/// 4. **Batas tunda dijaga** lapisan murni (lihat
///    `core/notifikasi/tunda_pengingat.dart`): maksimum 3 kali per pengingat.
library;

import 'package:drift/drift.dart';

import '../../core/notifikasi/tunda_pengingat.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Batas waktu satu pembacaan penyimpanan (aturan platform, 5 detik).
const Duration batasBacaNotifikasi = Duration(seconds: 5);

/// Tingkat notifikasi (FR-147).
///
/// [bobot] dipakai untuk pengurutan: angka lebih kecil dilihat lebih dulu.
enum TingkatNotifikasi {
  mendesak('mendesak', 'Mendesak', 0),
  penting('penting', 'Penting', 1),
  biasa('biasa', 'Biasa', 2);

  const TingkatNotifikasi(this.nilaiDb, this.label, this.bobot);
  final String nilaiDb;
  final String label;
  final int bobot;

  static TingkatNotifikasi dariDb(String? v) => TingkatNotifikasi.values
      .firstWhere((e) => e.nilaiDb == v, orElse: () => TingkatNotifikasi.biasa);
}

/// Status satu baris riwayat notifikasi (FR-147).
enum StatusNotifikasi {
  baru('baru', 'Belum dibaca'),
  dibaca('dibaca', 'Sudah dibaca'),
  selesai('selesai', 'Selesai'),
  ditunda('ditunda', 'Ditunda');

  const StatusNotifikasi(this.nilaiDb, this.label);
  final String nilaiDb;
  final String label;

  static StatusNotifikasi dariDb(String? v) => StatusNotifikasi.values
      .firstWhere((e) => e.nilaiDb == v, orElse: () => StatusNotifikasi.baru);
}

/// Hasil pengelompokan riwayat untuk layar: hari ini / kemarin / lebih lama.
class KelompokNotifikasi {
  const KelompokNotifikasi({
    required this.hariIni,
    required this.kemarin,
    required this.lebihLama,
  });

  final List<NotifikasiRiwayatData> hariIni;
  final List<NotifikasiRiwayatData> kemarin;
  final List<NotifikasiRiwayatData> lebihLama;

  int get total => hariIni.length + kemarin.length + lebihLama.length;

  bool get kosong => total == 0;
}

/// Kelompokkan riwayat menurut selisih hari kalender terhadap [sekarang].
///
/// Baris bertanggal hari ini (termasuk yang sedikit di depan, mis. notifikasi
/// terjadwal) masuk [KelompokNotifikasi.hariIni]. **Murni**, tanpa I/O.
KelompokNotifikasi kelompokkanNotifikasi(
  List<NotifikasiRiwayatData> baris,
  DateTime sekarang,
) {
  final hariIni = <NotifikasiRiwayatData>[];
  final kemarin = <NotifikasiRiwayatData>[];
  final lebihLama = <NotifikasiRiwayatData>[];
  for (final b in baris) {
    final selisih = selisihHari(b.waktu, sekarang);
    if (selisih <= 0) {
      hariIni.add(b);
    } else if (selisih == 1) {
      kemarin.add(b);
    } else {
      lebihLama.add(b);
    }
  }
  return KelompokNotifikasi(
    hariIni: List.unmodifiable(hariIni),
    kemarin: List.unmodifiable(kemarin),
    lebihLama: List.unmodifiable(lebihLama),
  );
}

/// Akses data riwayat notifikasi (FR-147).
class NotifikasiRiwayatRepository {
  NotifikasiRiwayatRepository(this.db, {this.jam});

  final AppDatabase db;

  /// Sumber waktu (null = satu sumber waktu aplikasi).
  final DateTime Function()? jam;

  DateTime _sekarang() => (jam ?? waktuSekarang)();

  // -------------------------------------------------------------------
  // TULIS
  // -------------------------------------------------------------------

  /// Simpan satu baris riwayat notifikasi.
  ///
  /// Dipanggil modul yang benar-benar mengirim notifikasi; [waktu] boleh diisi
  /// agar cocok dengan waktu notifikasi aslinya.
  Future<NotifikasiRiwayatData> catat({
    int? pengingatId,
    String tingkat = 'biasa',
    String kanal = 'push',
    required String judul,
    required String isi,
    String status = 'baru',
    String sumber = 'lain',
    DateTime? waktu,
  }) async {
    final id = await db.into(db.notifikasiRiwayat).insert(
          NotifikasiRiwayatCompanion.insert(
            pengingatId: Value(pengingatId),
            waktu: waktu ?? _sekarang(),
            tingkat: Value(tingkat),
            kanal: Value(kanal),
            judul: judul,
            isi: isi,
            status: Value(status),
            sumber: Value(sumber),
          ),
        );
    return (db.select(db.notifikasiRiwayat)..where((t) => t.id.equals(id)))
        .getSingle()
        .timeout(batasBacaNotifikasi);
  }

  /// Tandai satu baris sebagai sudah dibaca. 0 berarti baris tidak ditemukan.
  Future<int> tandaiDibaca(int id) => _ubahStatus(id, StatusNotifikasi.dibaca);

  /// Tandai SEMUA baris "baru" sebagai sudah dibaca. Mengembalikan jumlah baris.
  Future<int> tandaiDibacaSemua() =>
      (db.update(db.notifikasiRiwayat)
            ..where((t) => t.status.equals(StatusNotifikasi.baru.nilaiDb)))
          .write(NotifikasiRiwayatCompanion(
        status: Value(StatusNotifikasi.dibaca.nilaiDb),
      ))
          .timeout(batasBacaNotifikasi);

  /// Tandai satu baris selesai, beserta waktu penyelesaiannya.
  Future<int> tandaiSelesai(int id, {DateTime? pada}) => _ubahStatus(
        id,
        StatusNotifikasi.selesai,
        selesaiPada: pada ?? _sekarang(),
      );

  /// Tandai satu baris ditunda (waktunya disimpan di tabel tunda_pengingat).
  Future<int> tandaiDitunda(int id) =>
      _ubahStatus(id, StatusNotifikasi.ditunda);

  Future<int> _ubahStatus(
    int id,
    StatusNotifikasi status, {
    DateTime? selesaiPada,
  }) =>
      (db.update(db.notifikasiRiwayat)..where((t) => t.id.equals(id)))
          .write(NotifikasiRiwayatCompanion(
            status: Value(status.nilaiDb),
            selesaiPada: selesaiPada == null
                ? const Value.absent()
                : Value(selesaiPada),
          ))
          .timeout(batasBacaNotifikasi);

  /// Hapus satu baris riwayat (dipakai tombol hapus pada layar).
  Future<int> hapus(int id) =>
      (db.delete(db.notifikasiRiwayat)..where((t) => t.id.equals(id)))
          .go()
          .timeout(batasBacaNotifikasi);

  // -------------------------------------------------------------------
  // BACA
  // -------------------------------------------------------------------

  /// Daftar riwayat, terbaru lebih dulu.
  Future<List<NotifikasiRiwayatData>> daftar({
    String? tingkat,
    bool hanyaBelumDibaca = false,
    int batas = 200,
  }) {
    final q = db.select(db.notifikasiRiwayat);
    if (tingkat != null && tingkat.isNotEmpty) {
      q.where((t) => t.tingkat.equals(tingkat));
    }
    if (hanyaBelumDibaca) {
      q.where((t) => t.status.equals(StatusNotifikasi.baru.nilaiDb));
    }
    q
      ..orderBy([
        (t) => OrderingTerm.desc(t.waktu),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(batas < 1 ? 1 : batas);
    return q.get().timeout(batasBacaNotifikasi);
  }

  /// Versi aliran untuk layar.
  Stream<List<NotifikasiRiwayatData>> watchDaftar({int batas = 200}) =>
      (db.select(db.notifikasiRiwayat)
            ..orderBy([
              (t) => OrderingTerm.desc(t.waktu),
              (t) => OrderingTerm.desc(t.id),
            ])
            ..limit(batas))
          .watch();

  /// Jumlah baris belum dibaca (badge di layar). 0 = "Belum ada data baru".
  Future<int> jumlahBelumDibaca() =>
      hitung(status: StatusNotifikasi.baru.nilaiDb);

  /// Jumlah baris menurut status (null = semua).
  Future<int> hitung({String? status}) {
    final q = db.selectOnly(db.notifikasiRiwayat)
      ..addColumns([db.notifikasiRiwayat.id.count()]);
    if (status != null && status.isNotEmpty) {
      q.where(db.notifikasiRiwayat.status.equals(status));
    }
    return q
        .map((r) => r.read(db.notifikasiRiwayat.id.count()) ?? 0)
        .getSingle()
        .timeout(batasBacaNotifikasi);
  }

  /// Jumlah per tingkat — bahan ringkasan di layar (bukti angka, bukan klaim).
  Future<Map<TingkatNotifikasi, int>> hitungPerTingkat() async {
    final hasil = <TingkatNotifikasi, int>{};
    for (final t in TingkatNotifikasi.values) {
      hasil[t] = await _hitungTingkat(t);
    }
    return hasil;
  }

  Future<int> _hitungTingkat(TingkatNotifikasi t) {
    final q = db.selectOnly(db.notifikasiRiwayat)
      ..addColumns([db.notifikasiRiwayat.id.count()])
      ..where(db.notifikasiRiwayat.tingkat.equals(t.nilaiDb));
    return q
        .map((r) => r.read(db.notifikasiRiwayat.id.count()) ?? 0)
        .getSingle()
        .timeout(batasBacaNotifikasi);
  }
}

// ---------------------------------------------------------------------------
// FR-148 — Penundaan pengingat
// ---------------------------------------------------------------------------

/// Akses tabel `tunda_pengingat`: satu baris per pengingat (unik).
///
/// Aturan yang dipegang: **jatuh tempo asli tidak pernah ditulis** ke tabel ini
/// maupun diubah di tabel tagihan/tugas. Yang bergeser hanya waktu pengingat.
class TundaPengingatRepository {
  TundaPengingatRepository(this.db, {this.jam});

  final AppDatabase db;

  /// Sumber waktu (null = satu sumber waktu aplikasi).
  final DateTime Function()? jam;

  DateTime _sekarang() => (jam ?? waktuSekarang)();

  /// Baris tunda milik satu pengingat (null = belum pernah ditunda).
  Future<TundaPengingatData?> ambil(int pengingatId) =>
      (db.select(db.tundaPengingat)
            ..where((t) => t.pengingatId.equals(pengingatId)))
          .getSingleOrNull()
          .timeout(batasBacaNotifikasi);

  /// Semua baris tunda (untuk pemeriksaan & pekerja latar).
  Future<List<TundaPengingatData>> daftar() =>
      (db.select(db.tundaPengingat)
            ..orderBy([(t) => OrderingTerm.asc(t.kapan)]))
          .get()
          .timeout(batasBacaNotifikasi);

  /// Simpan atau perbarui baris tunda untuk satu pengingat.
  ///
  /// Satu pengingat = satu baris, jadi penundaan berikutnya memperbarui baris
  /// yang sama dan menaikkan [jumlahTunda].
  Future<TundaPengingatData> simpan({
    required int pengingatId,
    required DateTime kapan,
    int jumlahTunda = 1,
    String? alasan,
  }) =>
      db.transaction(() async {
        final ada = await (db.select(db.tundaPengingat)
              ..where((t) => t.pengingatId.equals(pengingatId)))
            .getSingleOrNull();
        final companion = TundaPengingatCompanion(
          pengingatId: Value(pengingatId),
          kapan: Value(kapan),
          alasan: Value(alasan),
          jumlahTunda: Value(jumlahTunda),
          dibuatPada: Value(_sekarang()),
        );
        if (ada == null) {
          await db.into(db.tundaPengingat).insert(companion);
        } else {
          await (db.update(db.tundaPengingat)
                ..where((t) => t.pengingatId.equals(pengingatId)))
              .write(companion);
        }
        return (db.select(db.tundaPengingat)
                ..where((t) => t.pengingatId.equals(pengingatId)))
            .getSingle()
            .timeout(batasBacaNotifikasi);
      });

  /// Hapus baris tunda satu pengingat (mis. saat pengingat sudah dijalankan).
  Future<int> hapus(int pengingatId) =>
      (db.delete(db.tundaPengingat)
            ..where((t) => t.pengingatId.equals(pengingatId)))
          .go()
          .timeout(batasBacaNotifikasi);

  /// Terapkan penundaan memakai aturan murni FR-148.
  ///
  /// Menghitung waktu pengingat baru, menyimpan baris tunda, lalu mengembalikan
  /// hasilnya. [jatuhTempoAsli] **hanya dibaca** dan dikembalikan apa adanya di
  /// dalam [HasilTunda] sebagai bukti bahwa tanggal aslinya tidak bergeser.
  /// Melempar [BatasTundaTerlampaui] bila batas 3 kali sudah tercapai.
  Future<HasilTunda> terapkan({
    required int pengingatId,
    required DateTime jatuhTempoAsli,
    required PilihanTunda pilihan,
    String? alasan,
  }) async {
    final ada = await ambil(pengingatId);
    final hasil = terapkanTunda(
      pengingatId: pengingatId,
      jatuhTempoAsli: jatuhTempoAsli,
      pilihan: pilihan,
      jumlahTundaSebelumnya: ada?.jumlahTunda ?? 0,
      sekarang: _sekarang(),
      alasan: alasan,
    );
    await simpan(
      pengingatId: pengingatId,
      kapan: hasil.waktuPengingatBaru,
      jumlahTunda: hasil.jumlahTunda,
      alasan: alasan,
    );
    return hasil;
  }
}
