/// Layar daftar & pengelola dokumen penting (FR-128) + masa berlaku (FR-129).
///
/// Isi layar:
///  1. satu kalimat catatan jujur soal berkas (tidak ada enkripsi di proyek ini);
///  2. bagian **"Masa berlaku dekat ini"** — dokumen aktif yang tanggal
///     berakhirnya tersisa paling banyak 90 hari, termasuk yang sudah lewat;
///  3. seluruh dokumen, urut tanggal berakhir terdekat; dokumen yang diarsipkan
///     disembunyikan sampai saklar "Tampilkan arsip" dinyalakan;
///  4. tiap baris bisa ditandai **sudah diperpanjang**, diubah, diarsipkan, atau
///     dihapus (hapus selalu lewat konfirmasi).
///
/// Rute: `/dokumen` (potongan rute ada di laporan; berkas rute milik Dinda).
/// Layar ini punya Scaffold + AppBar sendiri, jadi TIDAK dibungkus HalamanJudul.
///
/// Waktu dibaca lewat [jamSekarang] (bawaan `waktuSekarang()`) supaya hasilnya
/// dapat dikunci saat pengujian. Setiap pembacaan penyimpanan dibungkus
/// `.timeout(5 detik)`; bila gagal, layar menulis "Belum ada data" apa adanya
/// dan tidak menampilkan angka karangan.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/dokumen/samar_dokumen.dart';
import '../../core/platform/bagikan.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/dokumen_repository.dart';
import 'dokumen_form_screen.dart';
import 'dokumen_providers.dart';
import 'teks_dokumen.dart';

/// Batas waktu baca penyimpanan sebelum layar menyerah (aturan repo).
const Duration batasBacaDokumen = Duration(seconds: 5);

class DokumenScreen extends ConsumerStatefulWidget {
  const DokumenScreen({super.key, this.jamSekarang});

  /// Sumber waktu opsional (untuk pengujian).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<DokumenScreen> createState() => _DokumenScreenState();
}

class _DokumenScreenState extends ConsumerState<DokumenScreen> {
  List<DokumenData>? semua;
  List<DokumenData> sorotan = const <DokumenData>[];
  bool memuat = true;
  bool adaMasalah = false;
  bool tampilkanArsip = false;

  DateTime get sekarang => (widget.jamSekarang ?? waktuSekarang)();

  @override
  void initState() {
    super.initState();
    muat();
  }

