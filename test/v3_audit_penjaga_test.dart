/// Uji penjaga hasil audit kode 23 Sep 2026.
///
/// Berkas ini menjaga kelas kesalahan yang TIDAK bisa ditangkap uji fitur
/// biasa — semuanya pernah lolos ke rilis:
///
/// 1. Kanal Android yang dipanggil Dart tetapi **tidak pernah dipasang** di
///    `MainActivity.kt` (dulu: brankas berkas medis → `MissingPluginException`
///    yang membuat fitur lampiran mati tanpa suara).
/// 2. Berkas konfigurasi Android yang kembali membuka pintu: cadangan awan,
///    izin SMS, atau koneksi tanpa enkripsi.
/// 3. Label versi yang berbohong (layar Tentang vs `pubspec.yaml`).
/// 4. Cadangan yang ditulis sebagai teks polos — padahal isinya seluruh
///    riwayat keuangan & kesehatan pengguna.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/backup/ekspor_impor.dart';
import 'package:personal_life_os/core/platform/brankas_rahasia.dart';
import 'package:personal_life_os/core/versi.dart' as versi;
import 'package:personal_life_os/data/database/database.dart';

/// Berkas uji ini sendiri menyebut nama izin/kata yang dilarang → jangan
/// ikut dipindai.
final String _berkasUjiIni = 'v3_audit_penjaga_test.dart';

/// Berkas yang boleh dibaca sebagai teks. Berkas biner (mis. `.bin` di dalam
/// `android/.gradle/`) dilewati — membacanya melempar galat penyandian.
const List<String> _akhiranTeks = <String>[
  '.dart', '.kt', '.java', '.xml', '.gradle', '.kts', '.pro', '.properties',
  '.yaml', '.yml', '.json', '.md', '.txt',
];

const List<String> _folderDilewati = <String>[
  '/build/', '/.gradle/', '/.dart_tool/', '/test/failures/',
];

/// Buang komentar (XML, blok, dan baris) supaya pemindaian hanya menilai KODE.
String _tanpaKomentar(String isi) {
  String t = isi.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  t = t.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  t = t
      .split('\n')
      .map((String l) {
        final int i = l.indexOf('//');
        return i >= 0 ? l.substring(0, i) : l;
      })
      .join('\n');
  return t;
}

Iterable<File> _berkasDi(String folder, String akhiran) {
  final Directory d = Directory(folder);
  if (!d.existsSync()) return const <File>[];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => akhiran.isEmpty
          ? _akhiranTeks.any((String a) => f.path.endsWith(a))
          : f.path.endsWith(akhiran))
      .where((File f) => !f.path.endsWith(_berkasUjiIni))
      .where((File f) => !_folderDilewati.any((String x) => f.path.contains(x)));
}

