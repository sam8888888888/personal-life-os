/// Repositori tagihan — CRUD + aturan pelunasan/rollover (PRD §10.3).
library;

import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/laporan/ekspor_csv.dart';
import '../../core/utils/tanggal_utils.dart';
import '../database/database.dart';
import '../model/enums.dart';
import 'periode.dart';

class TagihanRepository {
  TagihanRepository(this.db);
  final AppDatabase db;

  /// Tagihan aktif, urut jatuh tempo terdekat.
  Stream<List<TagihanData>> watchAktif() => (db.select(db.tagihan)
        ..where((t) => t.statusAktif.equals(true))
        ..orderBy([
          (t) => OrderingTerm.asc(t.jatuhTempo),
          (t) => OrderingTerm.asc(t.id),
        ]))
      .watch();

  Stream<List<TagihanData>> watchSemua() =>
      (db.select(db.tagihan)..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();

  /// Ambil semua tagihan sekali (bukan stream) — dipakai penyinkron pengingat
  /// dan pekerja latar yang tidak butuh pembaruan langsung.
  Future<List<TagihanData>> ambilSemua() =>
      (db.select(db.tagihan)..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)])).get();

  /// Uid baru untuk sinkron antar HP (FR-150).
  ///
  /// Sengaja tidak memakai paket uuid: cukup unik dan tidak bergantung waktu
  /// perangkat yang bisa berbeda antar HP.
  static String uidBaru([Random? acak]) {
    final r = acak ?? Random();
    final bagian = List.generate(4, (_) => r.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'));
    return bagian.join();
  }

  Future<TagihanData> tambah(TagihanCompanion c) {
    // uid diisi di sini supaya semua jalur (form, contoh data, impor) ikut aman.
    final denganUid = (c.uid.present && (c.uid.value ?? '').isNotEmpty)
        ? c
        : c.copyWith(uid: Value(uidBaru()));
    return db.transaction(() async {
      final hasil = await db.into(db.tagihan).insertReturning(denganUid);
      await tandaiKotor(hasil.uid!);
      return hasil;
    });
  }

  /// Tandai satu baris (lewat id angka) sebagai perlu dikirim.
  ///
  /// Dipakai jalur ubah yang tidak lewat [ubah]: nonaktifkan, tandai lunas,
  /// undo lunas. tanpa ini, perubahan itu tidak akan pernah sampai ke HP lain.
  Future<void> tandaiUidDari(int id) async {
    final baris =
        await (db.select(db.tagihan)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (baris?.uid != null) await tandaiKotor(baris!.uid!);
  }

  /// Catat bahwa satu baris (uid) perlu dikirim ke server.
  ///
  /// Aman dipanggil berkali-kali: penanda digabung (upsert) per uid, dan kalau
  /// baris ini pernah ditandai hapus, tanda hapus yang menang.
  Future<void> tandaiKotor(String uid, {bool hapus = false}) async {
    final lama = await (db.select(db.sinkronKotor)
          ..where((k) => k.tabel.equals('tagihan') & k.uid.equals(uid)))
        .getSingleOrNull();
    await db.into(db.sinkronKotor).insertOnConflictUpdate(
          SinkronKotorCompanion.insert(
            tabel: 'tagihan',
            uid: uid,
            hapus: Value(hapus || (lama?.hapus ?? false)),
            waktu: DateTime.now(),
          ),
        );
  }

  /// Semua baris ber-uid (untuk sinkron); baris tanpa uid (belum tersentuh
  /// sejak v6) tetap tidak ikut supaya tidak ada data separuh jadi.
  Future<List<TagihanData>> semuaUntukSinkron() =>
      (db.select(db.tagihan)..where((t) => t.uid.isNotNull())).get();

  /// Terapkan satu baris kiriman server, dicocokkan lewat uid (bukan id angka).
  Future<void> terapDariServer({
    required String uid,
    required Map<String, dynamic> isi,
    required DateTime waktu,
    required bool dihapus,
  }) async {
    await db.transaction(() async {
      final lama = await (db.select(db.tagihan)..where((t) => t.uid.equals(uid)))
          .getSingleOrNull();
      if (dihapus) {
        if (lama != null) {
          await (db.delete(db.tagihan)..where((t) => t.id.equals(lama.id))).go();
        }
        return;
      }
      final nilai = TagihanCompanion(
        uid: Value(uid),
        jenis: Value(isi['jenis'] as String? ?? 'tagihan'),
        nama: Value(isi['nama'] as String? ?? '(tanpa nama)'),
        jumlahSen: Value(isi['jumlah_sen'] as int?),
        kodeMataUang: Value(isi['kode_mata_uang'] as String? ?? 'IDR'),
        kategoriId: Value(isi['kategori_id'] as int?),
        jatuhTempo: Value(DateTime.fromMillisecondsSinceEpoch(
            isi['jatuh_tempo_ms'] as int? ?? 0)),
        frekuensi: Value(isi['frekuensi'] as String? ?? 'bulanan'),
        kustomHariN: Value(isi['kustom_hari_n'] as int?),
        pengingatLeadHari: Value(isi['pengingat_lead_hari'] as String? ?? '7,3,1'),
        pengingatJam: Value(isi['pengingat_jam'] as String? ?? '09:00'),
        kanalPengingat: Value(isi['kanal_pengingat'] as String? ?? 'push'),
        prioritas: Value(isi['prioritas'] as String? ?? 'biasa'),
        catatan: Value(isi['catatan'] as String?),
        tautanBayar: Value(isi['tautan_bayar'] as String?),
        statusAktif: Value(isi['status_aktif'] as bool? ?? true),
        lunas: Value(isi['lunas'] as bool? ?? false),
        tanggalLunas: Value(isi['tanggal_lunas_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(isi['tanggal_lunas_ms'] as int)),
        diubahPada: Value(waktu),
      );
      if (lama == null) {
        await db.into(db.tagihan).insert(nilai);
      } else if (!waktu.isBefore(lama.diubahPada)) {
        await (db.update(db.tagihan)..where((t) => t.id.equals(lama.id)))
            .write(denganUid(nilai, lama.uid));
      }
      // Baris ini datang dari server: jangan pernah dikirim balik (kalau tidak,
      // penghapusan di HP lain bisa hidup lagi di sini).
      await (db.delete(db.sinkronKotor)
            ..where((k) => k.tabel.equals('tagihan') & k.uid.equals(uid)))
          .go();
    });
  }

  static TagihanCompanion denganUid(TagihanCompanion c, String? uid) =>
      uid == null ? c : c.copyWith(uid: Value(uid));

  /// Data satu baris untuk dikirim ke server.
  static Map<String, dynamic> kePeta(TagihanData t) => {
        'uid': t.uid,
        'jenis': t.jenis,
        'nama': t.nama,
        'jumlah_sen': t.jumlahSen,
        'kode_mata_uang': t.kodeMataUang,
        'kategori_id': t.kategoriId,
        'jatuh_tempo_ms': t.jatuhTempo.millisecondsSinceEpoch,
        'frekuensi': t.frekuensi,
        'kustom_hari_n': t.kustomHariN,
        'pengingat_lead_hari': t.pengingatLeadHari,
        'pengingat_jam': t.pengingatJam,
        'kanal_pengingat': t.kanalPengingat,
        'prioritas': t.prioritas,
        'catatan': t.catatan,
        'tautan_bayar': t.tautanBayar,
        'status_aktif': t.statusAktif,
        'lunas': t.lunas,
        'tanggal_lunas_ms': t.tanggalLunas?.millisecondsSinceEpoch,
      };


  /// Update sebagian; mengembalikan jumlah baris berubah.
  Future<int> ubah(TagihanCompanion c, {required int id}) async {
    return db.transaction(() async {
      final baris = (await (db.update(db.tagihan)..where((t) => t.id.equals(id)))
              .write(c.copyWith(id: Value(id), diubahPada: Value(DateTime.now()))));
      final sesudah =
          await (db.select(db.tagihan)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (sesudah?.uid != null) await tandaiKotor(sesudah!.uid!);
      return baris;
    });
  }

  /// Hapus permanen beserta riwayatnya.
  ///
  /// Skema v3 (langganan & kas) — baris lain **tidak** ikut dihapus:
  /// * `Langganan` yang menaut tagihan ini ditutup (`berhenti`) dan tautannya
  ///   dikosongkan, supaya tidak ada langganan yang menunjuk tagihan hilang;
  /// * `Transaksi` yang bertaut tetap ada, hanya `tagihanId` dikosongkan —
  ///   uangnya benar-benar keluar, jadi riwayat kas tidak boleh hilang diam
  ///   diam (aturan MASTER: baris jangan hilang, nilai dikosongkan + catatan).
  Future<void> hapus(int id) => db.transaction(() async {
        // FR-150: catat penanda hapus supaya HP lain ikut menghapus.
        final hendakDihapus = await (db.select(db.tagihan)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (hendakDihapus?.uid != null) {
          await tandaiKotor(hendakDihapus!.uid!, hapus: true);
        }
        await (db.update(db.langganan)..where((l) => l.tagihanId.equals(id)))
            .write(LanggananCompanion(
          tagihanId: const Value(null),
          status: Value(StatusLangganan.berhenti.nilaiDb),
          diubahPada: Value(DateTime.now()),
        ));
        await (db.update(db.transaksi)..where((t) => t.tagihanId.equals(id)))
            .write(TransaksiCompanion(
          tagihanId: const Value(null),
          diubahPada: Value(DateTime.now()),
        ));
        await (db.delete(db.riwayatPembayaran)
              ..where((r) => r.tagihanId.equals(id)))
            .go();
        await (db.delete(db.tagihan)..where((t) => t.id.equals(id))).go();
      });

  /// Nonaktifkan tagihan berulang tanpa menghapus riwayat.
  Future<int> nonaktifkan(int id) => db.transaction(() async {
        final n = await (db.update(db.tagihan)..where((t) => t.id.equals(id)))
            .write(TagihanCompanion(
                statusAktif: const Value(false),
                diubahPada: Value(DateTime.now())));
        await tandaiUidDari(id);
        return n;
      });

  /// Tandai lunas: catat riwayat, geser periode berikutnya
  /// (day-clamping 31 Jan -> 28/29 Feb). Tagihan sekali -> nonaktif.
  Future<RiwayatPembayaranData> tandaiLunas(int id,
      {DateTime? tanggalBayar,
      int? jumlahOverrideSen,
      DateTime? periodeYangDibayar}) async {
    return db.transaction(() async {
      final t = await (db.select(db.tagihan)..where((x) => x.id.equals(id)))
          .getSingle();
      final tglBayar = tanggalBayar ?? DateTime.now();
      final periode = t.jatuhTempo;

      // PB-06: SATU PERIODE = SATU PEMBAYARAN (idempoten).
      //
      // [periodeYangDibayar] = periode yang dilihat/dimaksud pemanggil (dari
      // kartu di layar atau dari payload notifikasi). Bila periode itu bukan
      // periode aktif lagi, artinya aksi datang dari tampilan/notifikasi lama:
      //   - sudah pernah dibayar -> kembalikan catatannya (tidak menggandakan,
      //     tidak menggeser periode dua kali),
      //   - belum pernah dibayar -> tolak dengan pesan jelas.
      // Tanpa [periodeYangDibayar], pemeriksaan tetap memakai periode aktif.
      Future<RiwayatPembayaranData?> cariCatatan(DateTime p) =>
          (db.select(db.riwayatPembayaran)
                ..where((r) =>
                    r.tagihanId.equals(id) & r.periodeJatuhTempo.equals(p))
                ..orderBy([(r) => OrderingTerm.desc(r.id)])
                ..limit(1))
              .getSingleOrNull();

      if (periodeYangDibayar != null &&
          selisihHari(periode, periodeYangDibayar) != 0) {
        final sudahDibayar = await cariCatatan(periodeYangDibayar);
        if (sudahDibayar != null) return sudahDibayar;
        throw StateError(
            'Aksi ini untuk periode ${fmtTanggalAman(periodeYangDibayar)}, '
            'sedangkan periode aktif sekarang ${fmtTanggalAman(periode)}.');
      }

      final catatanAktif = await cariCatatan(periode);
      if (catatanAktif != null) return catatanAktif;
      final telat = selisihHari(periode, tglBayar);
      final jumlah = jumlahOverrideSen ?? t.jumlahSen ?? 0;

      final riwayatId = await db.into(db.riwayatPembayaran).insert(
            RiwayatPembayaranCompanion.insert(
              tagihanId: id,
              periodeJatuhTempo: periode,
              jumlahSen: jumlah,
              kodeMataUang: Value(t.kodeMataUang),
              tanggalBayar: tglBayar,
              telatHari: telat > 0 ? Value(telat) : const Value(null),
            ),
          );

      final f = Frekuensi.dariDb(t.frekuensi);
      final penutup = f == Frekuensi.sekali
          ? TagihanCompanion(
              lunas: const Value(true),
              tanggalLunas: Value(tglBayar),
              statusAktif: const Value(false),
              diubahPada: Value(DateTime.now()),
            )
          : TagihanCompanion(
              jatuhTempo: Value(periodeBerikutnya(periode, f, kustomHariN: t.kustomHariN)),
              lunas: const Value(false),
              tanggalLunas: const Value(null),
              diubahPada: Value(DateTime.now()),
            );
      await (db.update(db.tagihan)..where((x) => x.id.equals(id))).write(penutup);
      await tandaiUidDari(id);

      return (db.select(db.riwayatPembayaran)..where((r) => r.id.equals(riwayatId)))
          .getSingle();
    });
  }

  /// Batalkan status lunas (undo) — kembalikan periode sebelumnya.
  Future<void> undoLunas(int id) => db.transaction(() async {
        final riwayatTerakhir = await (db.select(db.riwayatPembayaran)
              ..where((r) => r.tagihanId.equals(id))
              ..orderBy([(r) => OrderingTerm.desc(r.id)])
              ..limit(1))
            .getSingleOrNull();
        if (riwayatTerakhir == null) return;
        await (db.delete(db.riwayatPembayaran)
              ..where((r) => r.id.equals(riwayatTerakhir.id)))
            .go();
        await (db.update(db.tagihan)..where((x) => x.id.equals(id))).write(
              TagihanCompanion(
                jatuhTempo: Value(riwayatTerakhir.periodeJatuhTempo),
                lunas: const Value(false),
                tanggalLunas: const Value(null),
                statusAktif: const Value(true),
                diubahPada: Value(DateTime.now()),
              ),
            );
        await tandaiUidDari(id);
      });

  /// FR-09: salin satu tagihan sebagai tagihan baru (siap disunting).
  ///
  /// Yang disalin: jenis, nominal, mata uang, kategori, frekuensi, jadwal
  /// pengingat, catatan, dan tautan bayar. Yang direset: `lunas`,
  /// `tanggalLunas` (salinan selalu mulai belum dibayar) dan `uid` baru supaya
  /// sinkron antar HP tidak menganggapnya baris yang sama.
  ///
  /// [namaBaru] boleh diisi; bawaan = nama lama + " (salinan)".
  Future<int> duplikat(int id, {String? namaBaru, DateTime? jatuhTempoBaru}) async {
    final asal = await (db.select(db.tagihan)..where((t) => t.id.equals(id)))
        .getSingle();
    final kini = DateTime.now();
    return db.into(db.tagihan).insert(TagihanCompanion.insert(
          uid: Value(uidBaru()),
          jenis: Value(asal.jenis),
          nama: namaBaru ?? '${asal.nama} (salinan)',
          jumlahSen: Value(asal.jumlahSen),
          kodeMataUang: Value(asal.kodeMataUang),
          kategoriId: Value(asal.kategoriId),
          jatuhTempo: jatuhTempoBaru ?? asal.jatuhTempo,
          frekuensi: Value(asal.frekuensi),
          kustomHariN: Value(asal.kustomHariN),
          pengingatLeadHari: Value(asal.pengingatLeadHari),
          pengingatJam: Value(asal.pengingatJam),
          kanalPengingat: Value(asal.kanalPengingat),
          prioritas: Value(asal.prioritas),
          catatan: Value(asal.catatan),
          tautanBayar: Value(asal.tautanBayar),
          statusAktif: Value(asal.statusAktif),
          lunas: const Value(false),
          dibuatPada: Value(kini),
          diubahPada: Value(kini),
        ));
  }

  /// Semua riwayat pembayaran + nama tagihannya (FR-25 ekspor CSV).
  ///
  /// Nama diambil dari tagihan; kalau tagihannya sudah dihapus, ditulis
  /// "(tagihan dihapus)" — riwayat uangnya TIDAK dihilangkan.
  Future<List<BarisRiwayatCsv>> riwayatUntukEkspor() async {
    final kueri = db.select(db.riwayatPembayaran).join([
      leftOuterJoin(db.tagihan, db.tagihan.id.equalsExp(db.riwayatPembayaran.tagihanId)),
    ])
      ..orderBy([OrderingTerm.desc(db.riwayatPembayaran.tanggalBayar)]);
    final baris = await kueri.get();
    return baris.map((b) {
      final rp = b.readTable(db.riwayatPembayaran);
      final tg = b.readTableOrNull(db.tagihan);
      return BarisRiwayatCsv(
        namaTagihan: tg?.nama ?? '(tagihan dihapus)',
        periode: rp.periodeJatuhTempo,
        tanggalBayar: rp.tanggalBayar,
        jumlahSen: rp.jumlahSen,
        kodeMataUang: rp.kodeMataUang,
        telatHari: rp.telatHari,
      );
    }).toList();
  }

  /// Tagihan aktif belum lunas yang jatuh tempo dalam [dalamHari] ke depan.
  Stream<List<TagihanData>> watchJatuhTempoDalam(int dalamHari,
      {DateTime? acuan}) {
    final sekarang = acuan ?? DateTime.now();
    final dari = DateTime(sekarang.year, sekarang.month, sekarang.day);
    // Batas atas EKSKLUSIF: awal hari setelah hari terakhir jendela. Memakai
    // tengah malam hari terakhir akan membuang tagihan hari itu.
    final sampaiEksklusif =
        DateTime(dari.year, dari.month, dari.day + dalamHari + 1);
    return (db.select(db.tagihan)
          ..where((t) =>
              t.statusAktif.equals(true) &
              t.lunas.equals(false) &
              t.jatuhTempo.isBiggerOrEqualValue(dari) &
              t.jatuhTempo.isSmallerThanValue(sampaiEksklusif))
          ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)]))
        .watch();
  }

  /// Total semua kewajiban terbuka (sen) — seluruh tagihan aktif belum lunas.
  Future<int> totalTerbukaSen() async {
    final semua = await (db.select(db.tagihan)
          ..where((t) => t.statusAktif.equals(true) & t.lunas.equals(false)))
        .get();
    var total = 0;
    for (final t in semua) {
      total += t.jumlahSen ?? 0;
    }
    return total;
  }

  /// Total tagihan aktif belum lunas dalam bulan kalender [bulan] (sen).
  /// Dipakai dasbor "tagihan bulan ini" (FR-08/FR-33).
  Future<int> totalBelumBayarBulanSen(DateTime bulan) async {
    // Batas atas EKSKLUSIF (awal bulan berikutnya): memakai tengah malam
    // tanggal terakhir akan mengecilkan total bila tagihan punya jam.
    final r = rentangBulan(bulan);
    final daftar = await (db.select(db.tagihan)
          ..where((t) =>
              t.statusAktif.equals(true) &
              t.lunas.equals(false) &
              t.jatuhTempo.isBiggerOrEqualValue(r.awal) &
              t.jatuhTempo.isSmallerThanValue(r.akhirEksklusif)))
        .get();
    var total = 0;
    for (final t in daftar) {
      total += t.jumlahSen ?? 0;
    }
    return total;
  }

  /// PB-08: satu baris PERIODE untuk tampilan bulan.
  ///
  /// Berbeda dari [TagihanData] yang hanya menyimpan keadaan sekarang, baris ini
  /// mewakili kejadian: bisa berasal dari catatan pembayaran (sudah dibayar) atau
  /// dari tagihan aktif yang belum dibayar pada bulan tersebut.
  Future<List<BarisPeriode>> periodeBulan(DateTime bulan) async {
    // Batas atas EKSKLUSIF: awal bulan berikutnya (lihat `rentangBulan`).
    final r = rentangBulan(bulan);
    final awal = r.awal;
    final akhirEksklusif = r.akhirEksklusif;
    final tagihan = await ambilSemua();
    final namaTagihan = {for (final t in tagihan) t.id: t.nama};

    final catatan = await (db.select(db.riwayatPembayaran)
          ..where((r) =>
              r.periodeJatuhTempo.isBiggerOrEqualValue(awal) &
              r.periodeJatuhTempo.isSmallerThanValue(akhirEksklusif))
          ..orderBy([(r) => OrderingTerm.asc(r.periodeJatuhTempo)]))
        .get();

    final hasil = <BarisPeriode>[
      for (final r in catatan)
        BarisPeriode(
          tagihanId: r.tagihanId,
          nama: namaTagihan[r.tagihanId] ?? 'Tagihan #${r.tagihanId}',
          periode: r.periodeJatuhTempo,
          jumlahSen: r.jumlahSen,
          lunas: true,
          tanggalBayar: r.tanggalBayar,
          dariRiwayat: true,
        ),
      for (final t in tagihan.where((t) =>
          t.statusAktif &&
          !t.lunas &&
          !t.jatuhTempo.isBefore(awal) &&
          t.jatuhTempo.isBefore(akhirEksklusif) &&
          !catatan.any((r) =>
              r.tagihanId == t.id &&
              selisihHari(r.periodeJatuhTempo, t.jatuhTempo) == 0)))
        BarisPeriode(
          tagihanId: t.id,
          nama: t.nama,
          periode: t.jatuhTempo,
          jumlahSen: t.jumlahSen ?? 0,
          lunas: false,
        ),
    ]..sort((a, b) => a.periode.compareTo(b.periode));
    return hasil;
  }

  /// PB-08: ringkasan angka satu bulan (dipakai dasbor).
  Future<RingkasanBulan> ringkasanBulan(DateTime bulan) async =>
      RingkasanBulan(baris: await periodeBulan(bulan));
}

/// Satu periode tagihan pada tampilan bulan (PB-08).
class BarisPeriode {
  const BarisPeriode({
    required this.tagihanId,
    required this.nama,
    required this.periode,
    required this.jumlahSen,
    required this.lunas,
    this.tanggalBayar,
    this.dariRiwayat = false,
  });

  final int tagihanId;
  final String nama;
  final DateTime periode;
  final int jumlahSen;
  final bool lunas;
  final DateTime? tanggalBayar;

  /// true = berasal dari catatan pembayaran (sudah dibayar).
  final bool dariRiwayat;
}

/// Angka ringkas satu bulan untuk dasbor (PB-08).
class RingkasanBulan {
  const RingkasanBulan({required this.baris});

  final List<BarisPeriode> baris;

  int get totalSen => baris.fold<int>(0, (a, b) => a + b.jumlahSen);
  int get dibayarSen =>
      baris.where((b) => b.lunas).fold<int>(0, (a, b) => a + b.jumlahSen);
  int get belumSen => totalSen - dibayarSen;
  int get jumlahBelum => baris.where((b) => !b.lunas).length;
}
