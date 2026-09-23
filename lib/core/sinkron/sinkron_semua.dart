/// Mesin sinkron semua modul (FR-150) — Aaron, 22 Sep 2026.
///
/// Alur satu kali sinkron:
///   1. Pasang ulang kaitan yang tertunda (baris induk sudah turun).
///   2. Untuk tiap jalur: baca semua baris, isi `uid` bila belum ada, hitung
///      sidik isi baris, dan bandingkan dengan sidik tersimpan → kirim yang
///      berubah; baris yang hilang dikirim sebagai penanda hapus.
///   3. Kirim (dipotong per`batasPerKirim`) & terima perubahan yang belum
///      pernah dilihat HP ini (nomor revisi).
///   4. Terapkan perubahan: kaitan uid induk → id lokal; kalau induknya belum
///      ada, kaitan ditahan dulu (tidak dipasang ke induk yang salah).
///   5. Simpan sidik & kursor revisi.
///
/// Yang TIDAK dilakukan: menyentuh berkas repositori lama, mengubah tabel
/// pengaturan, atau memakai waktu sebagai penentu kemenangan di sisi HP
/// (waktu hanya dipakai server untuk memutuskan versi mana yang kalah).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../data/database/database.dart';
import '../platform/brankas_rahasia.dart';
import '../../data/repository/pengaturan_repository.dart';
import '../akun/klien_akun.dart';
import 'registri_sinkron.dart';
import 'sinkron_tagihan.dart' show HasilSinkron;

class SinkronSemua {
  SinkronSemua({
    required this.db,
    required this.klien,
    required this.pengaturan,
    List<JalurSinkron>? jalur,
  }) : jalur = jalur ?? daftarJalurSinkron(db);

  final AppDatabase db;
  final KlienAkun klien;
  final PengaturanRepository pengaturan;
  final List<JalurSinkron> jalur;

  static const String kunciRevisi = 'sinkron_revisi';
  static const String kunciTerakhir = 'sinkron_terakhir';

  static final Random _acak = Random.secure();

  JalurSinkron? _cari(String nama) {
    for (final j in jalur) {
      if (j.nama == nama) return j;
    }
    return null;
  }

  /// Jalur induk yang uid-nya dipakai anak.
  JalurSinkron? _cariInduk(String nama) => _cari(nama);