String _baca(String path) => File(path).readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kanal platform Android', () {
    test('setiap kanal lifeos/* yang dipanggil Dart ada di kode Android', () {
      final RegExp pola = RegExp(r"""['"]lifeos/([a-z_]+)['"]""");
      final Set<String> diDart = <String>{};
      for (final File f in _berkasDi('lib', '.dart')) {
        for (final RegExpMatch m in pola.allMatches(_baca(f.path))) {
          diDart.add(m.group(1)!);
        }
      }
      expect(diDart, isNotEmpty, reason: 'tidak ada kanal yang terbaca di lib/');

      final Set<String> diKotlin = <String>{};
      for (final File f in <File>[
        ..._berkasDi('android', '.kt'),
        ..._berkasDi('packages', '.kt'),
      ]) {
        for (final RegExpMatch m in pola.allMatches(_baca(f.path))) {
          diKotlin.add(m.group(1)!);
        }
      }

      final Set<String> tidakAda = diDart.difference(diKotlin);
      expect(
        tidakAda,
        isEmpty,
        reason: 'kanal ini dipanggil Dart tetapi tidak ada di kode Android '
            '(pemanggilnya akan gagal dengan MissingPluginException): $tidakAda',
      );
    });

    test('MainActivity memasang seluruh kanal (bukan cuma mendeklarasikan)', () {
      final String isi = _baca(
          'android/app/src/main/kotlin/com/personallifeos/personal_life_os/MainActivity.kt');
      // Setiap kanal yang punya kelas kanal di Android harus dipanggil
      // `.pasang(` atau `Kanal*.pasang(` di dalam configureFlutterEngine.
      final int jumlahPasang = RegExp(r'\.pasang\(').allMatches(isi).length;
      expect(
        jumlahPasang,
        greaterThanOrEqualTo(8),
        reason: 'jumlah pemasangan kanal menurun — ada kanal yang berhenti '
            'dipasang tanpa sengaja',
      );
      expect(isi.contains('kanalBerkasMedis.pasang('), isTrue,
          reason: 'brankas berkas medis (lampiran brankas medis) wajib dipasang');

      // Brankas rahasia TIDAK lagi dipasang di sini: kelasnya kini paket
      // plugin (packages/lifeos_brankas) supaya kanalnya juga ada di mesin
      // Flutter milik pekerja latar. Yang harus dijaga: plugin itu benar-benar
      // mendaftarkan kanalnya, bukan sekadar ada berkasnya.
      final String plugin = _baca(
          'packages/lifeos_brankas/android/src/main/kotlin/com/personallifeos/'
          'lifeos_brankas/BrankasRahasiaPlugin.kt');
      expect(plugin.contains('FlutterPlugin, MethodChannel.MethodCallHandler'), isTrue,
          reason: 'brankas Keystore wajib paket plugin (kanal harus ada di '
              'mesin pekerja latar, bukan hanya di MainActivity)');
      expect(plugin.contains('MethodChannel(binding.binaryMessenger'), isTrue,
          reason: 'kanal brankas wajib benar-benar dipasang (setMethodCallHandler)');
    });
  });

  group('konfigurasi rilis Android', () {
    test('manifest utama: cadangan awan mati, wajib TLS, izin jaringan ada', () {
      final String isi = _baca('android/app/src/main/AndroidManifest.xml');
      expect(isi.contains('android:allowBackup="false"'), isTrue,
          reason: 'tanpa allowBackup=false seluruh basis data terkirim ke '
              'Google Drive pengguna');
      expect(isi.contains('android:dataExtractionRules='), isTrue);
      expect(isi.contains('android:networkSecurityConfig='), isTrue);
      expect(isi.contains('android:usesCleartextTraffic="false"'), isTrue);
      expect(isi.contains('android.permission.INTERNET'), isTrue,
          reason: 'tanpa izin INTERNET di manifest UTAMA, sinkronisasi & AI '
              'Copilot mati di build rilis');
      expect(File('android/app/src/main/res/xml/data_extraction_rules.xml').existsSync(),
          isTrue);
      expect(File('android/app/src/main/res/xml/network_security_config.xml')
          .existsSync(), isTrue);
    });

    test('izin SMS sudah bersih dari seluruh kode (bukan hanya manifest)', () {
      // Komentar dibuang dulu: berkas aslinya MENJELASKAN izin yang dibuang
      // ("READ_SMS dihapus...") supaya pembaca tahu alasannya — itu bukan
      // pemakaian izin. Yang diuji: kode yang benar-benar memakainya.
      final RegExp pola = RegExp(r'READ_SMS|RECEIVE_SMS|SMS_RECEIVED');
      final List<String> temuan = <String>[];
      for (final String folder in <String>['lib', 'android']) {
        for (final File f in _berkasDi(folder, folder == 'lib' ? '.dart' : '')) {
          if (pola.hasMatch(_tanpaKomentar(_baca(f.path)))) temuan.add(f.path);
        }
      }
      expect(temuan, isEmpty,
          reason: 'izin SMS = pemicu Play Protect memblokir pemasangan: $temuan');
    });

    test('FileProvider tidak lagi membuka akar folder berkas', () {
      // Komentar XML dibuang dulu: penjelasan di dalamnya menyebut pola lama
      // `path="."` supaya pembaca tahu apa yang dihindari.
      final String isi = _baca('android/app/src/main/res/xml/berkas_paths.xml')
          .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
      expect(RegExp(r'path="\."').hasMatch(isi), isFalse,
          reason: 'path="." berarti seluruh folder dokumen/cache bisa di-URI-kan');
    });

    test('rilis tidak memakai debug keystore & tidak mematikan minify', () {
      final String isi = _baca('android/app/build.gradle.kts');
      // Kunci rilis dibaca dari android/key.properties; kunci debug hanya
      // dipakai sebagai jalur mundur yang DISEBUT di keluaran build.
      expect(isi.contains('key.properties'), isTrue,
          reason: 'kunci rilis harus dibaca dari android/key.properties');
      expect(isi.contains('signingConfigs.getByName("release")'), isTrue,
          reason: 'konfigurasi tanda tangan rilis wajib ada');
      expect(isi.contains('if (adaKunciRilis)'), isTrue,
          reason: 'pemilihan kunci rilis harus bersyarat & jelas, bukan asal pakai debug');
      expect(isi.contains('isMinifyEnabled = true'), isTrue);
      expect(isi.contains('isShrinkResources = true'), isTrue);
      expect(File('android/app/proguard-rules.pro').existsSync(), isTrue);
    });
  });

  group('versi aplikasi', () {
    test('pubspec.yaml sama dengan lib/core/versi.dart', () {
      final String pubspec = _baca('pubspec.yaml');
      final RegExpMatch? m =
          RegExp(r'^version:\s*(\S+)\+(\d+)\s*$', multiLine: true)
              .firstMatch(pubspec);
      expect(m, isNotNull, reason: 'baris version: tidak ditemukan di pubspec.yaml');
      expect(m!.group(1), versi.versiAplikasi,
          reason: 'versi di layar Tentang berbeda dengan pubspec');
      expect(int.parse(m.group(2)!), versi.nomorBuild,
          reason: 'nomor build di layar Tentang berbeda dengan pubspec');
    });
  });

  group('cadangan terenkripsi', () {
    /// Brankas tiruan: cukup untuk membuktikan jalur enkripsi Dart, tanpa
    /// kripto sungguhan (kriptonya ada di Android Keystore).
    late Map<String, String> brankas;
    late Map<String, String> sandiAmplop;

    setUp(() {
      brankas = <String, String>{};
      sandiAmplop = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(kanalBrankasRahasia),
        (MethodCall panggilan) async {
          final Map<Object?, Object?> a =
              (panggilan.arguments as Map<Object?, Object?>?) ?? <Object?, Object?>{};
          switch (panggilan.method) {
            case 'didukung':
              return true;
            case 'simpan':
              brankas[a['nama'] as String] = a['nilai'] as String;
              return true;
            case 'baca':
              return brankas[a['nama'] as String];
            case 'hapus':
              brankas.remove(a['nama'] as String);
              return true;
            case 'enkripsiSandi':
              final String amplop =
                  'AMPLOP-${base64.encode(utf8.encode(a['teks'] as String))}';
              sandiAmplop[amplop] = a['sandi'] as String;
              return amplop;
            case 'dekripsiSandi':
              final String amplop = a['amplop'] as String;
              if (sandiAmplop[amplop] != a['sandi']) return null;
              return utf8.decode(base64.decode(amplop.substring(7)));
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel(kanalBrankasRahasia), null);
    });

    test('tanpa frasa sandi → memakai kunci perangkat, isi tidak polos',
        () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final Directory folder = Directory.systemTemp.createTempSync('plo_uji_');
      addTearDown(() => folder.deleteSync(recursive: true));

      final LayananCadangan layanan = LayananCadangan(
        db: db,
        penentuFolder: () async => folder,
        jam: () => DateTime(2026, 9, 23, 10, 0),
      );

      final HasilEkspor hasil = await layanan.ekspor();
      expect(hasil.terenkripsi, isTrue,
          reason: 'kunci perangkat tersedia → cadangan wajib terenkripsi');

      final String isi = File(hasil.path).readAsStringSync();
      expect(isi.contains(formatCadanganTerenkripsi), isTrue);
      expect(isi.contains('"tabel"'), isFalse,
          reason: 'isi tabel tidak boleh terbaca sebagai teks polos');

      // Bisa dibuka lagi di perangkat yang sama (kuncinya ada di brankas).
      final PratinjauCadangan lihat = await layanan.pratinjau(hasil.path);
      expect(lihat.versiSkema, db.schemaVersion);

      // Frasa sandi yang salah → ditolak, bukan dianggap berhasil.
      await expectLater(
        () => layanan.pratinjau(hasil.path, sandi: 'sandi-salah'),
        throwsA(isA<GalatCadanganSandiSalah>()),
      );
    });

    test('frasa sandi pengguna dipakai untuk berkas yang pindah HP', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final Directory folder = Directory.systemTemp.createTempSync('plo_uji_');
      addTearDown(() => folder.deleteSync(recursive: true));

      final LayananCadangan layanan = LayananCadangan(
        db: db,
        penentuFolder: () async => folder,
        jam: () => DateTime(2026, 9, 23, 10, 0),
      );

      final HasilEkspor hasil = await layanan.ekspor(sandi: 'frasa-sandi-ku');
      expect(hasil.terenkripsi, isTrue);
      final PratinjauCadangan lihat =
          await layanan.pratinjau(hasil.path, sandi: 'frasa-sandi-ku');
      expect(lihat.versiSkema, db.schemaVersion);
    });

    test('tanpa brankas, cadangan dikatakan apa adanya (tidak diklaim aman)',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel(kanalBrankasRahasia), null);
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final Directory folder = Directory.systemTemp.createTempSync('plo_uji_');
      addTearDown(() => folder.deleteSync(recursive: true));

      final LayananCadangan layanan = LayananCadangan(
        db: db,
        penentuFolder: () async => folder,
        jam: () => DateTime(2026, 9, 23, 10, 0),
      );
      final HasilEkspor hasil = await layanan.ekspor();
      expect(hasil.terenkripsi, isFalse,
          reason: 'perangkat tanpa Keystore tidak boleh mengaku terenkripsi');
    });

    test('berkas rusak ditolak dengan pesan yang jelas', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final Directory folder = Directory.systemTemp.createTempSync('plo_uji_');
      addTearDown(() => folder.deleteSync(recursive: true));
      final File rusak = File('${folder.path}/plo_backup_rusak.json');
      rusak.writeAsStringSync('{"format":"bukan-backup"}');

      final LayananCadangan layanan = LayananCadangan(
        db: db,
        penentuFolder: () async => folder,
      );
      await expectLater(
        () => layanan.pratinjau(rusak.path),
        throwsA(isA<GalatCadangan>()),
      );
    });
  });
}