  /// Baca ulang daftar dokumen & dokumen yang masa berlakunya dekat.
  Future<void> muat() async {
    final repo = ref.read(repoDokumenProvider);
    try {
      final daftar = await repo
          .ambilSemua(termasukArsip: tampilkanArsip)
          .timeout(batasBacaDokumen);
      final dekat = await repo
          .segeraBerakhir(sekarang: sekarang)
          .timeout(batasBacaDokumen);
      if (!mounted) return;
      setState(() {
        semua = daftar;
        sorotan = dekat;
        memuat = false;
        adaMasalah = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        memuat = false;
        adaMasalah = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumen penting'),
        actions: [
          IconButton(
            key: const Key('ekspor_dokumen'),
            tooltip: 'Salin daftar',
            icon: const Icon(Icons.ios_share),
            onPressed:
                (semua ?? const <DokumenData>[]).isEmpty ? null : dialogEkspor,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tombol_dokumen_baru'),
        onPressed: () => bukaForm(null),
        icon: const Icon(Icons.add),
        label: const Text('Dokumen'),
      ),
      body: isi(),
    );
  }

  Widget isi() {
    final daftar = semua;
    if (daftar == null) {
      if (memuat) return const Center(child: CircularProgressIndicator());
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Belum ada data', textAlign: TextAlign.center),
        ),
      );
    }

    final tema = Theme.of(context);
    final idSorotan = <int>{for (final d in sorotan) d.id};
    final sisanya =
        daftar.where((d) => !idSorotan.contains(d.id)).toList(growable: false);

    return RefreshIndicator(
      onRefresh: muat,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Card(
            key: const Key('catatan_berkas'),
            color: tema.colorScheme.surfaceContainerHighest,
            margin: const EdgeInsets.only(bottom: 8),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(catatanBerkasJujur),
            ),
          ),
          SwitchListTile(
            key: const Key('tampilkan_arsip'),
            value: tampilkanArsip,
            contentPadding: EdgeInsets.zero,
            title: const Text('Tampilkan arsip'),
            subtitle: const Text('Dokumen arsip tidak dibuatkan pengingat.'),
            onChanged: (v) async {
              setState(() => tampilkanArsip = v);
              await muat();
            },
          ),
          if (adaMasalah)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Daftar ini mungkin belum yang terbaru.'),
            ),
          if (sorotan.isNotEmpty) ...[
            Text('Masa berlaku dekat ini', style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...sorotan.map(kartuBaris),
            const Divider(height: 24),
          ],
          if (sisanya.isNotEmpty)
            Text('Semua dokumen', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (daftar.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Text('Belum ada data', textAlign: TextAlign.center),
            ),
          ...sisanya.map(kartuBaris),
        ],
      ),
    );
  }

  /// FR-53 — salin nomor dokumen langsung dari daftar (tanpa membuka berkas).
  ///
  /// Nomornya TIDAK ditampilkan di pesan supaya tidak terbaca orang di sebelah;
  /// pesan hanya menyebut dokumen apa yang nomornya sudah masuk papan klip.
  Future<void> salinNomor(DokumenData d) async {
    final nomor = d.nomor?.trim() ?? '';
    if (nomor.isEmpty) return;
    var berhasil = true;
    try {
      // Batas waktu: bila kanal papan klip tidak menjawab, pengguna diberi tahu
      // apa adanya daripada pesan "berhasil" yang belum tentu benar.
      await Clipboard.setData(ClipboardData(text: nomor))
          .timeout(const Duration(milliseconds: 1200));
    } catch (_) {
      berhasil = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('pesan_salin_nomor'),
      content: Text(berhasil
          ? 'Nomor ${d.nama} disalin ke papan klip.'
          : 'Nomor ${d.nama} belum bisa disalin di perangkat ini.'),
    ));
  }

  /// FR-130 — bagikan terkendali.
  ///
  /// Yang dibagikan adalah **teks dengan nomor disamarkan** (ditulis ke berkas
  /// .txt lalu dikirim lewat lembar berbagi Android). Berkas asli hanya ikut
  /// bila pengguna mencentang sendiri di dialog DAN berkasnya ditemukan.
  /// Tidak ada berkas terkirim tanpa aksi pengguna yang jelas.
  Future<void> bagikanTersamar(DokumenData d) async {
    var adaBerkas = false;
    String? jalurBerkas;
    try {
      final folder = await getApplicationDocumentsDirectory()
          .timeout(const Duration(seconds: 3));
      final nama = d.berkasNama?.trim() ?? '';
      if (nama.isNotEmpty) {
        final kandidat = File('${folder.path}/$nama');
        if (await kandidat.exists()) {
          adaBerkas = true;
          jalurBerkas = kandidat.path;
        }
      }
    } catch (_) {
      adaBerkas = false;
    }
    if (!mounted) return;

    var sertakanBerkas = false;
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) {
          final contoh = susunBagikanTersamar(
            nama: d.nama,
            jenisDokumen: labelJenisDokumen[d.jenis] ?? d.jenis,
            nomor: d.nomor,
            pemilik: d.pemilik,
            berlakuSampai: d.berlakuSampai,
            berkasNama: d.berkasNama,
            jalurBerkas: jalurBerkas,
            sertakanBerkas: sertakanBerkas,
          );
          return AlertDialog(
            key: const Key('dialog_bagikan_tersamar'),
            title: Text('Bagikan ${d.nama}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Yang dibagikan (nomor sudah disamarkan):'),
                  const SizedBox(height: 8),
                  Text(contoh.teks, key: const Key('pratinjau_bagikan')),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    key: const Key('centang_sertakan_berkas'),
                    value: sertakanBerkas,
                    onChanged: adaBerkas
                        ? (v) => setDialogState(() => sertakanBerkas = v ?? false)
                        : null,
                    title: const Text('Sertakan berkas asli'),
                    subtitle: Text(adaBerkas
                        ? 'Berkas ditemukan & akan ikut terkirim beserta nomor aslinya'
                        : 'Berkas aslinya tidak ada di perangkat ini'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                key: const Key('konfirmasi_bagikan'),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Bagikan'),
              ),
            ],
          );
        },
      ),
    );
    if (lanjut != true) return;

    final isi = susunBagikanTersamar(
      nama: d.nama,
      jenisDokumen: labelJenisDokumen[d.jenis] ?? d.jenis,
      nomor: d.nomor,
      pemilik: d.pemilik,
      berlakuSampai: d.berlakuSampai,
      berkasNama: d.berkasNama,
      jalurBerkas: jalurBerkas,
      sertakanBerkas: sertakanBerkas,
    );
    var berhasil = false;
    var berhasilBerkas = false;
    try {
      final folder = await getApplicationDocumentsDirectory()
          .timeout(const Duration(seconds: 3));
      final berkasTeks = File('${folder.path}/${namaBerkasBagikan(d.nama)}');
      await berkasTeks.writeAsString(isi.teks);
      berhasil = await bagikanBerkas(
        jalur: berkasTeks.path,
        judul: isi.judul,
        jenis: 'text/plain',
      );
      if (isi.berkasIkut && isi.jalurBerkas != null) {
        berhasilBerkas = await bagikanBerkas(
          jalur: isi.jalurBerkas!,
          judul: 'Berkas asli ${d.nama}',
          jenis: 'application/octet-stream',
        );
      }
    } catch (_) {
      berhasil = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('pesan_bagikan_tersamar'),
      content: Text(berhasil
          ? isi.berkasIkut
              ? 'Lembar berbagi dibuka: teks tersamar + berkas asli '
                  '${berhasilBerkas ? 'ikut terkirim' : 'gagal dikirim'}.'
              : 'Lembar berbagi dibuka: teks tersamar (berkas asli tidak ikut).'
          : 'Belum bisa membagikan di perangkat ini.'),
    ));
  }

  Widget kartuBaris(DokumenData d) {
    final tema = Theme.of(context);
    final jenis = labelJenisDokumen[d.jenis] ?? d.jenis;
    return Card(
      key: Key('baris_dokumen_${d.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: Text(d.nama, style: tema.textTheme.titleMedium)),
                Text(jenis, style: tema.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 4),
            if (d.nomor != null && d.nomor!.isNotEmpty)
              Text('Nomor: ${d.nomor}'),
            if (d.pemilik != null && d.pemilik!.isNotEmpty)
              Text('Milik: ${d.pemilik}'),
            if (d.terbit != null) Text('Terbit: ${teksTanggalIsian(d.terbit!)}'),
            Text(kalimatTanggalBerlaku(d.berlakuSampai, sekarang),
                style: tema.textTheme.bodySmall),
            if (d.diperpanjangPada != null)
              Text(
                'Terakhir ditandai diperpanjang: '
                '${teksTanggalIsian(d.diperpanjangPada!)}',
                style: tema.textTheme.bodySmall,
              ),
            if (d.berkasNama != null && d.berkasNama!.isNotEmpty)
              Text('Catatan nama berkas: ${d.berkasNama}',
                  style: tema.textTheme.bodySmall),
            Row(
              children: [
                if (!d.aktif)
                  Text('Pengingat dimatikan', style: tema.textTheme.bodySmall),
                if (d.arsip)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('Di arsip', style: tema.textTheme.bodySmall),
                  ),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (d.nomor != null && d.nomor!.isNotEmpty)
                  TextButton.icon(
                    key: Key('salin_nomor_${d.id}'),
                    onPressed: () => salinNomor(d),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Salin nomor'),
                  ),
                TextButton.icon(
                  key: Key('bagikan_tersamar_${d.id}'),
                  onPressed: () => bagikanTersamar(d),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Bagikan tersamar'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                TextButton.icon(
                  key: Key('diperpanjang_${d.id}'),
                  onPressed: () => tandaiDiperpanjang(d),
                  icon: const Icon(Icons.event_repeat, size: 18),
                  label: const Text('Sudah diperpanjang'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                IconButton(
                  key: Key('ubah_dokumen_${d.id}'),
                  tooltip: 'Ubah',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => bukaForm(d),
                ),
                IconButton(
                  key: Key('arsip_dokumen_${d.id}'),
                  tooltip: d.arsip ? 'Kembalikan ke daftar' : 'Arsipkan',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                      d.arsip ? Icons.unarchive_outlined : Icons.archive_outlined,
                      size: 20),
                  onPressed: () => ubahArsip(d),
                ),
                IconButton(
                  key: Key('hapus_dokumen_${d.id}'),
                  tooltip: 'Hapus',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => hapus(d),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Aksi
  // ------------------------------------------------------------------

  /// Buka form tambah ([d] kosong) atau form ubah, lalu muat ulang bila tersimpan.
  Future<void> bukaForm(DokumenData? d) async {
    final tersimpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DokumenFormScreen(
          dokumen: d,
          jamSekarang: widget.jamSekarang,
        ),
      ),
    );
    if (tersimpan != true || !mounted) return;
    await muat();
    if (!mounted) return;
    pesan(d == null ? 'Dokumen tersimpan.' : 'Perubahan dokumen tersimpan.');
  }

  /// Tandai dokumen sudah diperpanjang, dengan tanggal berakhir baru opsional.
  Future<void> tandaiDiperpanjang(DokumenData d) async {
    final kapan = await showDialog<DateTime?>(
      context: context,
      builder: (_) => DialogPerpanjang(dokumen: d),
    );
    if (kapan == batalPerpanjang || !mounted) return;

    final repo = ref.read(repoDokumenProvider);
    try {
      final baru = await repo
          .tandaiDiperpanjang(
            d.id,
            berlakuSampaiBaru: kapan == tanpaTanggalBaru ? null : kapan,
          )
          .timeout(batasBacaDokumen);
      if (!mounted) return;
      await muat();
      if (!mounted) return;
      final akhir = baru.berlakuSampai;
      pesan(akhir == null
          ? 'Dokumen "${d.nama}" ditandai sudah diperpanjang.'
          : 'Dokumen "${d.nama}" ditandai sudah diperpanjang sampai '
              '${teksTanggalIsian(akhir)}.');
    } catch (_) {
      if (!mounted) return;
      pesan('Dokumen "${d.nama}" belum bisa ditandai saat ini.');
    }
  }

  /// Pindahkan dokumen ke arsip atau kembalikan ke daftar.
  Future<void> ubahArsip(DokumenData d) async {
    final repo = ref.read(repoDokumenProvider);
    try {
      await repo.tandaiArsip(d.id, arsip: !d.arsip).timeout(batasBacaDokumen);
      if (!mounted) return;
      await muat();
      if (!mounted) return;
      pesan(d.arsip
          ? 'Dokumen "${d.nama}" dikembalikan ke daftar.'
          : 'Dokumen "${d.nama}" dipindahkan ke arsip.');
    } catch (_) {
      if (!mounted) return;
      pesan('Dokumen "${d.nama}" belum bisa diubah saat ini.');
    }
  }

  /// Hapus dokumen sesudah konfirmasi.
  Future<void> hapus(DokumenData d) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('konfirmasi_hapus'),
        title: const Text('Hapus dokumen?'),
        content: Text('Dokumen "${d.nama}" akan dihapus dari catatan. '
            'Berkas aslinya tidak tersentuh.'),
        actions: [
          TextButton(
            key: const Key('batal_hapus'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('hapus_hapus'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (setuju != true || !mounted) return;

    final repo = ref.read(repoDokumenProvider);
    try {
      await repo.hapus(d.id).timeout(batasBacaDokumen);
      if (!mounted) return;
      await muat();
      if (!mounted) return;
      pesan('Dokumen "${d.nama}" dihapus.');
    } catch (_) {
      if (!mounted) return;
      pesan('Dokumen "${d.nama}" belum bisa dihapus saat ini.');
    }
  }

  /// Dialog salin daftar: bentuk teks (untuk cetak) & JSON (untuk berkas).
  void dialogEkspor() {
    final daftar = semua ?? const <DokumenData>[];
    if (daftar.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => DialogEkspor(daftar: daftar),
    );
  }

  void pesan(String teks) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(teks)));
}

/// Nilai balik dialog perpanjang: pengguna menekan "Batal".
final DateTime batalPerpanjang = DateTime(1900);

/// Nilai balik dialog perpanjang: tanggal berakhir dibiarkan seperti semula.
final DateTime tanpaTanggalBaru = DateTime(1901);

/// Dialog "sudah diperpanjang": tanggal berakhir baru boleh dikosongkan.
///
/// Dibuat StatefulWidget supaya `TextEditingController` dimiliki & dibuang oleh
/// dialog itu sendiri (kalau pemanggil membuangnya tepat setelah `showDialog`,
/// animasi penutup dialog masih memakainya dan Flutter melaporkan
/// "used after being disposed").
class DialogPerpanjang extends StatefulWidget {
  const DialogPerpanjang({super.key, required this.dokumen});

  final DokumenData dokumen;

  @override
  State<DialogPerpanjang> createState() => _StateDialogPerpanjang();
}

class _StateDialogPerpanjang extends State<DialogPerpanjang> {
  late final TextEditingController kendali;
  String pesanGalat = '';

  @override
  void initState() {
    super.initState();
    final akhir = widget.dokumen.berlakuSampai;
    kendali = TextEditingController(
        text: akhir == null ? '' : teksTanggalIsian(akhir));
  }

  @override
  void dispose() {
    kendali.dispose();
    super.dispose();
  }

  void simpan() {
    final teks = kendali.text.trim();
    if (teks.isEmpty) {
      Navigator.of(context).pop(tanpaTanggalBaru);
      return;
    }
    final tanggal = parseTanggal(teks);
    if (tanggal == null) {
      setState(() =>
          pesanGalat = 'Tanggal belum terbaca. Contoh: 31/12/2027.');
      return;
    }
    Navigator.of(context).pop(tanggal);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Perpanjang "${widget.dokumen.nama}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Isi tanggal berakhir yang baru (boleh dikosongkan).'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('perpanjang_tanggal'),
            controller: kendali,
            decoration: const InputDecoration(
              labelText: 'Berlaku sampai',
              hintText: 'dd/mm/yyyy',
            ),
          ),
          if (pesanGalat.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(pesanGalat,
                  key: const Key('galat_perpanjang'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('batal_perpanjang'),
          onPressed: () => Navigator.of(context).pop(batalPerpanjang),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('simpan_perpanjang'),
          onPressed: simpan,
          child: const Text('Tandai'),
        ),
      ],
    );
  }
}

/// Dialog ekspor daftar dokumen (teks siap cetak / JSON).
class DialogEkspor extends StatefulWidget {
  const DialogEkspor({super.key, required this.daftar});

  final List<DokumenData> daftar;

  @override
  State<DialogEkspor> createState() => _StateDialogEkspor();
}

class _StateDialogEkspor extends State<DialogEkspor> {
  bool bentukJson = false;

  @override
  Widget build(BuildContext context) {
    final isi = bentukJson
        ? DokumenRepository.eksporJson(widget.daftar)
        : DokumenRepository.eksporTeks(widget.daftar);
    return AlertDialog(
      title: const Text('Daftar dokumen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: false, label: Text('Teks')),
                ButtonSegment<bool>(value: true, label: Text('JSON')),
              ],
              selected: <bool>{bentukJson},
              onSelectionChanged: (s) => setState(() => bentukJson = s.first),
            ),
            const SizedBox(height: 12),
            SelectableText(
              isi,
              key: const Key('teks_ekspor_dokumen'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('tutup_ekspor'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
