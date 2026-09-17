/// Repositori dokumen penting & masa berlakunya (FR-128, FR-129).
///
/// **Kejujuran soal berkas (penting).** FR-128 di PRD menyebut berkas
/// terenkripsi. Enkripsi belum ada di proyek ini, dan modul ini tidak menambah
/// paket baru. Karena itu kolom `berkas_nama` hanya mencatat **nama** berkas
/// fisik milik pengguna: isinya tidak pernah dibaca, tidak disalin, dan tidak
/// diklaim terenkripsi. Layar wajib menuliskan catatan itu apa adanya.
///
/// **Masa berlaku (FR-129).** Tiap baris menyimpan `lead_hari` berbentuk teks
/// ("90,30,7,1"). Modul ini hanya menyimpan & menghitung; penjadwalan
/// notifikasi ada di `lib/features/dokumen/pengingat_dokumen.dart` yang
/// menyerahkan hasilnya lewat `SumberPengingatTambahan`.
///
/// **Aturan hapus berdampingan (cascade) ada di sini**, bukan di layar:
/// menghapus dokumen juga membuang baris penundaan pengingat (tunda_pengingat)
/// milik ID pengingat dokumen itu, supaya tidak ada penundaan menggantung.
/// Riwayat notifikasi & catatan aktivitas sengaja TIDAK dihapus karena
/// keduanya buku catatan kejadian, bukan data turunan dokumen.
///
/// Waktu selalu lewat `waktuSekarang()` (dapat dikunci saat pengujian).
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/audit/audit_log.dart';
import '../../core/notifikasi/perencana_pengingat.dart' show batasIdKhusus;
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Lead pengingat bawaan dokumen (FR-129): 90, 30, 7, dan 1 hari sebelum
/// masa berlaku berakhir.
const String leadDokumenBawaan = '90,30,7,1';

/// Batas hari bagian "masa berlaku dekat" pada layar daftar (FR-128).
const int maksSorotanDokumenHari = 90;

/// Jumlah slot lead yang dilayani per dokumen (membatasi rentang ID).
///
/// Teks lead boleh memuat lebih dari angka ini. Lead diurutkan menurun
/// (lihat `teksKeLead`), lalu yang **dipakai** adalah angka terkecil — yaitu
/// lead paling dekat dengan tanggal berakhir. Lead terjauh yang dibuang, dan
/// itu wajar: pengingat jauh sudah lewat ketika dokumen mulai mendekati
/// tanggal berakhir.
const int maksLeadPerDokumen = 8;

/// Awal rentang ID notifikasi dokumen. Berada di atas [batasIdKhusus] supaya
/// tidak pernah bentrok dengan ID tagihan (yang selalu di bawah batas itu).
const int batasIdDokumen = batasIdKhusus + 1000;

/// Rentang maksimum satu dokumen (blok 8 ID). Dipakai untuk membersihkan
/// penundaan pengingat ketika dokumen dihapus.
const int blokIdPerDokumen = maksLeadPerDokumen;

/// ID notifikasi stabil untuk dokumen [dokumenId] slot ke-[slot].
///
/// Sifatnya: hasil sama untuk masukan sama (stabil antar sinkronisasi), unik
/// antar dokumen, dan selalu di atas [batasIdKhusus].
int idPengingatDokumen(int dokumenId, int slot) {
  final aman = dokumenId < 0 ? -dokumenId : dokumenId;
  final bagian = slot.clamp(0, blokIdPerDokumen - 1);
  return batasIdDokumen + (aman % 200000) * blokIdPerDokumen + bagian;
}

/// Seluruh ID pengingat milik satu dokumen (untuk cascade & pembatalan).
List<int> rentangIdPengingatDokumen(int dokumenId) => List<int>.generate(
      blokIdPerDokumen,
      (i) => idPengingatDokumen(dokumenId, i),
      growable: false,
    );

/// Nomor urut pembantu supaya dua dokumen yang disimpan pada milidetik yang
/// sama tetap punya `id_dokumen` berbeda.
int urutanIdDokumen = 0;

/// Bentuk `id_dokumen` baru: "DOK", tanda hubung, mikrodetik basis36, lalu
/// tiga angka urut — contoh "DOK-MFK2X1A-004".
///
/// Dipakai agar baris dapat dikenali di berkas cadangan walau ID basis data
/// berubah saat pemulihan.
String buatIdDokumen(DateTime kapan) {
  urutanIdDokumen = (urutanIdDokumen + 1) % 1000;
  final mikro = kapan.microsecondsSinceEpoch.toRadixString(36).toUpperCase();
  return 'DOK-$mikro-${urutanIdDokumen.toString().padLeft(3, '0')}';
}

