/// Halaman masuk modul Aksi & Tujuan (FR-78/79/80/83).
///
/// Empat pintu:
/// - Tujuan (FR-78) — rantai tujuan -> proyek -> tugas,
/// - Tugas (FR-79)  — daftar tugas harian + tombol Tugas cepat,
/// - Kebiasaan (FR-80) — kebiasaan harian & ringkasan 7/30 hari,
/// - Perawatan berkala (FR-83) — jadwal perawatan & sorotan jatuh tempo.
///
/// Angka pada tiap baris dihitung dari data pengguna sendiri. Bila
/// penyimpanan belum menjawab dalam 5 detik, baris menampilkan "Belum ada
/// data" — bukan angka karangan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/utils/waktu.dart';
import '../../data/repository/aksi_repository.dart';
import 'aksi_providers.dart';
import 'kebiasaan_screen.dart';
import 'navigasi_aksi.dart';
import 'perawatan_screen.dart';
import 'tugas_cepat_sheet.dart';
import 'tugas_screen.dart';
import 'tujuan_screen.dart';

/// Batas hari sorotan perawatan (sama dengan FR-83 & layar perawatan).
const int batasHariSorotanPerawatan = 30;

class AksiHubScreen extends ConsumerStatefulWidget {
  const AksiHubScreen({super.key});

  @override
  ConsumerState<AksiHubScreen> createState() => _StateAksiHub();
}

class _StateAksiHub extends ConsumerState<AksiHubScreen> {
  late final AksiRepository _repo = ref.read(repoAksiProvider);

  bool _memuat = true;
  int? _tujuanAktif;
  int? _proyek;
  int? _tugasBelumSelesai;
  int? _tugasHariIni;
  int? _kebiasaanDipromosikan;
  int? _perawatanDekat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final db = ref.read(databaseProvider);
    try {
      final tujuan = await _repo
          .ambilTujuan(status: 'aktif')
          .timeout(const Duration(seconds: 5));
      final proyek =
          await _repo.ambilProyek().timeout(const Duration(seconds: 5));
      final tugas = await _repo
          .ambilTugas(selesai: false)
          .timeout(const Duration(seconds: 5));
      final kebiasaan = await (db.select(db.kebiasaan)
            ..where((k) => k.dipromosikan.equals(true)))
          .get()
          .timeout(const Duration(seconds: 5));
      final perawatan = await (db.select(db.perawatan))
          .get()
          .timeout(const Duration(seconds: 5));

      final hariIni = AksiRepository.hariSaja(waktuSekarang());
      final dekat = perawatan.where((p) {
        if (!p.aktif) return false;
        final sisa =
            AksiRepository.hariSaja(p.berikutnya).difference(hariIni).inDays;
        // Jadwal yang sudah lewat ikut dihitung: itu yang paling perlu
        // dilihat pengguna (sama dengan sorotan di layar perawatan).
        return sisa <= batasHariSorotanPerawatan;
      }).length;

      if (!mounted) return;
      setState(() {
        _tujuanAktif = tujuan.length;
        _proyek = proyek.length;
        _tugasBelumSelesai = tugas.length;
        _tugasHariIni = tugas
            .where((t) =>
                t.jatuhTempo != null &&
                AksiRepository.hariSaja(t.jatuhTempo!) == hariIni)
            .length;
        _kebiasaanDipromosikan =
            kebiasaan.where((k) => k.aktif).length;
        _perawatanDekat = dekat;
        _memuat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tujuanAktif = null;
        _proyek = null;
        _tugasBelumSelesai = null;
        _tugasHariIni = null;
        _kebiasaanDipromosikan = null;
        _perawatanDekat = null;
        _memuat = false;
      });
    }
  }

  Future<void> _tugasCepat() async {
    final tersimpan = await tampilkanTugasCepat(context, _repo);
    if (tersimpan != null) await _muat();
  }

  /// Kalimat angka jujur; "Belum ada data" bila pembacaan tidak berhasil.
  String _angka(int? nilai, String Function(int) kalimat) =>
      nilai == null ? 'Belum ada data' : kalimat(nilai);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Aksi & Tujuan')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: <Widget>[
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Tugas cepat', style: tema.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Simpan tugas singkat tanpa memilih proyek: '
                          'tekan tombol, tulis, lalu Simpan.',
                          style: tema.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('tombol_tugas_cepat_hub'),
                          onPressed: _tugasCepat,
                          icon: const Icon(Icons.bolt_outlined),
                          label: const Text('Tugas cepat'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Rencana', style: tema.textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        key: const Key('buka_tujuan'),
                        leading: const Icon(Icons.flag_outlined),
                        title: const Text('Tujuan'),
                        subtitle: Text(
                          '${_angka(_tujuanAktif, (n) => '$n tujuan aktif')} · '
                          '${_angka(_proyek, (n) => '$n proyek')}',
                          key: const Key('ringkas_tujuan'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => bukaLayarAksi(
                          context,
                          const TujuanScreen(),
                          rute: '/aksi/tujuan',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const Key('buka_tugas'),
                        leading: const Icon(Icons.checklist_outlined),
                        title: const Text('Tugas'),
                        subtitle: Text(
                          '${_angka(_tugasBelumSelesai, (n) => '$n belum selesai')} · '
                          '${_angka(_tugasHariIni, (n) => '$n jatuh tempo hari ini')}',
                          key: const Key('ringkas_tugas'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => bukaLayarAksi(
                          context,
                          const TugasScreen(),
                          rute: '/aksi/tugas',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Rutinitas', style: tema.textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        key: const Key('buka_kebiasaan'),
                        leading: const Icon(Icons.repeat_outlined),
                        title: const Text('Kebiasaan'),
                        subtitle: Text(
                          _angka(
                            _kebiasaanDipromosikan,
                            (n) => '$n dari 5 kebiasaan tampil di Hari Ini',
                          ),
                          key: const Key('ringkas_kebiasaan'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => bukaLayarAksi(
                          context,
                          const KebiasaanScreen(),
                          rute: '/aksi/kebiasaan',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const Key('buka_perawatan'),
                        leading: const Icon(Icons.build_outlined),
                        title: const Text('Perawatan berkala'),
                        subtitle: Text(
                          _angka(
                            _perawatanDekat,
                            (n) => '$n jatuh tempo dalam '
                                '$batasHariSorotanPerawatan hari',
                          ),
                          key: const Key('ringkas_perawatan'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => bukaLayarAksi(
                          context,
                          const PerawatanScreen(),
                          rute: '/aksi/perawatan',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
