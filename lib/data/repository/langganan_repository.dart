/// Repositori langganan berulang (FR-68) — memperluas mesin tagihan FR-03/FR-16.
///
/// Rancangan sengaja TIDAK membuat mesin pengingat baru: langganan menaut ke
/// satu baris `Tagihan` (kolom `tagihanId`), dan pengingat tetap dijadwalkan
/// oleh `lib/core/notifikasi/**` dari tabel Tagihan. Karena itu:
///
/// * `pause`  → tagihan tertaut dinonaktifkan (`statusAktif = false`) sehingga
///   pengingat berhenti **tanpa menghapus riwayat** (kriteria terima FR-68);
/// * `aktifkan` → tagihan tertaut dihidupkan lagi;
/// * `berhenti` → langganan selesai, tagihan tertaut juga dinonaktifkan.
///
/// Riwayat pembayaran tetap ada di `RiwayatPembayaran` (tidak disentuh).
library;

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../model/enums.dart';

class LanggananRepository {
  LanggananRepository(this.db);

  final AppDatabase db;

  /// Pengenal stabil baru (`lgn_<microseconds>`).
  static String idBaru() => 'lgn_${DateTime.now().microsecondsSinceEpoch}';

  Future<LanggananData> tambah({
    required String nama,
    required int nominalSen,
    required DateTime tanggalMulai,
    Frekuensi siklus = Frekuensi.bulanan,
    String? idLangganan,
    int? tagihanId,
    int? kategoriId,
    bool perpanjangOtomatis = true,
    StatusLangganan status = StatusLangganan.aktif,
    String? metodeBayar,
    String? tautanBayar,
    String? catatan,
  }) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama langganan tidak boleh kosong.');
    }
    if (nominalSen < 0) {
      throw ArgumentError('Nominal langganan tidak boleh negatif.');
    }
    final l = await db.into(db.langganan).insertReturning(
          LanggananCompanion.insert(
            idLangganan: idLangganan ?? idBaru(),
            nama: bersih,
            tanggalMulai: tanggalMulai,
            nominalSen: Value(nominalSen),
            siklus: Value(siklus.nilaiDb),
            tagihanId: Value(tagihanId),
            kategoriId: Value(kategoriId),
            perpanjangOtomatis: Value(perpanjangOtomatis),
            status: Value(status.nilaiDb),
            metodeBayar: Value(metodeBayar),
            tautanBayar: Value(tautanBayar),
            catatan: Value(catatan),
          ),
        );
    await _selaraskanPengingat(l);
    return l;
  }

  Future<LanggananData?> ambilSatu(int id) =>
      (db.select(db.langganan)..where((l) => l.id.equals(id))).getSingleOrNull();

  Stream<List<LanggananData>> watchSemua() => (db.select(db.langganan)
        ..orderBy([
          (l) => OrderingTerm.asc(l.status),
          (l) => OrderingTerm.asc(l.nama),
        ]))
      .watch();

  /// Semua langganan yang belum berhenti (aktif + pause) — bahan daftar UI.
  Stream<List<LanggananData>> watchBelumBerhenti() => (db.select(db.langganan)
        ..where((l) => l.status.equals(StatusLangganan.berhenti.nilaiDb).not())
        ..orderBy([(l) => OrderingTerm.asc(l.nama)]))
      .watch();

  /// Hanya yang aktif — bahan penjadwalan/ringkasan biaya berulang.
  Future<List<LanggananData>> ambilAktif() => (db.select(db.langganan)
        ..where((l) => l.status.equals(StatusLangganan.aktif.nilaiDb))
        ..orderBy([(l) => OrderingTerm.asc(l.nama)]))
      .get();

  /// Ubah sebagian kolom. `null` berarti **tidak diubah** (bukan "kosongkan").
  ///
  /// Untuk mengosongkan kategori langganan, pakai [kosongkanKategori] = true:
  /// kolom `kategoriId` bertipe nullable, jadi `kategoriId: null` tidak bisa
  /// dibedakan dari "tidak diubah". Sebelum ini layar terpaksa menulis langsung
  /// ke tabel — aturan itu sekarang tinggal di satu tempat.
  Future<int> ubah(
    int id, {
    String? nama,
    int? nominalSen,
    Frekuensi? siklus,
    bool? perpanjangOtomatis,
    int? kategoriId,
    bool kosongkanKategori = false,
    String? metodeBayar,
    String? tautanBayar,
    String? catatan,
  }) async {
    if (nominalSen != null && nominalSen < 0) {
      throw ArgumentError('Nominal langganan tidak boleh negatif.');
    }
    if (kosongkanKategori && kategoriId != null) {
      throw ArgumentError(
          'Pilih salah satu: kategoriId diisi, atau kosongkanKategori = true.');
    }
    return (db.update(db.langganan)..where((l) => l.id.equals(id)))
        .write(LanggananCompanion(
      nama: nama == null ? const Value.absent() : Value(nama.trim()),
      nominalSen: nominalSen == null ? const Value.absent() : Value(nominalSen),
      siklus: siklus == null ? const Value.absent() : Value(siklus.nilaiDb),
      perpanjangOtomatis: perpanjangOtomatis == null
          ? const Value.absent()
          : Value(perpanjangOtomatis),
      kategoriId: kosongkanKategori
          ? const Value(null)
          : (kategoriId == null ? const Value.absent() : Value(kategoriId)),
      metodeBayar:
          metodeBayar == null ? const Value.absent() : Value(metodeBayar),
      tautanBayar:
          tautanBayar == null ? const Value.absent() : Value(tautanBayar),
      catatan: catatan == null ? const Value.absent() : Value(catatan),
      diubahPada: Value(DateTime.now()),
    ));
  }

  /// Pause: pengingat berhenti, riwayat tetap.
  Future<void> pause(int id, {DateTime? sampai}) async {
    await _ubahStatus(id, StatusLangganan.pause, sampai: sampai);
  }

  /// Kembali aktif: pengingat hidup lagi.
  Future<void> aktifkan(int id) =>
      _ubahStatus(id, StatusLangganan.aktif, hapusPause: true);

  /// Berhenti permanen (mis. langganan dibatalkan) — riwayat tetap tersimpan.
  Future<void> hentikan(int id) => _ubahStatus(id, StatusLangganan.berhenti);

  /// Tautkan ke tagihan (mesin pengingat lama). Satu tagihan hanya boleh
  /// dipakai satu langganan.
  Future<void> tautkanKeTagihan(int id, int tagihanId) async {
    final bentrok = await (db.select(db.langganan)
          ..where((l) => l.tagihanId.equals(tagihanId) & l.id.equals(id).not()))
        .getSingleOrNull();
    if (bentrok != null) {
      throw StateError(
          'Tagihan itu sudah dipakai langganan "${bentrok.nama}".');
    }
    await (db.update(db.langganan)..where((l) => l.id.equals(id)))
        .write(LanggananCompanion(
      tagihanId: Value(tagihanId),
      diubahPada: Value(DateTime.now()),
    ));
    final l = await ambilSatu(id);
    if (l != null) await _selaraskanPengingat(l);
  }

  /// Hapus baris langganan (FR-68).
  ///
  /// Aturan yang dijaga di sini — bukan di layar — supaya semua pemanggil sama:
  /// * tagihan tertaut **dihidupkan kembali** (pengingat tidak boleh mati
  ///   diam-diam; lebih aman pengingat berlebih yang bisa dimatikan pengguna);
  /// * tagihan dan **riwayat pembayaran tidak dihapus** — uangnya benar-benar
  ///   keluar, jadi riwayat tetap tersimpan;
  /// * satu transaksi database: kalau gagal, tidak ada yang setengah jalan.
  ///
  /// Untuk sekadar menghentikan pengingat, pakai [hentikan] atau [pause].
  Future<void> hapus(int id, {bool hidupkanTagihanTertaut = true}) async {
    final l = await ambilSatu(id);
    if (l == null) {
      throw StateError('Langganan tidak ditemukan.');
    }
    await db.transaction(() async {
      final tagihanId = l.tagihanId;
      if (hidupkanTagihanTertaut && tagihanId != null) {
        await _setTagihanAktif(tagihanId, true);
      }
      await (db.delete(db.langganan)..where((x) => x.id.equals(id))).go();
    });
  }

  /// Lepas tautan. Tagihan dihidupkan kembali supaya pengingat tidak mati
  /// diam-diam (lebih aman: pengingat berlebih masih bisa dimatikan pengguna).
  Future<void> lepasTautan(int id) async {
    final l = await ambilSatu(id);
    if (l == null) return;
    final tagihanId = l.tagihanId;
    await (db.update(db.langganan)..where((x) => x.id.equals(id)))
        .write(LanggananCompanion(
      tagihanId: const Value(null),
      diubahPada: Value(DateTime.now()),
    ));
    if (tagihanId != null) {
      await _setTagihanAktif(tagihanId, true);
    }
  }

  /// Ringkasan biaya langganan aktif per bulan (sen) — bahan FR-69/FR-71.
  ///
  /// Siklus non-bulanan dinormalkan ke bulanan memakai kelipatan tetap;
  /// nilai perkiraan (mis. mingguan) dibulatkan ke atas supaya tidak
  /// mengecilkan angka. Angka ini *perkiraan*, bukan tagihan.
  Future<int> totalBulananSen() async {
    final aktif = await ambilAktif();
    var total = 0;
    for (final l in aktif) {
      total += nominalBulananSen(l);
    }
    return total;
  }

  /// Nominal satu langganan bila dinormalkan ke satu bulan (sen).
  static int nominalBulananSen(LanggananData l) {
    final n = l.nominalSen;
    switch (Frekuensi.dariDb(l.siklus)) {
      case Frekuensi.mingguan:
        return (n * 52 / 12).ceil();
      case Frekuensi.duaMingguan:
        return (n * 26 / 12).ceil();
      case Frekuensi.bulanan:
        return n;
      case Frekuensi.duaBulanan:
        return (n / 2).ceil();
      case Frekuensi.kuartalan:
        return (n / 3).ceil();
      case Frekuensi.semesteran:
        return (n / 6).ceil();
      case Frekuensi.tahunan:
        return (n / 12).ceil();
      case Frekuensi.kustomHari:
        // Tabel langganan V1.5 belum menyimpan jumlah hari kustom; siklus ini
        // diperlakukan seperti bulanan supaya tidak menebak angka.
        return n;
      case Frekuensi.sekali:
        return 0;
    }
  }

  /// FR-70 — tandai langganan masih dipakai (memperbarui `terakhirDipakaiPada`).
  Future<void> tandaiDipakai(int id, {DateTime? kapan}) async {
    final waktu = kapan ?? DateTime.now();
    await (db.update(db.langganan)..where((l) => l.id.equals(id)))
        .write(LanggananCompanion(
      terakhirDipakaiPada: Value(waktu),
      diubahPada: Value(waktu),
    ));
  }

  /// FR-70 — nominal pembayaran terakhir per tagihan (sen) dari riwayat.
  ///
  /// Bukti "tarif mungkin naik": kalau pembayaran terakhir lebih besar daripada
  /// nominal langganan, angka langganan sudah tertinggal. Baris diurutkan waktu
  /// (lalu id) supaya pembayaran paling baru selalu menang.
  Future<Map<int, int>> pembayaranTerakhirPerTagihan() async {
    final rows = await (db.select(db.riwayatPembayaran)
          ..orderBy([
            (r) => OrderingTerm.asc(r.tanggalBayar),
            (r) => OrderingTerm.asc(r.id),
          ]))
        .get();
    final hasil = <int, int>{};
    for (final r in rows) {
      hasil[r.tagihanId] = r.jumlahSen;
    }
    return hasil;
  }

  Future<void> _ubahStatus(
    int id,
    StatusLangganan status, {
    DateTime? sampai,
    bool hapusPause = false,
  }) async {
    final l = await ambilSatu(id);
    if (l == null) {
      throw StateError('Langganan tidak ditemukan.');
    }
    final sekarang = DateTime.now();
    await (db.update(db.langganan)..where((x) => x.id.equals(id)))
        .write(LanggananCompanion(
      status: Value(status.nilaiDb),
      pauseSejak: hapusPause
          ? const Value(null)
          : (status == StatusLangganan.pause ? Value(sekarang) : const Value(null)),
      pauseSampai: hapusPause || status != StatusLangganan.pause
          ? const Value(null)
          : Value(sampai),
      diubahPada: Value(sekarang),
    ));
    final baru = await ambilSatu(id);
    if (baru != null) await _selaraskanPengingat(baru);
  }

  /// Satu-satunya tempat yang menyentuh `Tagihan.statusAktif` dari modul
  /// langganan — supaya aturan "pause menghentikan pengingat" hanya ada di satu
  /// tempat dan mudah ditelusuri.
  Future<void> _selaraskanPengingat(LanggananData l) async {
    final tagihanId = l.tagihanId;
    if (tagihanId == null) return;
    await _setTagihanAktif(tagihanId, StatusLangganan.dariDb(l.status).mengingatkan);
  }

  Future<void> _setTagihanAktif(int tagihanId, bool aktif) async {
    await (db.update(db.tagihan)..where((t) => t.id.equals(tagihanId)))
        .write(TagihanCompanion(
      statusAktif: Value(aktif),
      diubahPada: Value(DateTime.now()),
    ));
  }
}
