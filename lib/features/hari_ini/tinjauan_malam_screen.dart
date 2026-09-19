/// Layar Tinjauan Malam (FR-64) — apa yang selesai, apa yang belum, satu
/// pertanyaan refleksi, dan catatan yang disimpan di perangkat.
///
/// Catatan refleksi disimpan di tabel `pengaturan` (k-v) dengan kunci
/// `tinjauan_malam_<yyyy-MM-dd>` — tidak perlu tabel baru hanya untuk satu
/// catatan per hari.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/hari_ini/hari_berat.dart';
import '../../core/hari_ini/tinjauan_malam.dart';
import '../../core/providers/app_providers.dart';
import '../../data/repository/aksi_repository.dart';
import '../../data/repository/kebiasaan_repository.dart';
import '../../data/repository/kesehatan_repository.dart';
import '../../data/repository/pengaturan_repository.dart';

/// Saklar pengguna: tampilkan kartu "Tinjauan malam" di Hari Ini?
final tinjauanMalamAktifProvider = FutureProvider<bool>(
    (ref) => PengaturanRepository(ref.watch(databaseProvider))
        .bacaSaklar(kunciSaklarTinjauanMalam, bawaan: true));

/// Kunci pengaturan (dipakai layar & uji).
const String kunciSaklarTinjauanMalam = 'tinjauan_malam_aktif';
String kunciCatatanTinjauan(DateTime hari) =>
    'tinjauan_malam_${hari.year.toString().padLeft(4, '0')}-'
    '${hari.month.toString().padLeft(2, '0')}-'
    '${hari.day.toString().padLeft(2, '0')}';

/// Isi tinjauan untuk satu hari, dihitung dari data nyata.
final isiTinjauanProvider =
    FutureProvider.autoDispose.family<IsiTinjauanMalam, DateTime>(
        (ref, hari) async {
  final db = ref.watch(databaseProvider);
  final awal = DateTime(hari.year, hari.month, hari.day);
  final akhir = awal.add(const Duration(days: 1));

  final tagihan = await db.select(db.tagihan).get();
  final namaTagihan = {for (final t in tagihan) t.id: t.nama};

  // Dibayar hari ini (bukti dari riwayat, bukan dari status saja).
  // Penyaringan tanggal dilakukan di Dart supaya tidak bergantung ekspresi
  // khusus drift di lapisan layar.
  final semuaRiwayat = await db.select(db.riwayatPembayaran).get();
  final riwayat = semuaRiwayat
      .where((r) =>
          !r.tanggalBayar.isBefore(awal) && r.tanggalBayar.isBefore(akhir))
      .toList();

  final lunasHariIni = <JudulNominal>[
    for (final r in riwayat)
      JudulNominal(
        judul: namaTagihan[r.tagihanId] ?? 'Tagihan #${r.tagihanId}',
        nominalSen: r.jumlahSen,
      ),
  ];

  final belum = <JudulNominal>[
    for (final t in tagihan)
      if (!t.lunas && t.statusAktif)
        JudulNominal(judul: t.nama, nominalSen: t.jumlahSen),
  ];

  final aksi = AksiRepository(db);
  final tugasSemua = await aksi.ambilTugas();
  final tugasSelesai = <JudulNominal>[];
  final tugasBelum = <JudulNominal>[];
  for (final t in tugasSemua) {
    final selesaiPada = t.selesaiPada;
    if (t.selesai) {
      if (selesaiPada != null &&
          !selesaiPada.isBefore(awal) &&
          selesaiPada.isBefore(akhir)) {
        tugasSelesai.add(JudulNominal(judul: t.nama));
      }
      continue;
    }
    final jt = t.jatuhTempo;
    if (jt != null && !DateTime(jt.year, jt.month, jt.day).isAfter(awal)) {
      tugasBelum.add(JudulNominal(judul: t.nama));
    }
  }

  final kebRepo = KebiasaanRepository(db);
  final dipromosikan = await kebRepo.ambilDipromosikan();
  final nilai = await kebRepo.nilaiHari(awal);
  final kebiasaan = <KebiasaanHariIni>[
    for (final k in dipromosikan)
      KebiasaanHariIni(nama: k.nama, ditandai: (nilai[k.id] ?? 0) > 0),
  ];

  final air = await KesehatanRepository(db).catatanAirRentang(
    dari: awal,
    sampai: akhir.subtract(const Duration(seconds: 1)),
  );

  return susunTinjauanMalam(
    hari: awal,
    tagihanLunasHariIni: lunasHariIni,
    tagihanBelumSelesai: belum,
    tugasSelesaiHariIni: tugasSelesai,
    tugasBelumSelesai: tugasBelum,
    kebiasaan: kebiasaan,
    jumlahAirHariIni: air.length,
  );
});