/// Status masa berlaku sebuah dokumen (tanpa penilaian, hanya keadaan).
enum StatusMasaBerlaku {
  /// Tidak ada tanggal berakhir (dokumen berlaku tanpa batas yang dicatat).
  tanpaBatas,

  /// Tanggal berakhirnya sudah lewat.
  sudahLewat,

  /// Berakhir hari ini.
  hariIni,

  /// Berakhir dalam [maksSorotanDokumenHari] hari atau kurang.
  dekat,

  /// Berakhir lebih dari 90 hari lagi.
  jauh,
}

/// Label jenis dokumen yang dikenali skema `dokumen.jenis`.
const Map<String, String> labelJenisDokumen = <String, String>{
  'ktp': 'KTP',
  'kk': 'Kartu Keluarga',
  'paspor': 'Paspor',
  'sim': 'SIM',
  'stnk': 'STNK',
  'sertifikat': 'Sertifikat',
  'ijazah': 'Ijazah',
  'kontrak': 'Kontrak',
  'polis': 'Polis',
  'anak': 'Dokumen anak',
  'lain': 'Lainnya',
};

/// Kalimat catatan jujur soal berkas — dipakai layar daftar & form.
///
/// Ditulis di satu tempat supaya tidak ada layar yang mengklaim lebih dari
/// yang benar-benar dilakukan aplikasi.
const String catatanBerkasJujur =
    'Aplikasi hanya mencatat nama & tanggal dokumen. Berkas asli tetap di '
    'tempat Anda, tidak disalin dan belum dienkripsi.';

class DokumenRepository {
  DokumenRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? waktuSekarang;

  final AppDatabase db;

  /// Sumber waktu (dapat dikunci saat pengujian).
  final DateTime Function() _jam;

  // ------------------------------------------------------------------
  // Simpan / ubah
  // ------------------------------------------------------------------

  /// Tambah baris baru (`id == null`) atau ubah baris yang sudah ada.
  ///
  /// `lead_hari` dinormalkan menjadi teks urut menurun tanpa duplikat, jadi
  /// " 90, 30,30,7,1 " tersimpan sebagai "90,30,7,1".
  ///
  /// Satu-satunya kolom yang TIDAK pernah diubah di sini: `arsip` (diatur
  /// lewat [tandaiArsip]) dan `diperpanjang_pada` (lewat [tandaiDiperpanjang]).
  Future<DokumenData> simpan({
    int? id,
    required String nama,
    String jenis = 'lain',
    String? nomor,
    String? pemilik,
    DateTime? terbit,
    DateTime? berlakuSampai,
    String? berkasNama,
    String? catatan,
    String leadHari = leadDokumenBawaan,
    String kanalPengingat = 'push',
    bool aktif = true,
    String? idDokumen,
  }) async {
    final namaBersih = nama.trim();
    if (namaBersih.isEmpty) {
      throw ArgumentError('Nama dokumen tidak boleh kosong.');
    }
    final lead = teksKeLead(leadHari);
    if (lead.isEmpty) {
      throw ArgumentError(
          'Lead pengingat harus berisi angka hari, mis. "$leadDokumenBawaan".');
    }
    final leadBersih = leadKeTeks(lead);
    final jenisBersih = jenis.trim().isEmpty ? 'lain' : jenis.trim();
    final kanalBersih =
        kanalPengingat.trim().isEmpty ? 'push' : kanalPengingat.trim();
    final kini = _jam();

    if (id == null) {
      final baris = await db.into(db.dokumen).insertReturning(
            DokumenCompanion.insert(
              idDokumen: idDokumen ?? buatIdDokumen(kini),
              nama: namaBersih,
              jenis: Value(jenisBersih),
              nomor: Value(kosongJadiNull(nomor)),
              pemilik: Value(kosongJadiNull(pemilik)),
              terbit: Value(terbit),
              berlakuSampai: Value(berlakuSampai),
              berkasNama: Value(kosongJadiNull(berkasNama)),
              catatan: Value(kosongJadiNull(catatan)),
              leadHari: Value(leadBersih),
              kanalPengingat: Value(kanalBersih),
              aktif: Value(aktif),
              dibuatPada: Value(kini),
              diubahPada: Value(kini),
            ),
          );
      await _catat(
        aksi: AksiAudit.buat,
        ringkas: 'Dokumen "${baris.nama}" ditambahkan',
        entitasId: '${baris.id}',
        sesudah: baris.nama,
      );
      return baris;
    }

    final lama = await ambilSatu(id);
    if (lama == null) {
      throw StateError('Dokumen #$id tidak ditemukan.');
    }
    await (db.update(db.dokumen)..where((d) => d.id.equals(id)))
        .write(DokumenCompanion(
      nama: Value(namaBersih),
      jenis: Value(jenisBersih),
      nomor: Value(kosongJadiNull(nomor)),
      pemilik: Value(kosongJadiNull(pemilik)),
      terbit: Value(terbit),
      berlakuSampai: Value(berlakuSampai),
      berkasNama: Value(kosongJadiNull(berkasNama)),
      catatan: Value(kosongJadiNull(catatan)),
      leadHari: Value(leadBersih),
      kanalPengingat: Value(kanalBersih),
      aktif: Value(aktif),
      diubahPada: Value(kini),
    ));
    final baru = await ambilSatu(id);
    if (baru == null) {
      throw StateError('Dokumen #$id tidak ditemukan sesudah diubah.');
    }
    await _catat(
      aksi: AksiAudit.ubah,
      ringkas: 'Dokumen "${baru.nama}" diubah',
      entitasId: '${baru.id}',
      sebelum: lama.nama,
      sesudah: baru.nama,
    );
    return baru;
  }