  Future<HasilSinkron> jalan({required String token, int batasPerKirim = 400}) async {
    final sejak = int.tryParse(await pengaturan.baca(kunciRevisi) ?? '') ?? 0;
    await _pulihkanTautan();

    final perubahan = <Map<String, dynamic>>[];
    final terkirim = <List<String>>[];
    var jumlahBerubah = 0;

    for (final j in jalur) {
      final baris = await _bacaSemua(j.nama);
      final lama = await _sidikTersimpan(j.nama);
      final baru = <String, String>{};

      for (final r in baris) {
        if (j.saring != null && !j.saring!(r)) continue;
        final uid = await _pastikanUid(
            j.nama, j.kolomUid.$name, j.kolomKunci?.$name, r);
        final peta = await _untukServer(j, r);
        final sidik = _sidikPeta(peta);
        baru[uid] = sidik;
        if (lama[uid] == sidik) continue;
        perubahan.add(<String, dynamic>{
          'tabel': j.nama,
          'id_lokal': uid,
          'waktu_klien': _waktuKirim(j, r),
          'dihapus': false,
          'isi': peta,
        });
        terkirim.add(<String>[j.nama, uid]);
        jumlahBerubah++;
      }

      // Baris yang hilang di HP ini = dihapus di sini → kirim penanda hapus.
      for (final e in lama.entries) {
        if (baru.containsKey(e.key)) continue;
        perubahan.add(<String, dynamic>{
          'tabel': j.nama,
          'id_lokal': e.key,
          'waktu_klien': DateTime.now().toUtc().toIso8601String(),
          'dihapus': true,
          'isi': const <String, dynamic>{},
        });
        terkirim.add(<String>[j.nama, e.key]);
        jumlahBerubah++;
      }
    }

    // Kirim berkelompok supaya satu permintaan tidak terlalu besar.
    var diterima = 0;
    var konflik = 0;
    var revisi = sejak;
    final tarikan = <Map<String, dynamic>>[];
    final kiriman = <List<List<String>>>[];
    for (var i = 0; i < terkirim.length; i += batasPerKirim) {
      kiriman.add(terkirim.sublist(i, min(i + batasPerKirim, terkirim.length)));
    }
    if (kiriman.isEmpty) kiriman.add(<List<String>>[]);

    for (var g = 0; g < kiriman.length; g++) {
      final kelompok = kiriman[g];
      final kelompokSet = kelompok.map((e) => '${e[0]}|${e[1]}').toSet();
      final paket = perubahan
          .where((p) => kelompokSet.contains('${p['tabel']}|${p['id_lokal']}'))
          .toList();
      final jawab = await klien.sinkron(
        token: token,
        sejak: revisi,
        perubahan: paket,
      );
      diterima += (jawab['diterima'] as num?)?.toInt() ?? 0;
      konflik += (jawab['konflik'] as num?)?.toInt() ?? 0;
      revisi = (jawab['revisi'] as num?)?.toInt() ?? revisi;
      final isi = (jawab['perubahan'] as List?) ?? const [];
      for (final butir in isi) {
        tarikan.add((butir as Map).cast<String, dynamic>());
      }
      // Sidik hanya ditulis setelah server menerima kiriman ini.
      for (final e in kelompok) {
        final isiPaket = paket.firstWhere(
          (p) => p['tabel'] == e[0] && p['id_lokal'] == e[1],
          orElse: () => const <String, dynamic>{},
        );
        if (isiPaket.isEmpty) continue;
        if (isiPaket['dihapus'] == true) {
          await _hapusSidik(e[0], e[1]);
        } else {
          await _simpanSidik(e[0], e[1], _sidikPeta(isiPaket['isi']));
        }
      }
    }

    // Terapkan tarikan.
    var diterapkan = 0;
    final sudah = <String>{};
    for (final butir in tarikan) {
      final nama = _teks(butir['tabel']);
      final uid = _teks(butir['id_lokal']);
      if (nama == null || uid == null) continue;
      final j = _cari(nama);
      if (j == null) continue;
      if (!sudah.add('$nama|$uid')) continue;
      final isiMasuk = (butir['isi'] as Map?)?.cast<String, Object?>() ?? const {};
      if (j.saring != null && !j.saring!(isiMasuk)) continue;
      await _terapkan(j, uid, butir);
      diterapkan++;
    }

    await pengaturan.simpan(kunciRevisi, '$revisi');
    await pengaturan.simpan(kunciTerakhir, DateTime.now().toIso8601String());

    final pesan = jumlahBerubah == 0 && diterapkan == 0
        ? 'Sudah sama di semua HP.'
        : 'Dikirim $jumlahBerubah · diterima server $diterima · dipasang '
            'di HP ini $diterapkan'
            '${konflik > 0 ? ' · $konflik bentrok (versi lama disimpan di server)' : ''}';
    return HasilSinkron(
      dikirim: jumlahBerubah,
      diterapkan: diterapkan,
      konflik: konflik,
      pesan: pesan,
    );
  }

  /// Pastikan baris punya uid (dipakai jalur server maupun jalur berkas).
  Future<String> _pastikanUid(String nama, String kolomUid, String? kolomKunci,
      Map<String, Object?> baris) async {
    var uid = _teks(baris[kolomUid]);
    if (uid != null && uid.isNotEmpty) return uid;
    uid = _uidBaru();
    final kunci = kolomKunci ?? 'id';
    await db.customStatement(
        'UPDATE $nama SET $kolomUid = ? WHERE $kunci = ?', [uid, baris[kunci]]);
    baris[kolomUid] = uid;
    return uid;
  }

  /// Seluruh baris lokal dalam bentuk yang bisa dikirim ke server ATAU ditulis
  /// ke berkas (FR-27). Bentuknya sama supaya penerapannya satu kode saja.
  Future<List<Map<String, dynamic>>> semuaButirLokal() async {
    final keluar = <Map<String, dynamic>>[];
    for (final j in jalur) {
      for (final r in await _bacaSemua(j.nama)) {
        if (j.saring != null && !j.saring!(r)) continue;
        final uid = await _pastikanUid(
            j.nama, j.kolomUid.$name, j.kolomKunci?.$name, r);
        keluar.add(<String, dynamic>{
          'tabel': j.nama,
          'id_lokal': uid,
          'dihapus': false,
          'waktu_klien': _waktuKirim(j, r),
          'isi': await _untukServer(j, r),
        });
      }
    }
    return keluar;
  }

