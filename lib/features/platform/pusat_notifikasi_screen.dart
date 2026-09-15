/// FR-147 & FR-148 — Pusat Notifikasi.
///
/// Isi layar:
/// * riwayat notifikasi terkelompok **Hari ini / Kemarin / Lebih lama**;
/// * tanda belum dibaca, dengan aksi "Tandai dibaca", "Tandai selesai", dan
///   "Tunda";
/// * jumlah belum dibaca & jumlah per tingkat, dihitung dari data (bukti angka).
///
/// Kejujuran data (PRD §III-11): riwayat ini **tersimpan di perangkat Anda
/// saja, tidak dikirim ke mana pun**. Penundaan hanya menggeser waktu pengingat
/// — tanggal jatuh tempo asli di modul asalnya tidak disentuh. Notifikasi tetap
/// dibatasi per siklus agar tidak mengganggu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/notifikasi/tunda_pengingat.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/notifikasi_riwayat_repository.dart';

/// Repositori riwayat notifikasi untuk layar ini.
final notifikasiRiwayatRepoProvider = Provider<NotifikasiRiwayatRepository>(
    (ref) => NotifikasiRiwayatRepository(ref.watch(databaseProvider)));

/// Repositori penundaan pengingat (FR-148) untuk layar ini.
final tundaPengingatRepoProvider = Provider<TundaPengingatRepository>(
    (ref) => TundaPengingatRepository(ref.watch(databaseProvider)));

/// Catatan lokal riwayat notifikasi — satu sumber untuk layar & uji.
const String catatanLokalNotifikasi =
    'Riwayat ini tersimpan di perangkat Anda saja, tidak dikirim ke mana pun.';

/// Catatan anti-bising: jumlah notifikasi per siklus tetap dibatasi.
const String catatanBatasNotifikasi =
    'Jumlah notifikasi per siklus tetap dibatasi agar tidak mengganggu.';

/// Catatan bahwa penundaan tidak mengubah tanggal asli.
const String catatanTundaTidakMengubahJatuhTempo =
    'Jatuh tempo asli tidak berubah — hanya waktu pengingat yang bergeser.';

/// Data satu kali pemuatan layar Pusat Notifikasi.
class DataNotifikasi {
  const DataNotifikasi({
    required this.kelompok,
    required this.belumDibaca,
    required this.jumlahMendesak,
    required this.jumlahPenting,
    required this.jumlahTundaPerPengingat,
  });

  final KelompokNotifikasi kelompok;

  /// Jumlah baris berstatus "baru".
  final int belumDibaca;

  final int jumlahMendesak;
  final int jumlahPenting;

  /// jumlah tunda per pengingat (pengingatId → jumlah tunda).
  final Map<int, int> jumlahTundaPerPengingat;

  bool get kosong => kelompok.kosong;

  /// Jumlah tunda yang sudah tercatat untuk satu pengingat.
  int tundaUntuk(int? pengingatId) =>
      pengingatId == null ? 0 : (jumlahTundaPerPengingat[pengingatId] ?? 0);
}

class PusatNotifikasiScreen extends ConsumerStatefulWidget {
  const PusatNotifikasiScreen({super.key, this.jamSekarang});

  /// Sumber waktu yang bisa disuntik uji.
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<PusatNotifikasiScreen> createState() =>
      _PusatNotifikasiScreenState();
}

