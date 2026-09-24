/// Layar Hari Ini (FR-60) + Kartu Pilar (FR-61) + Perhatian (FR-62).
///
/// Sumber angka: tabel tagihan yang sudah ada (F1/F2) + status izin pengingat
/// (F3). Pilar yang modulnya belum ada menampilkan "Belum ada data" (III-11).
library;

import 'package:flutter/material.dart';
import 'package:personal_life_os/core/utils/waktu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audit/audit_log.dart';
import '../../core/theme/editorial.dart';
import '../../core/hari_ini/hari_berat.dart';
import '../../core/hari_ini/model_hari_ini.dart';
import '../../core/hari_ini/penyusun_hari_ini.dart';
import '../../data/database/database.dart';
import '../rumah/rumah_providers.dart';
import '../../core/ibadah/kalender_hijriah.dart';
import '../../core/notifikasi/perencana_pengingat.dart';
import '../../core/notifikasi/tunda_pengingat.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../data/repository/notifikasi_riwayat_repository.dart';
import 'kartu_hari_berat.dart';
import 'kartu_pilar.dart';
import 'pemetaan_tagihan.dart';
import 'tinjauan_malam_screen.dart';
import 'warna_tingkat.dart';

class HariIniScreen extends ConsumerStatefulWidget {
  const HariIniScreen({
    super.key,
    this.jamSekarang,
    this.ambilJumlahSholatTercatat,
    this.namaPanggilan = 'Anda',
  });

  /// Jam yang disuntik uji. Dianggap TANGGAL SIPIL perangkat (bukan instan
  /// UTC), karena agenda menanyakan "hari apa sekarang di perangkat".
  final DateTime Function()? jamSekarang;

  /// Pembacaan catatan sholat (FR-88). null = modul belum dipasang.
  final Future<int?> Function()? ambilJumlahSholatTercatat;

  final String namaPanggilan;

  @override
  ConsumerState<HariIniScreen> createState() => _HariIniScreenState();
}