  /// Berkas lintas-perangkat memakai passphrase; jangan menaruh data sensitif
  /// dalam JSON polos yang dibagikan lewat Drive/WhatsApp/USB.
  static const String formatBerkasSinkronTerenkripsi = 'plo-sync-terenkripsi';
  static const int panjangSandiBerkasMinimum = 8;

  /// Kenali format terenkripsi saat ini atau format polos lama (versi 1).
  static Future<bool> berkasSinkronTerenkripsi(File berkas) async {
    final data = jsonDecode(await berkas.readAsString());
    if (data is Map && data['format'] == formatBerkasSinkronTerenkripsi) {
      return true;
    }
    if (data is Map && data['versi'] == 1 && data['butir'] is List) {
      return false;
    }
    throw const FormatException('Berkas sinkron tidak dikenali.');
  }

  /// FR-27 — ekspor data dalam amplop AES-GCM dengan passphrase pengguna.
  Future<int> eksporBerkas(File berkas, {required String sandi}) async {
    if (sandi.length < panjangSandiBerkasMinimum) {
      throw ArgumentError('Frasa sandi minimal 8 karakter.');
    }
    final butir = await semuaButirLokal();
    final isi = jsonEncode(<String, dynamic>{
      'versi': 1,
      'dibuat': DateTime.now().toUtc().toIso8601String(),
      'butir': butir,
    });
    final amplop = await enkripsiDenganSandi(teks: isi, sandi: sandi);
    if (amplop == null) {
      throw StateError('Perangkat gagal mengenkripsi berkas sinkron.');
    }
    await berkas.writeAsString(
      jsonEncode(<String, dynamic>{
        'format': formatBerkasSinkronTerenkripsi,
        'versi': 1,
        'amplop': amplop,
      }),
      flush: true,
    );
    return butir.length;
  }

  /// Impor atomik: semua baris diterapkan atau seluruh perubahan dibatalkan.
  /// Berkas versi lama polos hanya diterima bila pemanggil sudah memberi
  /// peringatan dan memperoleh persetujuan pengguna.
  Future<int> imporBerkas(
    File berkas, {
    String? sandi,
    bool izinkanBerkasLamaPolos = false,
  }) async {
    final dibaca = jsonDecode(await berkas.readAsString());
    if (dibaca is! Map) {
      throw const FormatException('Berkas sinkron tidak dikenali.');
    }

    Map<String, dynamic> data;
    if (dibaca['format'] == formatBerkasSinkronTerenkripsi) {
      if (sandi == null || sandi.isEmpty) {
        throw const FormatException('Masukkan frasa sandi berkas sinkron.');
      }
      final teks = await dekripsiDenganSandi(
        amplop: _teks(dibaca['amplop']) ?? '',
        sandi: sandi,
      );
      if (teks == null) {
        throw const FormatException('Sandi salah atau berkas rusak.');
      }
      final isi = jsonDecode(teks);
      if (isi is! Map || isi['butir'] is! List) {
        throw const FormatException('Isi berkas sinkron tidak dikenali.');
      }
      data = isi.cast<String, dynamic>();
    } else if (dibaca['versi'] == 1 && dibaca['butir'] is List) {
      if (!izinkanBerkasLamaPolos) {
        throw const FormatException(
          'Berkas lama tidak terenkripsi; persetujuan eksplisit diperlukan.',
        );
      }
      data = dibaca.cast<String, dynamic>();
    } else {
      throw const FormatException('Berkas sinkron tidak dikenali.');
    }

    final butirMasuk = data['butir'];
    if (butirMasuk is! List) {
      throw const FormatException('Daftar isi berkas sinkron tidak sah.');
    }
    return db.transaction(() async {
      var masuk = 0;
      for (final b in butirMasuk) {
        if (b is! Map) {
          throw const FormatException('Baris berkas sinkron tidak sah.');
        }
        final butir = b.cast<String, dynamic>();
        final nama = _teks(butir['tabel']);
        final uid = _teks(butir['id_lokal']);
        if (nama == null || uid == null) continue;
        final j = _cari(nama);
        if (j == null) continue;
        final isiMasuk =
            (butir['isi'] as Map?)?.cast<String, Object?>() ?? const {};
        if (j.saring != null && !j.saring!(isiMasuk)) continue;
        butir['dihapus'] = butir['dihapus'] == true;
        await _terapkan(j, uid, butir);
        masuk++;
      }
      await _pulihkanTautan();
      return masuk;
    });
  }