  /// Tandai dokumen sudah diperpanjang (FR-128).
  ///
  /// [berlakuSampaiBaru] boleh kosong: kalau kosong, tanggal berakhir yang lama
  /// dipertahankan dan hanya jejak `diperpanjang_pada` yang diperbarui. Dokumen
  /// yang tadinya diarsipkan atau dinonaktifkan ikut diaktifkan lagi karena
  /// tindakan ini berarti dokumennya dipakai lagi.
  Future<DokumenData> tandaiDiperpanjang(
    int id, {
    DateTime? berlakuSampaiBaru,
    DateTime? kapan,
  }) async {
    final lama = await ambilSatu(id);
    if (lama == null) {
      throw StateError('Dokumen #$id tidak ditemukan.');
    }
    final waktuTanda = kapan ?? _jam();
    await (db.update(db.dokumen)..where((d) => d.id.equals(id)))
        .write(DokumenCompanion(
      diperpanjangPada: Value(waktuTanda),
      berlakuSampai:
          Value<DateTime?>(berlakuSampaiBaru ?? lama.berlakuSampai),
      arsip: const Value(false),
      aktif: const Value(true),
      diubahPada: Value(waktuTanda),
    ));
    final baru = await ambilSatu(id);
    if (baru == null) {
      throw StateError('Dokumen #$id tidak ditemukan sesudah ditandai.');
    }
    final akhir = baru.berlakuSampai;
    await _catat(
      aksi: AksiAudit.tandai,
      ringkas: 'Dokumen "${baru.nama}" ditandai sudah diperpanjang'
          '${akhir == null ? '' : ', berlaku sampai ${fmtTanggalAman(akhir)}'}',
      entitasId: '${baru.id}',
      sesudah: akhir?.toIso8601String(),
    );
    return baru;
  }

  /// Pindahkan dokumen ke arsip (`arsip = true`) atau kembalikan ke daftar.
  ///
  /// Dokumen yang diarsipkan tidak dibuatkan pengingat dan tidak muncul di
  /// daftar utama, tetapi barisnya tetap ada (tidak ada penghapusan diam-diam).
  Future<DokumenData> tandaiArsip(int id, {bool arsip = true}) async {
    final lama = await ambilSatu(id);
    if (lama == null) {
      throw StateError('Dokumen #$id tidak ditemukan.');
    }
    await (db.update(db.dokumen)..where((d) => d.id.equals(id)))
        .write(DokumenCompanion(
      arsip: Value(arsip),
      diubahPada: Value(_jam()),
    ));
    final baru = await ambilSatu(id);
    if (baru == null) {
      throw StateError('Dokumen #$id tidak ditemukan sesudah ditandai.');
    }
    await _catat(
      aksi: AksiAudit.tandai,
      ringkas: 'Dokumen "${baru.nama}" '
          '${arsip ? 'dipindahkan ke arsip' : 'dikembalikan ke daftar'}',
      entitasId: '${baru.id}',
    );
    return baru;
  }