class _HariIniScreenState extends ConsumerState<HariIniScreen> {
  int? _jumlahSholat;
  bool _sudahBacaSholat = false;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _bacaCatatanSholat();
  }

  Future<void> _bacaCatatanSholat() async {
    final f = widget.ambilJumlahSholatTercatat;
    if (f == null) return;
    try {
      final n = await f();
      if (!mounted) return;
      setState(() {
        _jumlahSholat = n;
        _sudahBacaSholat = true;
      });
    } catch (_) {
      // Catatan gagal dibaca bukan alasan menampilkan galat ke pengguna.
      if (!mounted) return;
      setState(() => _sudahBacaSholat = true);
    }
  }

  /// FR-66 — tunda pengingat butir yang tidak mendesak.
  ///
  /// Yang bergeser hanya waktu pengingat; tanggal jatuh tempo tidak disentuh
  /// (aturan `tunda_pengingat.dart`, FR-148).
  Future<void> _tundaButir(ButirHariBerat b) async {
    if (b.jenis != 'tagihan') {
      // ponytail: tugas belum punya lembar ubah tanggal, jadi tombolnya tidak
      // pernah ditampilkan untuk tugas.
      return;
    }
    final pengingatId = idNotifikasi(b.id, slotTunda);
    try {
      final hasil = await TundaPengingatRepository(
        ref.read(databaseProvider),
        jam: () => _sekarang,
      ).terapkan(
            pengingatId: pengingatId,
            jatuhTempoAsli: b.jatuhTempo,
            pilihan: PilihanTunda.besokSembilan,
            alasan: 'ditunda dari mode hari berat',
          );
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.notifikasi,
        aksi: AksiAudit.tunda,
        entitas: 'pengingat',
        entitasId: '$pengingatId',
        ringkas: 'Pengingat "${b.nama}" ditunda sampai '
            '${fmtTanggalAman(hasil.waktuPengingatBaru)}. '
            'Jatuh tempo tetap ${fmtTanggalAman(b.jatuhTempo)}.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pengingat "${b.nama}" ditunda sampai '
              '${fmtTanggalAman(hasil.waktuPengingatBaru)}. '
              'Tanggal jatuh temponya tidak berubah.')));
    } on BatasTundaTerlampaui catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.pesan)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Penundaan belum bisa disimpan sekarang.')));
    }
  }

  /// Buka modul asal butir (tagihan atau kerja).
  void _bukaButir(ButirHariBerat b) {
    context.push(b.jenis == 'tugas' ? '/kerja' : '/tagihan');
  }

  void _bukaTinjauanMalam() {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TinjauanMalamScreen(hari: _sekarang)));
  }

  @override
  Widget build(BuildContext context) {
    final tagihanAsync = ref.watch(semuaTagihanProvider);
    final izinAsync = ref.watch(statusIzinPengingatProvider);
    final izin = izinAsync.value;
    final tagihan = petaDaftarTagihan(tagihanAsync.value ?? const <TagihanData>[]);
    // FR-66 — beban hari ini (tagihan + tugas). FR-64 — saklar tinjauan malam.
    final tugasRingkas =
        ref.watch(tugasRingkasProvider).value ?? const <TugasRingkas>[];
    final hariBerat = susunHariBerat(
      tagihan: tagihan,
      tugas: tugasRingkas,
      hari: _sekarang,
    );
    final tinjauanAktif = ref.watch(tinjauanMalamAktifProvider).value ?? true;

    // FR-126 & FR-125: garansi aset yang hampir berakhir + perawatan yang
    // mendekat, keduanya muncul sebagai Perhatian (maks 5 butir).
    final garansiAset = ref.watch(garansiDekatProvider).value ?? const <AsetData>[];
    final perawatanDekat =
        ref.watch(perawatanDekatProvider).value ?? const <PerawatanData>[];

    final data = DataHariIni(
      sekarang: _sekarang,
      tagihan: tagihan,
      jumlahSholatTercatat: _jumlahSholat,
      statusIzinPengingat: izin == null ? null : (izin.siap ? 'diizinkan' : 'belum'),
      namaPanggilan: widget.namaPanggilan,
      garansiAset: [
        for (final a in garansiAset)
          if (a.garansiSampai != null)
            RingkasGaransiAset(
                asetId: a.id, nama: a.nama, sampai: a.garansiSampai!),
      ],
      perawatanAset: [
        for (final w in perawatanDekat)
          RingkasPerawatanAset(
            perawatanId: w.id,
            nama: w.nama,
            berikutnya: w.berikutnya,
            asetId: w.asetId,
          ),
      ],
    );
    final ringkas = susunHariIni(data);
    final hijri = hijriahDariMasehi(_sekarang);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hari Ini'),
        actions: [
          IconButton(
            tooltip: 'Ringkasan pagi',
            onPressed: () => context.push('/briefing'),
            icon: const Icon(Icons.wb_twilight),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _Kepala(
            nama: widget.namaPanggilan,
            tanggal: _sekarang,
            hijriah: hijri?.label ?? 'Belum ada data Hijriah',
            jumlahPerhatian: ringkas.perhatian.length,
            jumlahAgenda: ringkas.jumlahAgenda,
          ),
          const SizedBox(height: 12),
          if (_sekarang.hour < 12) ...[
            _KartuRingkasanPagi(onTap: () => context.push('/briefing')),
            const SizedBox(height: 12),
          ],
          if (hariBerat.berat) ...[
            KartuHariBerat(
              hasil: hariBerat,
              onTunda: _tundaButir,
              onBuka: _bukaButir,
            ),
            const SizedBox(height: 12),
          ],
          if (_sekarang.hour >= 17 && tinjauanAktif) ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                key: const Key('kartu_tinjauan_malam'),
                leading: const Icon(Icons.nightlight_outlined),
                title: const Text('Tinjauan malam'),
                subtitle: const Text(
                    'Apa yang selesai, apa yang belum, dan satu pertanyaan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _bukaTinjauanMalam,
              ),
            ),
            const SizedBox(height: 12),
          ],
          const _JudulBlok('Pilar hari ini'),
          _GridPilar(
            pilar: ringkas.pilar,
            onTap: (p) {
              final rute = p.rute;
              if (rute == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modul ini menyusul.')),
                );
                return;
              }
              context.push(rute);
            },
          ),
          const SizedBox(height: 16),
          _JudulBlok('Perhatian (${ringkas.perhatian.length})'),
          if (ringkas.perhatian.isEmpty)
            const _Kosong('Tidak ada yang perlu perhatian hari ini')
          else
            for (final b in ringkas.perhatian) _BarisPerhatian(butir: b),
          const SizedBox(height: 16),
          _JudulBlok('Agenda hari ini'),
          if (!ringkas.adaAgenda)
            const _Kosong('Belum ada agenda hari ini')
          else ...[
            for (final b in ringkas.agenda) _BarisAgenda(butir: b),
            if (ringkas.jumlahAgenda > ringkas.agenda.length)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.push('/kerja'),
                  child: Text('Lihat semua (${ringkas.jumlahAgenda})'),
                ),
              ),
          ],
          if (!_sudahBacaSholat && widget.ambilJumlahSholatTercatat != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Membaca catatan sholat…'),
            ),
        ],
      ),
    );
  }
}