/// Ringkas tugas untuk mode hari berat (FR-66) — dipakai layar Hari Ini.
final tugasRingkasProvider =
    FutureProvider.autoDispose<List<TugasRingkas>>((ref) async {
  final daftar = await AksiRepository(ref.watch(databaseProvider))
      .ambilTugas(selesai: false);
  return [
    for (final t in daftar)
      TugasRingkas(
        id: t.id,
        nama: t.nama,
        jatuhTempo: t.jatuhTempo,
        prioritas: t.prioritas,
        selesai: t.selesai,
      ),
  ];
});

class TinjauanMalamScreen extends ConsumerStatefulWidget {
  const TinjauanMalamScreen({super.key, required this.hari});

  final DateTime hari;

  @override
  ConsumerState<TinjauanMalamScreen> createState() =>
      _TinjauanMalamScreenState();
}

class _TinjauanMalamScreenState extends ConsumerState<TinjauanMalamScreen> {
  final _catatan = TextEditingController();
  bool _memuatCatatan = true;
  bool _sudahUbahSaklar = false;

  @override
  void initState() {
    super.initState();
    _muatCatatan();
  }

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _muatCatatan() async {
    final teks = await PengaturanRepository(ref.read(databaseProvider))
        .bacaTeks(kunciCatatanTinjauan(widget.hari), '');
    if (!mounted) return;
    setState(() {
      _catatan.text = teks;
      _memuatCatatan = false;
    });
  }

  Future<void> _simpanCatatan() async {
    final teks = _catatan.text.trim();
    await PengaturanRepository(ref.read(databaseProvider))
        .simpan(kunciCatatanTinjauan(widget.hari), teks);
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.pengaturan,
      aksi: AksiAudit.ubah,
      entitas: 'tinjauan_malam',
      entitasId: kunciCatatanTinjauan(widget.hari),
      ringkas: 'Catatan tinjauan malam ${labelHariTinjauan(widget.hari)} '
          'disimpan.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(teks.isEmpty
            ? 'Catatan dikosongkan.'
            : 'Catatan tinjauan malam disimpan.')));
  }

  Future<void> _ubahSaklar(bool nilai) async {
    await PengaturanRepository(ref.read(databaseProvider))
        .simpan(kunciSaklarTinjauanMalam, nilai ? 'true' : 'false');
    if (!mounted) return;
    setState(() => _sudahUbahSaklar = true);
    ref.invalidate(tinjauanMalamAktifProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(nilai
            ? 'Tinjauan malam tampil di layar Hari Ini.'
            : 'Tinjauan malam disembunyikan dari Hari Ini. Datanya tetap ada.')));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final isiAsync = ref.watch(isiTinjauanProvider(widget.hari));
    final aktifAsync = ref.watch(tinjauanMalamAktifProvider);
    final aktif = aktifAsync.value ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Tinjauan malam')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text(labelHariTinjauan(widget.hari),
              style: tema.textTheme.titleMedium),
          isiAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Belum bisa membaca data hari ini.'),
            ),
            data: (isi) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _Blok(
                  judul: 'Yang selesai hari ini (${isi.jumlahSelesai})',
                  kosong: 'Belum ada yang tercatat selesai hari ini.',
                  baris: isi.selesai,
                ),
                const SizedBox(height: 12),
                _Blok(
                  judul: 'Yang belum (${isi.jumlahBelum})',
                  kosong: 'Tidak ada yang menggantung hari ini.',
                  baris: isi.belum,
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Satu pertanyaan',
                            style: tema.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(isi.pertanyaan,
                            key: const Key('pertanyaan_malam')),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('catatan_refleksi'),
                          controller: _catatan,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Catatan (opsional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            key: const Key('simpan_refleksi'),
                            onPressed: _memuatCatatan ? null : _simpanCatatan,
                            child: const Text('Simpan catatan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: SwitchListTile(
                    key: const Key('saklar_tinjauan_malam'),
                    value: aktif,
                    onChanged: _ubahSaklar,
                    title: const Text('Tampilkan tinjauan malam'),
                    subtitle: const Text('Muncul di layar Hari Ini setelah '
                        'pukul 17.00. Mematikan tidak menghapus catatan.'),
                  ),
                ),
                if (_sudahUbahSaklar)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Pengaturan tersimpan di perangkat ini.'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Blok extends StatelessWidget {
  const _Blok({required this.judul, required this.kosong, required this.baris});

  final String judul;
  final String kosong;
  final List<BarisTinjauan> baris;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul, style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (baris.isEmpty)
              Text(kosong, style: tema.textTheme.bodyMedium)
            else
              for (final b in baris)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.judul),
                      Text(b.keterangan, style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

