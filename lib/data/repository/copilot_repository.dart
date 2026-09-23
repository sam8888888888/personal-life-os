/// FR-149 — repositori AI Copilot: konfigurasi, konteks dari data pengguna,
/// dan satu panggilan tanya-jawab.
///
/// Data yang dikirim TIDAK PERNAH melewati fungsi ini tanpa izin menyala
/// (diperiksa di `bolehTanyaCopilot`) — dan isi konteksnya dibangun dari
/// tabel pengguna sendiri, bukan dari sumber luar.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../core/analitik/copilot.dart';
import '../../core/platform/brankas_rahasia.dart';
import '../../data/repository/obat_repository.dart';
import '../database/database.dart';
import 'pengaturan_repository.dart';

/// Kunci baris konfigurasi di tabel `pengaturan`.
const String kunciCopilotEndpoint = 'copilot.endpoint';
const String kunciCopilotModel = 'copilot.model';
const String kunciCopilotKunci = 'copilot.kunci';
const String kunciCopilotIzin = 'copilot.izin';

class CopilotRepository {
  CopilotRepository(
    this.db, {
    DateTime Function()? jamSekarang,
    this.klien,
    this._batasWaktu = const Duration(seconds: 30),
  }) : _jam = jamSekarang ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _jam;
  final HttpClient? klien;
  final Duration _batasWaktu;

  PengaturanRepository get _pengaturan => PengaturanRepository(db);

  /// Penyimpan kunci API: brankas Keystore bila tersedia (audit P0-3 — kunci
  /// berbayar milik pengguna tidak boleh tersimpan polos di basis data).
  late final PenyimpanRahasia _rahasia = PenyimpanRahasia(_pengaturan);

  /// Apakah kunci API tersimpan TERENKRIPSI di perangkat ini.
  Future<bool> kunciTerlindungi() => _rahasia.tersedia();

  // ── Konfigurasi ───────────────────────────────────────────────────────────
  Future<KonfigCopilot> konfig() async {
    final endpoint =
        await _pengaturan.bacaTeks(kunciCopilotEndpoint, 'https://api.deepseek.com/chat/completions');
    final model = await _pengaturan.bacaTeks(kunciCopilotModel, 'deepseek-chat');
    final kunci = (await _rahasia.baca(kunciCopilotKunci)) ?? '';
    final izin = await _pengaturan.bacaSaklar(kunciCopilotIzin);
    return KonfigCopilot(
      endpoint: endpoint,
      model: model,
      kunci: kunci,
      izinDiberikan: izin,
    );
  }

  Future<void> simpanKonfig({
    String? endpoint,
    String? model,
    String? kunci,
    bool? izin,
  }) async {
    if (endpoint != null) {
      await _pengaturan.simpan(kunciCopilotEndpoint, endpoint.trim());
    }
    if (model != null) {
      await _pengaturan.simpan(kunciCopilotModel, model.trim());
    }
    if (kunci != null) {
      await _rahasia.simpan(kunciCopilotKunci, kunci.trim());
    }
    if (izin != null) {
      await _pengaturan.simpan(kunciCopilotIzin, izin ? '1' : '0');
    }
  }

  Future<void> hapusKunci() => _rahasia.hapus(kunciCopilotKunci);