class _Kepala extends StatelessWidget {
  const _Kepala({
    required this.nama,
    required this.tanggal,
    required this.hijriah,
    this.jumlahPerhatian = 0,
    this.jumlahAgenda = 0,
  });

  final String nama;
  final DateTime tanggal;
  final String hijriah;
  final int jumlahPerhatian;
  final int jumlahAgenda;

  /// Satu kalimat yang menjawab "hari ini saya harus lihat apa?" sebelum
  /// pengguna menggulir. Hanya menghitung butir yang sudah disusun layar ini.
  String get _kalimatUtama => jumlahPerhatian > 0
      ? 'Ada $jumlahPerhatian hal yang perlu diperhatikan'
      : 'Tidak ada yang mendesak hari ini';

  String get _kalimatAgenda => jumlahAgenda > 0
      ? '$jumlahAgenda acara hari ini'
      : 'Belum ada acara terjadwal';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assalamualaikum, $nama',
                  style: tema.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                fmtTanggalAman(tanggal),
                style: tema.textTheme.titleSmall
                    ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              Text(
                '$hijriah · perhitungan, bukan penetapan resmi',
                style: tema.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
        KartuUtama(
          label: 'Hari ini',
          judul: _kalimatUtama,
          anak: Text(
            _kalimatAgenda,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onPrimaryContainer.withValues(alpha: 0.82),
            ),
          ),
        ),
      ],
    );
  }
}

class _KartuRingkasanPagi extends StatelessWidget {
  const _KartuRingkasanPagi({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.wb_twilight),
          title: const Text('Ringkasan pagi'),
          subtitle: const Text('Agenda, tagihan 7 hari, dan waktu sholat berikutnya'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class _JudulBlok extends StatelessWidget {
  const _JudulBlok(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Text(
        teks,
        style: tema.textTheme.labelSmall
            ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong(this.teks);

  final String teks;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(teks, style: tema.textTheme.bodyMedium),
    );
  }
}

/// Dua kolom, tinggi baris disamakan supaya sisi kiri & kanan rata.
///
/// Sebelumnya memakai Wrap: tinggi kartu mengikuti isi masing-masing sehingga
/// baris tampak bergerigi. Sekarang tiap pasangan dibungkus IntrinsicHeight.
class _GridPilar extends StatelessWidget {
  const _GridPilar({required this.pilar, required this.onTap});

  static const _jarak = 8.0;

  final List<NilaiPilar> pilar;
  final void Function(NilaiPilar) onTap;

  @override
  Widget build(BuildContext context) {
    final baris = <Widget>[];
    for (var i = 0; i < pilar.length; i += 2) {
      final kiri = pilar[i];
      final kanan = i + 1 < pilar.length ? pilar[i + 1] : null;
      baris.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < pilar.length ? _jarak : 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: KartuPilar(nilai: kiri, onTap: () => onTap(kiri)),
                ),
                const SizedBox(width: _jarak),
                Expanded(
                  child: kanan == null
                      ? const SizedBox.shrink()
                      : KartuPilar(nilai: kanan, onTap: () => onTap(kanan)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: baris,
    );
  }
}

class _BarisAgenda extends StatelessWidget {
  const _BarisAgenda({required this.butir});

  final ButirAgenda butir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final warna = warnaTingkat(butir.tingkat, tema);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: butir.rute == null ? null : () => context.push(butir.rute!),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ikonButir(butir.jenis), color: warna, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      butir.judul,
                      style: tema.textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(butir.alasan, style: tema.textTheme.bodySmall, maxLines: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarisPerhatian extends StatelessWidget {
  const _BarisPerhatian({required this.butir});

  final ButirPerhatian butir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final warna = warnaTingkat(butir.tingkat, tema);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.priority_high, size: 18, color: warna),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    butir.judul,
                    style: tema.textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(butir.alasan, style: tema.textTheme.bodySmall, maxLines: 3),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: butir.rute == null ? null : () => context.push(butir.rute!),
                child: Text(butir.labelTombol),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