  /// Nyalakan atau matikan pengingat dokumen tanpa mengubah isinya.
  Future<DokumenData> tandaiAktif(int id, {required bool aktif}) async {
    final lama = await ambilSatu(id);
    if (lama == null) {
      throw StateError('Dokumen #$id tidak ditemukan.');
    }
    await (db.update(db.dokumen)..where((d) => d.id.equals(id)))
        .write(DokumenCompanion(
      aktif: Value(aktif),
      diubahPada: Value(_jam()),
    ));
    final baru = await ambilSatu(id);
    if (baru == null) {
      throw StateError('Dokumen #$id tidak ditemukan sesudah ditandai.');
    }
    await _catat(
      aksi: AksiAudit.tandai,
      ringkas: 'Pengingat dokumen "${baru.nama}" '
          '${aktif ? 'diaktifkan' : 'dimatikan'}',
      entitasId: '${baru.id}',
    );
    return baru;
  }

  /// Hapus satu dokumen beserta penundaan pengingatnya (cascade di repositori).
  ///
  /// Mengembalikan jumlah baris penundaan pengingat yang ikut dibuang.
  Future<int> hapus(int id) async {
    final lama = await ambilSatu(id);
    if (lama == null) return 0;
    final idPengingat = rentangIdPengingatDokumen(id);
    final jumlahTunda = await (db.delete(db.tundaPengingat)
          ..where((t) => t.pengingatId.isBetweenValues(
                idPengingat.first,
                idPengingat.last,
              )))
        .go();
    await (db.delete(db.dokumen)..where((d) => d.id.equals(id))).go();
    await _catat(
      aksi: AksiAudit.hapus,
      ringkas: 'Dokumen "${lama.nama}" dihapus'
          '${jumlahTunda > 0 ? ' bersama $jumlahTunda penundaan pengingat' : ''}',
      entitasId: '$id',
      sebelum: lama.nama,
    );
    return jumlahTunda;
  }

  // ------------------------------------------------------------------
  // Baca
  // ------------------------------------------------------------------

  /// Semua dokumen, urut tanggal berakhir terdekat; dokumen tanpa tanggal
  /// berakhir diletakkan di bawah.
  ///
  /// [termasukArsip] palsu (bawaan) menyembunyikan dokumen yang diarsipkan.
  Future<List<DokumenData>> ambilSemua({bool termasukArsip = false}) {
    final kueri = db.select(db.dokumen);
    if (!termasukArsip) {
      kueri.where((d) => d.arsip.equals(false));
    }
    kueri.orderBy([
      (d) => OrderingTerm.asc(d.berlakuSampai.isNull()),
      (d) => OrderingTerm.asc(d.berlakuSampai),
      (d) => OrderingTerm.asc(d.nama),
    ]);
    return kueri.get();
  }

  /// Dokumen yang masih diingatkan: aktif dan tidak diarsipkan.
  Future<List<DokumenData>> ambilUntukPengingat() => (db.select(db.dokumen)
        ..where((d) => d.aktif.equals(true) & d.arsip.equals(false)))
        .get();