class _PusatNotifikasiScreenState extends ConsumerState<PusatNotifikasiScreen> {
  bool _hanyaBelumDibaca = false;
  late Future<DataNotifikasi> _masaDepan;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _masaDepan = _muat();
  }

  Future<DataNotifikasi> _muat() async {
    final repo = ref.read(notifikasiRiwayatRepoProvider);
    final baris = await repo.daftar(
      hanyaBelumDibaca: _hanyaBelumDibaca,
      batas: batasTampilNotifikasi,
    );
    final belumDibaca = await repo.jumlahBelumDibaca();
    final perTingkat = await repo.hitungPerTingkat();
    final tunda = await ref.read(tundaPengingatRepoProvider).daftar();
    return DataNotifikasi(
      kelompok: kelompokkanNotifikasi(baris, _sekarang),
      belumDibaca: belumDibaca,
      jumlahMendesak: perTingkat[TingkatNotifikasi.mendesak] ?? 0,
      jumlahPenting: perTingkat[TingkatNotifikasi.penting] ?? 0,
      jumlahTundaPerPengingat: {
        for (final t in tunda) t.pengingatId: t.jumlahTunda,
      },
    );
  }

  void _muatUlang() => setState(() {
    _masaDepan = _muat();
  });

  Future<void> _pesan(String teks) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _ubahStatus(int id, {required bool selesai}) async {
    try {
      final repo = ref.read(notifikasiRiwayatRepoProvider);
      if (selesai) {
        await repo.tandaiSelesai(id, pada: _sekarang);
      } else {
        await repo.tandaiDibaca(id);
      }
      await _pesan(selesai
          ? 'Baris ini ditandai selesai.'
          : 'Baris ini ditandai sudah dibaca.');
    } catch (e) {
      await _pesan('Penandaan tidak bisa disimpan sekarang. Penyebab: $e');
    }
    if (mounted) _muatUlang();
  }

  /// Tunda pengingat (FR-148). Hanya untuk baris yang bertaut jadwal pengingat.
  Future<void> _tunda(NotifikasiRiwayatData b, DataNotifikasi data) async {
    final pengingatId = b.pengingatId;
    if (pengingatId == null) {
      await _pesan('Baris ini tidak bertaut jadwal pengingat, jadi pilihan '
          'tunda tidak tersedia.');
      return;
    }
    final jumlah = data.tundaUntuk(pengingatId);
    if (!bolehDitundaLagi(jumlah)) {
      await _pesan(BatasTundaTerlampaui(jumlah).pesan);
      return;
    }
    final pilihan = await _pilihTunda(jumlah);
    if (pilihan == null) return;
    try {
      final hasil = await ref.read(tundaPengingatRepoProvider).terapkan(
            pengingatId: pengingatId,
            jatuhTempoAsli: b.waktu,
            pilihan: pilihan,
            alasan: 'ditunda dari pusat notifikasi',
          );
      await ref.read(notifikasiRiwayatRepoProvider).tandaiDitunda(b.id);
      // Jejak audit: "pengingat ditunda sampai 23:30" (FR-138).
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.notifikasi,
        aksi: AksiAudit.tunda,
        entitas: 'pengingat',
        entitasId: '$pengingatId',
        sebelum: fmtJam(hasil.waktuPengingatSebelumnya),
        sesudah: fmtJam(hasil.waktuPengingatBaru),
        ringkas: ringkasTunda(hasil),
      );
      await _pesan('${ringkasTunda(hasil)} '
          '(${hasil.jumlahTunda} dari $batasMaksimalTunda kali). '
          '${catatanJatuhTempoTidakBerubah(hasil)}');
    } on BatasTundaTerlampaui catch (e) {
      await _pesan(e.pesan);
    } catch (e) {
      await _pesan('Penundaan tidak bisa disimpan sekarang. Penyebab: $e');
    }
    if (mounted) _muatUlang();
  }

  /// Lembar pilihan tunda + pratinjau waktunya (dihitung, bukan dikira-kira).
  Future<PilihanTunda?> _pilihTunda(int jumlahSudah) => showModalBottomSheet<PilihanTunda>(
        context: context,
        builder: (c) {
          final tema = Theme.of(c);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tunda pengingat',
                          style: tema.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Sudah ditunda $jumlahSudah dari $batasMaksimalTunda kali. '
                        '$catatanTundaTidakMengubahJatuhTempo',
                        style: tema.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                for (final p in PilihanTunda.values)
                  ListTile(
                    key: Key('pilihan_${p.name}'),
                    leading: const Icon(Icons.snooze),
                    title: Text(p.label),
                    subtitle: Text('Pengingat berikutnya '
                        '${fmtTanggalAman(hitungWaktuTunda(p, _sekarang))} '
                        '${fmtJam(hitungWaktuTunda(p, _sekarang))}'),
                    onTap: () => Navigator.of(c).pop(p),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pusat Notifikasi')),
      body: FutureBuilder<DataNotifikasi>(
        future: _masaDepan,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Riwayat tidak bisa dibaca saat ini. '
                  'Penyebab: ${snap.error}'),
            );
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _catatan(),
              const SizedBox(height: 12),
              _ringkasan(data),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const Key('saring_belum_dibaca'),
                value: _hanyaBelumDibaca,
                title: const Text('Hanya yang belum dibaca'),
                onChanged: (v) => setState(() {
                  _hanyaBelumDibaca = v;
                  _masaDepan = _muat();
                }),
              ),
              const SizedBox(height: 8),
              if (data.kosong)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Belum ada data riwayat notifikasi. Baris akan muncul '
                    'sendiri saat aplikasi mengirim pengingat.',
                  ),
                )
              else ...[
                if (data.kelompok.hariIni.isNotEmpty)
                  ..._bagian('Hari ini', data.kelompok.hariIni, data),
                if (data.kelompok.kemarin.isNotEmpty)
                  ..._bagian('Kemarin', data.kelompok.kemarin, data),
                if (data.kelompok.lebihLama.isNotEmpty)
                  ..._bagian('Lebih lama', data.kelompok.lebihLama, data),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _catatan() => Card(
        key: const Key('catatan_lokal_notifikasi'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.phonelink_lock_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(catatanLokalNotifikasi)),
                ],
              ),
              const SizedBox(height: 6),
              Text(catatanBatasNotifikasi,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );

  Widget _ringkasan(DataNotifikasi data) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ringkasan',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${data.belumDibaca} belum dibaca dari '
                  '${data.kelompok.total} riwayat yang ditampilkan.'),
              Text(
                'Tingkat: ${data.jumlahMendesak} mendesak · '
                '${data.jumlahPenting} penting · '
                '${data.kelompok.total - data.jumlahMendesak - data.jumlahPenting} biasa.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );

  List<Widget> _bagian(
      String judul, List<NotifikasiRiwayatData> baris, DataNotifikasi data) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(judul, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      for (final b in baris) _kartuBaris(b, data),
    ];
  }

  Widget _kartuBaris(NotifikasiRiwayatData b, DataNotifikasi data) {
    final tema = Theme.of(context);
    final tingkat = TingkatNotifikasi.dariDb(b.tingkat);
    final status = StatusNotifikasi.dariDb(b.status);
    final baru = status == StatusNotifikasi.baru;
    final jumlah = data.tundaUntuk(b.pengingatId);
    return Card(
      key: Key('notif_${b.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (tingkat) {
                    TingkatNotifikasi.mendesak => Icons.priority_high,
                    TingkatNotifikasi.penting => Icons.error_outline,
                    TingkatNotifikasi.biasa => Icons.notifications_none,
                  },
                  size: 18,
                  color: baru
                      ? tema.colorScheme.primary
                      : tema.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b.judul,
                    style: TextStyle(
                      fontWeight: baru ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (baru)
                  Container(
                    key: Key('tanda_baru_${b.id}'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: tema.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Belum dibaca',
                        style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(b.isi),
            const SizedBox(height: 4),
            Text(
              '${fmtTanggalAman(b.waktu)} ${fmtJam(b.waktu)} · ${tingkat.label} '
              '· kanal ${b.kanal} · ${status.label} · sumber ${b.sumber}'
              '${jumlah > 0 ? ' · ditunda $jumlah kali' : ''}',
              style: tema.textTheme.bodySmall,
            ),
            if (jumlah >= batasMaksimalTunda) ...[
              const SizedBox(height: 4),
              Text(
                'Batas tunda sudah tercapai, jadi pengingat ini tampil '
                '"mendesak" dan tidak bisa ditunda lagi.',
                style: tema.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                if (baru)
                  TextButton(
                    key: Key('baca_${b.id}'),
                    onPressed: () => _ubahStatus(b.id, selesai: false),
                    child: const Text('Tandai dibaca'),
                  ),
                if (status != StatusNotifikasi.selesai)
                  TextButton(
                    key: Key('selesai_${b.id}'),
                    onPressed: () => _ubahStatus(b.id, selesai: true),
                    child: const Text('Tandai selesai'),
                  ),
                if (b.pengingatId != null && bolehDitundaLagi(jumlah))
                  TextButton(
                    key: Key('tunda_${b.id}'),
                    onPressed: () => _tunda(b, data),
                    child: const Text('Tunda'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Batas baris riwayat yang ditampilkan sekali buka.
const int batasTampilNotifikasi = 200;
