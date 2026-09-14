/// Implementasi nyata layanan notifikasi (flutter_local_notifications, Android).
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'jejak.dart';
import 'layanan_notifikasi.dart';
import 'model_pengingat.dart';
import 'penangan_aksi_pengingat.dart';
import 'perencana_pengingat.dart';

class LayananNotifikasiLokal implements LayananNotifikasi {
  LayananNotifikasiLokal([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _siap = false;
  bool _alarmTepat = false;
  HasilPasang? _hasilPasang;

  @override
  HasilPasang? get hasilPasangTerakhir => _hasilPasang;

  @override
  bool get siap => _siap;

  static const _ikonAndroid = '@mipmap/ic_launcher';

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> siapkan() async {
    if (_siap) return;
    try {
      await lakukanInisialisasi();
      _siap = true; // hanya bila SELURUH inisialisasi berhasil
    } catch (e) {
      // PB-10: JANGAN menandai siap saat gagal — biar pemanggilan berikutnya
      // benar-benar mencoba lagi (sebelumnya satu kegagalan membuat instance ini
      // tidak pernah mencoba pulih). Aplikasi tetap tidak ikut gagal.
      _siap = false;
      debugPrint('LayananNotifikasiLokal.siapkan gagal: $e');
      await catatJejak({'jenis': 'siapkan_gagal', 'galat': '$e'});
    }
  }

  /// Inisialisasi nyata ke plugin Android. Dipisah supaya bisa diuji tanpa
  /// perangkat (uji mensubstitusi method ini untuk mensimulasikan kegagalan).
  @protected
  @visibleForTesting
  Future<void> lakukanInisialisasi() async {
    tzdata.initializeTimeZones();
    await _aturZonaWaktu();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_ikonAndroid),
      ),
      onDidReceiveNotificationResponse: _saatAksiDipilih,
      onDidReceiveBackgroundNotificationResponse: _saatAksiLatarDipilih,
    );
    await _buatKanal();
    _alarmTepat = (await _android?.canScheduleExactNotifications()) ?? false;
  }

  Future<void> _aturZonaWaktu() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }
  }

  Future<void> _buatKanal() async {
    for (final k in KanalNotifikasi.values) {
      await _android?.createNotificationChannel(AndroidNotificationChannel(
        k.id,
        k.nama,
        description: k.deskripsi,
        importance: k == KanalNotifikasi.terlambat
            ? Importance.max
            : k == KanalNotifikasi.tagihan
                ? Importance.high
                : Importance.defaultImportance,
      ));
    }
  }

  NotificationDetails _detail(Pengingat p) {
    final penting = p.terlambat;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        p.kanal.id,
        p.kanal.nama,
        channelDescription: p.kanal.deskripsi,
        importance: penting ? Importance.max : Importance.high,
        priority: penting ? Priority.max : Priority.high,
        category: AndroidNotificationCategory.reminder,
        styleInformation: BigTextStyleInformation(p.isi),
        ticker: p.judul,
        // FR-11: aksi dari notifikasi tanpa membuka aplikasi.
        // PB-16: notifikasi uji (tagihanId 0) tidak menawarkan "Sudah bayar",
        // supaya tidak ada aksi yang berakhir "tagihan tidak ditemukan".
        actions: p.tagihanId > 0
            ? const <AndroidNotificationAction>[
                AndroidNotificationAction(
                  'sudah_bayar',
                  '✓ Sudah bayar',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
                AndroidNotificationAction(
                  'tunda_1_jam',
                  'Tunda 1 jam',
                  showsUserInterface: false,
                ),
                AndroidNotificationAction(
                  'buka',
                  'Buka aplikasi',
                  showsUserInterface: true,
                ),
              ]
            : const <AndroidNotificationAction>[
                AndroidNotificationAction(
                  'tunda_1_jam',
                  'Tunda 1 jam',
                  showsUserInterface: false,
                ),
                AndroidNotificationAction(
                  'buka',
                  'Buka aplikasi',
                  showsUserInterface: true,
                ),
              ],
      ),
    );
  }

  AndroidScheduleMode get _mode => _alarmTepat
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  @override
  Future<void> pasangJadwal(List<Pengingat> daftar) async {
    await siapkan();
    // PB-04: jangan "batalkan semua" — batalkan hanya jadwal yang tidak ada di
    // rencana, dan pertahankan "Tunda 1 jam" milik tagihan yang masih ada.
    final tertunda = await _plugin.pendingNotificationRequests();
    final buang = idJadwalDibatalkan(
      tertunda: tertunda.map((n) => n.id),
      rencana: daftar.map((p) => p.id),
      tagihanRencana: daftar.map((p) => p.tagihanId),
    );
    for (final id in buang) {
      try {
        await _plugin.cancel(id: id);
      } catch (e) {
        debugPrint('gagal batalkan jadwal $id: $e');
      }
    }
    for (final p in daftar) {
      try {
        await _jadwalkan(p);
      } catch (e) {
        debugPrint('gagal jadwalkan ${p.id}: $e');
      }
    }

    // PB-09: verifikasi hasil nyata. Baca ulang apa yang benar-benar terpasang,
    // ulangi sekali untuk yang gagal, lalu simpan hasilnya supaya bisa dilihat
    // pengguna — kegagalan tidak lagi hanya jadi debugPrint yang tidak terlihat.
    var gagal = await _idBelumTerpasang(daftar);
    if (gagal.isNotEmpty) {
      for (final p in daftar.where((x) => gagal.contains(x.id))) {
        try {
          await _jadwalkan(p);
        } catch (_) {
          // sengaja: kegagalan kedua dicatat di jejak di bawah
        }
      }
      gagal = await _idBelumTerpasang(daftar);
    }

    _hasilPasang = HasilPasang(
      direncanakan: daftar.length,
      terpasang: daftar.length - gagal.length,
      idGagal: gagal,
      waktu: DateTime.now(),
    );
    if (gagal.isNotEmpty) {
      await catatJejak({
        'jenis': 'sinkron_tidak_lengkap',
        'galat': 'jadwal gagal terpasang: ${gagal.join(', ')}',
      });
    }
  }

  /// ID rencana yang belum muncul di daftar jadwal sistem.
  Future<List<int>> _idBelumTerpasang(List<Pengingat> daftar) async {
    try {
      final terpasang =
          (await _plugin.pendingNotificationRequests()).map((n) => n.id);
      return idJadwalGagalTerpasang(
        direncanakan: daftar.map((p) => p.id),
        terpasang: terpasang,
      );
    } catch (e) {
      debugPrint('verifikasi jadwal gagal: $e');
      return const [];
    }
  }

  Future<void> _jadwalkan(Pengingat p) => _plugin.zonedSchedule(
        id: p.id,
        title: p.judul,
        body: p.isi,
        scheduledDate: tz.TZDateTime.from(p.waktu, tz.local),
        notificationDetails: _detail(p),
        androidScheduleMode: _mode,
        payload: p.periode == null ? p.payload : p.payloadDenganPeriode(p.periode!),
      );

  @override
  Future<void> jadwalkanSatu(Pengingat p) async {
    await siapkan();
    await _jadwalkan(p);
  }

  @override
  Future<void> batalkanSemua() async {
    await _plugin.cancelAllPendingNotifications();
  }

  @override
  Future<void> tampilkanUji({Duration tunda = const Duration(seconds: 10)}) async {
    await siapkan();
    final p = Pengingat(
      id: idUjiNotifikasi,
      tagihanId: 0,
      waktu: DateTime.now().add(tunda),
      kanal: KanalNotifikasi.tagihan,
      judul: 'Notifikasi uji berhasil',
      isi: 'Kalau Anda melihat ini, pengingat Personal Life OS aktif di HP ini. '
          'Coba tombol "✓ Sudah bayar" untuk melatih aksinya.',
    );
    await _jadwalkan(p);
  }

  @override
  Future<List<({int id, String? judul, DateTime? waktu})>> tertunda() async {
    await siapkan();
    final daftar = await _plugin.pendingNotificationRequests();
    return daftar
        .map((p) => (id: p.id, judul: p.title, waktu: null))
        .toList(growable: false);
  }

  @override
  Future<StatusIzinPengingat> statusIzin() async {
    await siapkan();
    var notif = false;
    var alarm = false;
    try {
      notif = (await _android?.areNotificationsEnabled()) ?? false;
      alarm = (await _android?.canScheduleExactNotifications()) ?? false;
    } catch (e) {
      debugPrint('statusIzin gagal: $e');
    }
    _alarmTepat = alarm;
    return StatusIzinPengingat(
      notifikasiDiizinkan: notif,
      alarmTepatDiizinkan: alarm,
      catatan: [
        if (!Platform.isAndroid) 'Pengingat dirancang untuk Android.',
        if (!alarm)
          'Izin "alarm & pengingat" belum aktif: notifikasi tetap muncul, '
              'tetapi waktunya bisa bergeser beberapa menit.',
      ],
    );
  }

  @override
  Future<bool> mintaIzinNotifikasi() async =>
      (await _android?.requestNotificationsPermission()) ?? false;

  @override
  Future<bool> mintaIzinAlarmTepat() async {
    final hasil = (await _android?.requestExactAlarmsPermission()) ?? false;
    _alarmTepat = (await _android?.canScheduleExactNotifications()) ?? hasil;
    return _alarmTepat;
  }

  Future<void> _saatAksiDipilih(NotificationResponse r) async {
    // Isolate utama: aplikasi terlihat. Buka database aplikasi lewat handler.
    // PB-01: aksi diambil dari tombol yang benar-benar ditekan.
    final hasil = await tanganiAksiPengingat(
      r.payload,
      actionId: AksiNotifikasi.dariId(r.actionId),
      layanan: this,
    );
    await catatJejak({'jenis': 'aksi_ui', 'aksi': r.actionId, 'hasil': hasil.pesan});
  }

  @pragma('vm:entry-point')
  static void _saatAksiLatarDipilih(NotificationResponse r) {
    DartPluginRegistrant.ensureInitialized();
    unawaited(initializeDateFormatting('id_ID'));
    // Isolate latar: buka database sendiri.
    unawaited(tanganiAksiPengingat(
      r.payload,
      actionId: AksiNotifikasi.dariId(r.actionId),
      layanan: LayananNotifikasiLokal(),
    ));
  }
}