  Future<DokumenData?> ambilSatu(int id) =>
      (db.select(db.dokumen)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// Dokumen yang masa berlakunya tersisa paling banyak [maksHari] hari,
  /// termasuk yang tanggalnya sudah lewat. Urut yang paling dekat lebih dulu.
  Future<List<DokumenData>> segeraBerakhir({
    DateTime? sekarang,
    int maksHari = maksSorotanDokumenHari,
  }) async {
    final acuan = sekarang ?? _jam();
    final baris = await ambilUntukPengingat();
    final hasil = <({DokumenData d, int sisa})>[];
    for (final d in baris) {
      final sisa = sisaHari(d, acuan);
      if (sisa == null) continue;
      if (sisa <= maksHari) hasil.add((d: d, sisa: sisa));
    }
    hasil.sort((a, b) {
      final c = a.sisa.compareTo(b.sisa);
      return c != 0 ? c : a.d.nama.compareTo(b.d.nama);
    });
    return hasil.map((e) => e.d).toList(growable: false);
  }

  // ------------------------------------------------------------------
  // Hitungan murni (tanpa I/O) — dipakai layar, pengingat, dan pengujian
  // ------------------------------------------------------------------

  /// Sisa hari kalender menuju tanggal berakhir [d] dari [sekarang].
  ///
  /// `null` = dokumen tidak punya tanggal berakhir. Nilai negatif berarti
  /// tanggalnya sudah lewat.
  static int? sisaHari(DokumenData d, DateTime sekarang) {
    final akhir = d.berlakuSampai;
    if (akhir == null) return null;
    return selisihHari(sekarang, akhir);
  }

  /// Keadaan masa berlaku [d] pada saat [sekarang].
  static StatusMasaBerlaku status(
    DokumenData d,
    DateTime sekarang, {
    int batasDekat = maksSorotanDokumenHari,
  }) {
    final sisa = sisaHari(d, sekarang);
    if (sisa == null) return StatusMasaBerlaku.tanpaBatas;
    if (sisa < 0) return StatusMasaBerlaku.sudahLewat;
    if (sisa == 0) return StatusMasaBerlaku.hariIni;
    if (sisa <= batasDekat) return StatusMasaBerlaku.dekat;
    return StatusMasaBerlaku.jauh;
  }

  /// Tanggal & jam pengingat untuk lead [leadHariAwal] hari, pada jam [jam].
  ///
  /// Memakai penambahan hari lewat konstruktor `DateTime` supaya pergantian
  /// waktu musiman tidak menggeser tanggal.
  static DateTime waktuPengingat(
    DateTime berlakuSampai,
    int leadHariAwal, {
    int jam = 8,
  }) {
    final lead = leadHariAwal < 0 ? 0 : leadHariAwal;
    return DateTime(
      berlakuSampai.year,
      berlakuSampai.month,
      berlakuSampai.day - lead,
      jam,
    );
  }

  /// Lead hari yang tersimpan pada [d], urut menurun & tanpa duplikat.
  static List<int> leadDokumen(DokumenData d) => teksKeLead(d.leadHari);

  // ------------------------------------------------------------------
  // Ekspor (dipakai fitur cetak/salin; tidak mengubah data)
  // ------------------------------------------------------------------

  /// Daftar dokumen menjadi JSON siap simpan/cetak.
  ///
  /// Nilai uang tidak ada di sini; tanggal ditulis ISO-8601 supaya bisa dibaca
  /// program lain. Tidak ada satu pun isi berkas dokumen yang ikut diekspor.
  static String eksporJson(List<DokumenData> daftar) {
    final isi = <Map<String, Object?>>[
      for (final d in daftar)
        <String, Object?>{
          'idDokumen': d.idDokumen,
          'nama': d.nama,
          'jenis': d.jenis,
          'nomor': d.nomor,
          'pemilik': d.pemilik,
          'terbit': d.terbit?.toIso8601String(),
          'berlakuSampai': d.berlakuSampai?.toIso8601String(),
          'berkasNama': d.berkasNama,
          'leadHari': d.leadHari,
          'aktif': d.aktif,
          'arsip': d.arsip,
          'catatan': d.catatan,
        },
    ];
    return const JsonEncoder.withIndent('  ').convert({
      'jenis': 'daftar_dokumen',
      'jumlah': isi.length,
      'dokumen': isi,
    });
  }

  /// Daftar dokumen menjadi teks berbaris — enak dibaca & mudah dicetak.
  static String eksporTeks(List<DokumenData> daftar) {
    final papan = StringBuffer()
      ..writeln('Daftar dokumen (${daftar.length})')
      ..writeln('Catatan: $catatanBerkasJujur');
    for (final d in daftar) {
      final jenis = labelJenisDokumen[d.jenis] ?? d.jenis;
      final bagian = <String>['- ${d.nama} ($jenis)'];
      if (d.nomor != null && d.nomor!.isNotEmpty) bagian.add('nomor ${d.nomor}');
      if (d.pemilik != null && d.pemilik!.isNotEmpty) {
        bagian.add('milik ${d.pemilik}');
      }
      if (d.berlakuSampai != null) {
        bagian.add('berlaku sampai ${fmtTanggalAman(d.berlakuSampai!)}');
      }
      if (d.berkasNama != null && d.berkasNama!.isNotEmpty) {
        bagian.add('nama berkas ${d.berkasNama}');
      }
      if (d.arsip) bagian.add('di arsip');
      papan.writeln(bagian.join(' · '));
    }
    return papan.toString();
  }

  // ------------------------------------------------------------------

  Future<void> _catat({
    required String aksi,
    required String ringkas,
    String? entitasId,
    String? sebelum,
    String? sesudah,
  }) =>
      catatAuditAman(
        db,
        modul: ModulAudit.dokumen,
        aksi: aksi,
        entitas: 'dokumen',
        entitasId: entitasId,
        sebelum: sebelum,
        sesudah: sesudah,
        ringkas: ringkas,
      );
}

/// Teks kosong dianggap tidak diisi (kolom nullable diisi `null`, bukan "").
String? kosongJadiNull(String? teks) {
  final v = teks?.trim();
  if (v == null || v.isEmpty) return null;
  return v;
}