  // ── baca & sidik ──────────────────────────────────────────────────────────
  Future<List<Map<String, Object?>>> _bacaSemua(String nama) async {
    final hasil = await db.customSelect('SELECT * FROM $nama').get();
    return hasil.map((b) => Map<String, Object?>.from(b.data)).toList();
  }

  Future<Map<String, String>> _sidikTersimpan(String nama) async {
    final hasil = await (db.select(db.sinkronSidik)
          ..where((t) => t.tabel.equals(nama)))
        .get();
    return <String, String>{for (final b in hasil) b.uid: b.sidik};
  }

  Future<void> _simpanSidik(String nama, String uid, String sidik) =>
      db.into(db.sinkronSidik).insertOnConflictUpdate(
            SinkronSidikCompanion.insert(
              tabel: nama,
              uid: uid,
              sidik: sidik,
              waktu: Value(DateTime.now()),
            ),
          );

  Future<void> _hapusSidik(String nama, String uid) => (db.delete(db.sinkronSidik)
        ..where((t) => t.tabel.equals(nama) & t.uid.equals(uid)))
      .go();

  /// Sidik isi pakai FNV-1a 64 bit — cukup untuk mendeteksi perubahan isi dan
  /// tidak butuh pustaka tambahan.
  static String _sidikPeta(Map<String, Object?> peta) {
    final kunci = peta.keys.toList()..sort();
    final buf = StringBuffer();
    for (final k in kunci) {
      buf.write(k);
      buf.write('=');
      buf.write(peta[k]?.toString() ?? '~');
      buf.write(';');
    }
    var h = 0xcbf29ce484222325;
    for (final b in utf8.encode(buf.toString())) {
      h ^= b;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(16, '0');
  }

  /// Isi yang dikirim ke server: kunci angka dibuang, kaitan dikirim sebagai uid
  /// induk (bukan id lokal).
  Future<Map<String, Object?>> _untukServer(
      JalurSinkron j, Map<String, Object?> baris) async {
    final peta = <String, Object?>{};
    final kunci = j.kolomKunci?.$name;
    for (final e in baris.entries) {
      if (kunci != null && e.key == kunci) continue;
      final induk = j.kaitan[e.key];
      if (induk != null) {
        final idLokal = e.value;
        if (idLokal == null) {
          peta[e.key] = null;
          continue;
        }
        peta[e.key] = await _uidDariId(induk, idLokal);
        continue;
      }
      peta[e.key] = e.value;
    }
    return peta;
  }

  String _waktuKirim(JalurSinkron j, Map<String, Object?> baris) {
    final nama = j.kolomDiubah?.$name;
    final v = nama == null ? null : baris[nama];
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true)
          .toIso8601String();
    }
    if (v is String) {
      final t = DateTime.tryParse(v);
      if (t != null) return t.toUtc().toIso8601String();
    }
    return DateTime.now().toUtc().toIso8601String();
  }

  // ── terapkan perubahan dari server ────────────────────────────────────────
  Future<void> _terapkan(
      JalurSinkron j, String uid, Map<String, dynamic> butir) async {
    if (butir['dihapus'] == true) {
      await db.customStatement('DELETE FROM ${j.nama} WHERE ${j.kolomUid.$name} = ?', [uid]);
      await _hapusSidik(j.nama, uid);
      return;
    }
    final isi = (butir['isi'] as Map?)?.cast<String, Object?>() ?? const {};
    final kolom = <String>[];
    final nilai = <Object?>[];
    for (final e in isi.entries) {
      if (e.key == 'uid') continue;
      if (e.key == j.kolomKunci?.$name) continue;
      final induk = j.kaitan[e.key];
      if (induk != null && e.value != null) {
        final idLokal = await _idDariUid(induk, '${e.value}');
        if (idLokal == null) {
          // Induk belum ada di HP ini → tahan kaitannya, jangan pasang salah.
          await _catatTautanBelum(j.nama, uid, e.key, '${e.value}');
          continue;
        }
        kolom.add(e.key);
        nilai.add(idLokal);
        continue;
      }
      kolom.add(e.key);
      nilai.add(e.value);
    }

    final ada = await db
        .customSelect('SELECT 1 AS ada FROM ${j.nama} WHERE ${j.kolomUid.$name} = ? LIMIT 1',
            variables: [Variable<String>(uid)])
        .getSingleOrNull();
    if (ada != null) {
      final set = kolom.map((k) => '$k = ?').join(', ');
      await db.customStatement(
          'UPDATE ${j.nama} SET $set WHERE ${j.kolomUid.$name} = ?',
          [...nilai, uid]);
    } else {
      final semuaKolom = [...kolom, j.kolomUid.$name];
      final tanda = List.filled(semuaKolom.length, '?').join(', ');
      await db.customStatement(
          'INSERT INTO ${j.nama} (${semuaKolom.join(', ')}) VALUES ($tanda)',
          [...nilai, uid]);
    }

    // Sidik dari keadaan lokal sesudah ditulis, supaya baris ini tidak
    // dikirim balik ke server (tidak ada pantulan).
    final baris = await _bacaSatu(j, uid);
    if (baris != null) {
      final peta = await _untukServer(j, baris);
      await _simpanSidik(j.nama, uid, _sidikPeta(peta));
    }
  }

  Future<Map<String, Object?>?> _bacaSatu(JalurSinkron j, String uid) async {
    final hasil = await db
        .customSelect('SELECT * FROM ${j.nama} WHERE ${j.kolomUid.$name} = ? LIMIT 1',
            variables: [Variable<String>(uid)])
        .getSingleOrNull();
    return hasil == null ? null : Map<String, Object?>.from(hasil.data);
  }

  // ── kaitan ────────────────────────────────────────────────────────────────
  Future<String?> _uidDariId(String namaInduk, Object? idLokal) async {
    final j = _cariInduk(namaInduk);
    if (j == null) return null;
    final kunci = j.kolomKunci?.$name ?? 'id';
    final hasil = await db
        .customSelect(
            'SELECT ${j.kolomUid.$name} AS uid FROM ${j.nama} WHERE $kunci = ? LIMIT 1',
            variables: [Variable<int>(int.tryParse('$idLokal') ?? -1)])
        .getSingleOrNull();
    return hasil?.read<String?>('uid');
  }

  Future<int?> _idDariUid(String namaInduk, String uid) async {
    final j = _cariInduk(namaInduk);
    if (j == null) return null;
    final kunci = j.kolomKunci?.$name ?? 'id';
    final hasil = await db
        .customSelect('SELECT $kunci AS kunci FROM ${j.nama} WHERE ${j.kolomUid.$name} = ? LIMIT 1',
            variables: [Variable<String>(uid)])
        .getSingleOrNull();
    return hasil?.read<int?>('kunci');
  }

  Future<void> _catatTautanBelum(
          String nama, String uid, String kolom, String uidInduk) =>
      db.into(db.sinkronTautanBelum).insertOnConflictUpdate(
            SinkronTautanBelumCompanion.insert(
              tabel: nama,
              uid: uid,
              kolom: kolom,
              uidInduk: uidInduk,
            ),
          );

  /// Coba pasang kaitan yang tertunda (dipanggil di awal tiap sinkron).
  Future<void> _pulihkanTautan() async {
    final tertunda = await db.select(db.sinkronTautanBelum).get();
    for (final t in tertunda) {
      final j = _cari(t.tabel);
      if (j == null) continue;
      final idLokal = await _idDariUid(j.kaitan[t.kolom] ?? '', t.uidInduk);
      if (idLokal == null) continue;
      await db.customStatement(
          'UPDATE ${j.nama} SET ${t.kolom} = ? WHERE ${j.kolomUid.$name} = ?',
          [idLokal, t.uid]);
      await (db.delete(db.sinkronTautanBelum)
            ..where((x) =>
                x.tabel.equals(t.tabel) & x.uid.equals(t.uid) & x.kolom.equals(t.kolom)))
          .go();
    }
  }

  static String? _teks(Object? v) =>
      v is String ? v : (v == null ? null : '$v');

  static String _uidBaru() {
    final b = List<int>.generate(16, (_) => _acak.nextInt(256));
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  }
}
