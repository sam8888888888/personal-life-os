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

  static const _ikonAndroid = '@mipmap/ic_launcher';

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> siapkan() async {
    if (_siap) return;
    try {
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
    } catch (e) {
      // Jangan gagalkan aplikasi: pengingat tidak aktif, fitur lain tetap jalan.
      debugPrint('LayananNotifikasiLokal.siapkan gagal: $e');
    }
    _siap = true;
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
        actions: const <AndroidNotificationAction>[
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
    await batalkanSemua();
    for (final p in daftar) {
      try {
        await _jadwalkan(p);
      } catch (e) {
        debugPrint('gagal jadwalkan ${p.id}: $e');
      }
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
    final hasil = await tanganiAksiPengingat(r.payload, layanan: this);
    await catatJejak({'jenis': 'aksi_ui', 'aksi': r.actionId, 'hasil': hasil.pesan});
  }

  @pragma('vm:entry-point')
  static void _saatAksiLatarDipilih(NotificationResponse r) {
    DartPluginRegistrant.ensureInitialized();
    unawaited(initializeDateFormatting('id_ID'));
    // Isolate latar: buka database sendiri.
    unawaited(tanganiAksiPengingat(r.payload, layanan: LayananNotifikasiLokal()));
  }
}