  // ── Konteks dari data pengguna ────────────────────────────────────────────
  Future<BahanKonteksCopilot> bahanKonteks() async {
    final kini = _jam();

    // Tagihan terdekat yang belum lunas (maksimal 5).
    final tagihan = await (db.select(db.tagihan)
          ..where((t) => t.lunas.equals(false) & t.statusAktif.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.jatuhTempo)])
          ..limit(5))
        .get();
    final daftarTagihan = tagihan
        .map((t) => '${t.nama} '
            '${t.jumlahSen == null ? '(nominal belum diisi)' : rpKonteks(t.jumlahSen!)} '
            'jatuh tempo ${t.jatuhTempo.day}/${t.jatuhTempo.month}/${t.jatuhTempo.year}')
        .toList();

    // Dana persiapan aktif.
    final dana = await (db.select(db.danaPersiapan)
          ..where((t) => t.arsip.equals(false)))
        .get();
    final daftarDana = dana
        .map((d) => '${d.nama}: ${rpKonteks(d.tersediaSen)} dari target '
            '${d.targetSen <= 0 ? 'belum diisi' : rpKonteks(d.targetSen)}')
        .toList();

    // Jadwal obat/suplemen hari ini — memakai ulang modul obat FR-106
    // (`ObatRepository.jadwalRingkas`), bukan tabel obat kedua.
    final daftarObat = <String>[];
    for (final j in await ObatRepository(db).jadwalRingkas()) {
      daftarObat.add('${j.nama}'
          '${j.dosis.trim().isEmpty ? '' : ' (${j.dosis})'} jam ${j.jam}');
    }

    // Perjalanan terdekat.
    final perjalanan = await (db.select(db.perjalanan)
          ..where((t) => t.arsip.equals(false) & t.mulai.isBiggerOrEqualValue(
              DateTime(kini.year, kini.month, kini.day)))
          ..orderBy([(t) => OrderingTerm.asc(t.mulai)])
          ..limit(1))
        .get();
    final perjalananTeks = perjalanan.isEmpty
        ? null
        : '${perjalanan.first.nama} ke ${perjalanan.first.tujuan} '
            'mulai ${perjalanan.first.mulai.day}/${perjalanan.first.mulai.month}/'
            '${perjalanan.first.mulai.year} '
            '(anggaran ${rpKonteks(perjalanan.first.anggaranSen)})';

    return BahanKonteksCopilot(
      tagihanTerdekat: daftarTagihan,
      danaPersiapan: daftarDana,
      obatHariIni: daftarObat,
      perjalananTerdekat: perjalananTeks,
    );
  }

  Future<RingkasanCopilot> ringkasan({
    required bool adaJaringan,
    List<HasilCopilot> riwayat = const [],
  }) async {
    final k = await konfig();
    final bahan = await bahanKonteks();
    return ringkasCopilot(
      konfig: k,
      bahan: bahan,
      adaJaringan: adaJaringan,
      riwayat: riwayat,
    );
  }

  // ── Panggilan ke layanan AI ───────────────────────────────────────────────
  /// Kirim pertanyaan. Mengembalikan hasil BESERTA daftar data yang dikirim;
  /// kegagalan dijelaskan apa adanya (tidak dikarang jawabannya).
  Future<HasilCopilot> tanya({
    required String pertanyaan,
    required bool adaJaringan,
  }) async {
    final k = await konfig();
    final bahan = await bahanKonteks();
    final konteks = susunKonteksCopilot(bahan);

    final alasan = bolehTanyaCopilot(k, adaJaringan: adaJaringan);
    if (alasan.isNotEmpty) {
      return HasilCopilot(
        jawaban: '',
        dataDikirim: const [],
        waktu: _jam(),
        galat: alasan.join(' '),
      );
    }

    final permintaan = susunPermintaanCopilot(
      konfig: k,
      konteks: konteks,
      pertanyaan: pertanyaan.trim(),
    );

    final klienPakai = klien ?? HttpClient();
    klienPakai.connectionTimeout = _batasWaktu;
    try {
      final req = await klienPakai
          .postUrl(Uri.parse(permintaan.url))
          .timeout(_batasWaktu);
      permintaan.headers.forEach((nama, nilai) {
        req.headers.set(nama, nilai);
      });
      req.add(utf8.encode(permintaan.body));
      final res = await req.close().timeout(_batasWaktu);
      final badan = await res.transform(utf8.decoder).join();
      return HasilCopilot(
        jawaban: uraiJawabanCopilot(badan, statusKode: res.statusCode),
        dataDikirim: konteks.daftarData,
        waktu: _jam(),
        galat: res.statusCode >= 400
            ? 'Layanan AI menjawab HTTP ${res.statusCode}.'
            : null,
      );
    } catch (e) {
      return HasilCopilot(
        jawaban: '',
        dataDikirim: const [],
        waktu: _jam(),
        galat: 'Tidak bisa menghubungi layanan AI (${e.runtimeType}). '
            'Periksa jaringan/alamat layanan, lalu coba lagi.',
      );
    } finally {
      if (klien == null) klienPakai.close(force: true);
    }
  }
}
