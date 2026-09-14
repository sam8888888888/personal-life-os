/// Layar Pengingat: status izin, panduan per merek HP, uji notifikasi,
/// dan pratinjau jadwal pengingat berikutnya (FR-10 … FR-16).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifikasi/jejak.dart';
import '../../core/notifikasi/layanan_notifikasi.dart';
import '../../core/notifikasi/model_pengingat.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import 'layanan_panduan.dart';

class PengingatScreen extends ConsumerStatefulWidget {
  const PengingatScreen({super.key});

  @override
  ConsumerState<PengingatScreen> createState() => _PengingatScreenState();
}

class _PengingatScreenState extends ConsumerState<PengingatScreen> {
  Future<({String merek, String model, String android})>? _perangkat;
  StatusIzinPengingat? _izin;
  List<({int id, String? judul, DateTime? waktu})> _tertunda = const [];
  List<String> _jejak = const [];
  // PB-09/PB-10: hasil sinkronisasi terakhir & status penjadwal — ditampilkan
  // apa adanya supaya pengguna tahu kalau ada jadwal yang gagal terpasang.
  HasilPasang? _hasilPasang;
  bool _penjadwalSiap = false;

  @override
  void initState() {
    super.initState();
    _perangkat = infoPerangkat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muatStatus());
  }

  Future<void> _muatStatus() async {
    final l = ref.read(layananNotifikasiProvider);
    final izin = await l.statusIzin();
    final tertunda = await l.tertunda();
    final jejak = await bacaJejak(maks: 5);
    if (!mounted) return;
    setState(() {
      _izin = izin;
      _tertunda = tertunda;
      _hasilPasang = l.hasilPasangTerakhir;
      _penjadwalSiap = l.siap;
      _jejak = jejak
          .map((j) => [
                j['jenis']?.toString() ?? '-',
                j['hasil']?.toString() ?? j['galat']?.toString() ?? '',
                j['terjadwal']?.toString() ?? '',
              ].where((s) => s.isNotEmpty).join(' · '))
          .toList();
    });
  }

  Future<void> _pesan(String teks) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(teks)));
  }

  @override
  Widget build(BuildContext context) {
    final jadwal = ref.watch(pengingatBerikutnyaProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statusIzin(),
        const SizedBox(height: 12),
        _aksiCepat(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jadwal pengingat berikutnya',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  'Disusun ulang otomatis setiap aplikasi dibuka dan tiap 6 jam '
                  'lewat pekerja latar.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                jadwal.when(
                  data: (daftar) => daftar.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Belum ada pengingat. Tambahkan tagihan dulu, '
                              'lalu buka layar ini lagi.'),
                        )
                      : Column(
                          children: [
                            for (final p in daftar) _barisPengingat(p),
                          ],
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Gagal membaca jadwal: $e'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _panduan(),
        const SizedBox(height: 12),
        _diagnostik(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _statusIzin() {
    final izin = _izin;
    final siap = izin?.notifikasiDiizinkan ?? false;
    final alarm = izin?.alarmTepatDiizinkan ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(siap ? Icons.notifications_active : Icons.notifications_off,
                    color: siap ? Theme.of(context).colorScheme.primary : Colors.orange),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Status izin pengingat',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _barisCek('Izin notifikasi', siap),
            _barisCek('Izin alarm tepat (waktu presisi)', alarm),
            // PB-10: jujur kalau layanan pengingat belum berhasil disiapkan.
            _barisCek('Layanan pengingat siap', _penjadwalSiap),
            if (izin != null)
              for (final c in izin.catatan) ...[
                const SizedBox(height: 6),
                Text(c, style: Theme.of(context).textTheme.bodySmall),
              ],
          ],
        ),
      ),
    );
  }

  String _jam(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _barisCek(String label, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.error_outline,
                size: 18, color: ok ? Colors.green : Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(ok ? 'Aktif' : 'Belum', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  Widget _aksiCepat() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () async {
              final ok = await ref.read(layananNotifikasiProvider).mintaIzinNotifikasi();
              await _pesan(ok ? 'Izin notifikasi diberikan.' : 'Izin notifikasi belum diberikan.');
              await _muatStatus();
            },
            icon: const Icon(Icons.notifications),
            label: const Text('Minta izin notifikasi'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await ref.read(layananNotifikasiProvider).mintaIzinAlarmTepat();
              await _pesan(ok
                  ? 'Izin alarm tepat aktif: waktu notifikasi presisi.'
                  : 'Izin alarm tepat belum aktif. Notifikasi tetap jalan, waktu bisa bergeser.');
              await _muatStatus();
            },
            icon: const Icon(Icons.alarm),
            label: const Text('Izin alarm tepat'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(layananNotifikasiProvider)
                  .tampilkanUji(tunda: const Duration(seconds: 10));
              await _pesan('Notifikasi uji dijadwalkan 10 detik lagi. Kunci HP untuk mengujinya.');
            },
            icon: const Icon(Icons.science),
            label: const Text('Uji notifikasi (10 detik)'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final hasil = await ref.read(penyinkronPengingatProvider).sinkron();
              await _pesan('Jadwal disegarkan: ${hasil.jumlahTerjadwal} pengingat '
                  '(${hasil.jumlahTerlambat} terlambat).'
                  '${hasil.galat != null ? ' Gagal: ${hasil.galat}' : ''}');
              await _muatStatus();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Segarkan jadwal'),
          ),
        ],
      );

  Widget _barisPengingat(Pengingat p) {
    final warna = p.terlambat
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              p.kanal == KanalNotifikasi.ringkasan ? Icons.summarize : Icons.alarm,
              size: 16,
              color: warna,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.judul, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${fmtTanggalPendek(p.waktu)} · '
                  '${p.waktu.hour.toString().padLeft(2, '0')}:${p.waktu.minute.toString().padLeft(2, '0')}'
                  ' · ${p.kanal.nama}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panduan() => FutureBuilder(
        future: _perangkat,
        builder: (context, snap) {
          final info = snap.data;
          final panduan = panduanUntuk(info?.merek, info?.model);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agar pengingat tidak dimatikan sistem',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    'Panduan untuk: ${panduan.nama}'
                    '${info != null ? ' · ${info.merek} ${info.model} (${info.android})' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  for (final (i, l) in panduan.langkah.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 22, child: Text('${i + 1}.')),
                          Expanded(child: Text(l)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Catatan jujur: beberapa merek tetap membatasi aplikasi latar. '
                    'Karena itu jadwal pengingat juga disegarkan saat aplikasi dibuka.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _diagnostik() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Diagnostik',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text('Pengingat tertunda di sistem: ${_tertunda.length}'),
              Text('Aplikasi memantau ${_tertunda.length} jadwal Android.'),
              // PB-12: Android tidak memberi waktu pasti untuk jadwal tertunda —
              // jangan menampilkan waktu yang tidak benar-benar diketahui.
              if (_tertunda.any((t) => t.waktu == null))
                Text(
                  'Catatan: sistem Android tidak menyediakan waktu pasti untuk '
                  'jadwal tertunda; angka di atas adalah jumlah yang benar-benar terpasang.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              // PB-09: hasil sinkronisasi terakhir, termasuk kegagalan.
              if (_hasilPasang != null) ...[
                const SizedBox(height: 6),
                Text('Sinkron terakhir ${_jam(_hasilPasang!.waktu)} — '
                    '${_hasilPasang!.ringkas}'),
                if (!_hasilPasang!.lengkap)
                  Text(
                    'Jadwal yang gagal: ${_hasilPasang!.idGagal.join(', ')}. '
                    'Coba tekan "Segarkan jadwal" sekali lagi.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
              const SizedBox(height: 8),
              const Text('Jejak terakhir:', style: TextStyle(fontWeight: FontWeight.w600)),
              if (_jejak.isEmpty) const Text('- belum ada jejak -'),
              for (final j in _jejak)
                Text('• $j', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
