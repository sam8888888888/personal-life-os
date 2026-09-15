/// FR-28 — Layar "Beban tagihan": grafik sederhana beban tagihan per bulan
/// (total & per kategori).
///
/// Grafik digambar SENDIRI dengan [CustomPaint] — tidak ada paket grafik
/// tambahan. Batang = total beban tiap bulan, nominal ditulis dengan
/// `fmtUangDariSen`, nama bulan singkat di bawah batang. Warna netral dari
/// tema (tidak memakai merah: layar ini tidak menuduh siapa pun).
///
/// ATURAN III-11: layar ini melaporkan angka. Tidak ada kata menghakimi
/// ("boros", "gagal", "tidak disiplin", "skor"); bulan yang belum punya
/// tagihan ditulis apa adanya.
///
/// Angka dihitung oleh `BebanTagihan.hitung` di
/// `lib/core/laporan/beban_tagihan.dart` (inti murni Dart, sudah diuji
/// terpisah). Layar ini hanya menyiapkan data dari repositori & menggambar.
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/laporan/beban_tagihan.dart';
import '../../core/providers/app_providers.dart' hide kunciBulan;
import '../../core/utils/mata_uang.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';

/// Satu batang grafik: label sumbu, nominal terformat, nilai (sen), dan tanda
/// sedang dilihat. Bentuk murni supaya bisa diuji tanpa merender widget.
typedef BatangBeban = ({
  String kunci,
  String label,
  String nominal,
  int nilai,
  bool terpilih,
});

/// Daftar batang grafik dari hasil hitung inti. Nominal selalu lewat
/// `fmtUangDariSen` (tidak ada format rupiah buatan sendiri).
List<BatangBeban> daftarBatangBeban(BebanTagihan beban, String dipilih) =>
    <BatangBeban>[
      for (final b in beban.bulan)
        (
          kunci: b.kunci,
          label: b.labelSumbu,
          nominal: fmtUangDariSen(b.totalSen),
          nilai: b.totalSen,
          terpilih: b.kunci == dipilih,
        ),
    ];

/// Kartu grafik batang beban tagihan per bulan.
///
/// Bila jendela bulan belum punya tagihan sama sekali, kartu ini menulis
/// [BebanTagihan.pesanBelumAdaData] dan tidak menggambar batang kosong.
class GrafikBebanTagihan extends StatelessWidget {
  const GrafikBebanTagihan({
    super.key,
    required this.beban,
    required this.dipilih,
    this.tinggi = 180,
  });

  /// Hasil hitung beban (bulan urut paling lama -> paling baru).
  final BebanTagihan beban;

  /// Kunci bulan yang sedang dilihat (batangnya berwarna penuh).
  final String dipilih;

  /// Tinggi area gambar (tanpa judul kartu).
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final skema = tema.colorScheme;
    final batang = daftarBatangBeban(beban, dipilih);
    var tertinggi = 0;
    for (final b in beban.bulan) {
      if (b.totalSen > tertinggi) tertinggi = b.totalSen;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: skema.surface,
        border: Border.all(color: skema.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Grafik beban per bulan', style: tema.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            beban.adaData
                ? 'Tertinggi ${fmtUangDariSen(tertinggi)} — batang berwarna penuh '
                    'adalah bulan yang sedang Anda lihat.'
                : 'Belum ada angka untuk digambar.',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (!beban.adaData)
            Text(BebanTagihan.pesanBelumAdaData,
                key: const Key('grafik_kosong'),
                style: tema.textTheme.bodyMedium)
          else
            SizedBox(
              width: double.infinity,
              height: tinggi,
              child: CustomPaint(
                painter: _PelukisBeban(
                  batang: batang,
                  warnaBatang: skema.primary.withValues(alpha: 0.45),
                  warnaBatangTerpilih: skema.primary,
                  warnaGaris: skema.outlineVariant,
                  warnaTeks: skema.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pelukis batang beban. Dipisah sebagai kelas sendiri supaya uji widget bisa
/// memastikan pelukis ini benar-benar terpasang pada `CustomPaint`.
class _PelukisBeban extends CustomPainter {
  _PelukisBeban({
    required this.batang,
    required this.warnaBatang,
    required this.warnaBatangTerpilih,
    required this.warnaGaris,
    required this.warnaTeks,
  });

  final List<BatangBeban> batang;
  final Color warnaBatang;
  final Color warnaBatangTerpilih;
  final Color warnaGaris;
  final Color warnaTeks;

  /// Pita atas untuk label nominal, pita bawah untuk label bulan.
  static const double _pitaAtas = 16;
  static const double _pitaBawah = 16;

  @override
  void paint(Canvas canvas, Size size) {
    if (batang.isEmpty) return;
    final area = Rect.fromLTWH(
        0, _pitaAtas, size.width, size.height - _pitaAtas - _pitaBawah);
    if (area.height <= 4 || area.width <= 4) return;

    var maks = 0;
    for (final b in batang) {
      if (b.nilai > maks) maks = b.nilai;
    }

    final lebarSlot = area.width / batang.length;
    final lebarBatang = (lebarSlot * 0.5).clamp(6.0, 28.0);

    // Garis dasar (titik nol) tipis, warna netral dari tema.
    canvas.drawLine(
      Offset(0, area.bottom),
      Offset(size.width, area.bottom),
      Paint()
        ..color = warnaGaris
        ..strokeWidth = 1,
    );

    for (var i = 0; i < batang.length; i++) {
      final b = batang[i];
      final pusat = lebarSlot * i + lebarSlot / 2;
      final tinggiBatang =
          maks <= 0 ? 0.0 : (b.nilai / maks) * (area.height - 2);
      final atas = area.bottom - tinggiBatang;
      final kiri = pusat - lebarBatang / 2;
      final kanan = pusat + lebarBatang / 2;
      // Batang bernilai nol tetap digambar setipis 1 px supaya bulannya terlihat.
      final bawah = area.bottom - atas < 1 ? atas + 1 : area.bottom;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(kiri, atas, kanan, bawah),
          const Radius.circular(3),
        ),
        Paint()..color = b.terpilih ? warnaBatangTerpilih : warnaBatang,
      );

      // Label nominal di atas batang — hanya bila muat selebar slot, supaya
      // angka tidak saling menumpuk di layar sempit.
      final nominal = TextPainter(
        text: TextSpan(
          text: b.nominal,
          style: TextStyle(fontSize: 9.5, color: warnaTeks),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (nominal.width <= lebarSlot - 2) {
        final x = (pusat - nominal.width / 2).clamp(0.0, size.width - nominal.width);
        final y = (atas - nominal.height - 1).clamp(0.0, size.height - nominal.height);
        nominal.paint(canvas, Offset(x, y));
      }

      // Label bulan singkat di bawah batang.
      final label = TextPainter(
        text: TextSpan(
          text: b.label,
          style: TextStyle(fontSize: 10, color: warnaTeks),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final xLabel = (pusat - label.width / 2).clamp(0.0, size.width - label.width);
      label.paint(canvas, Offset(xLabel, area.bottom + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _PelukisBeban lama) =>
      !listEquals(lama.batang, batang) ||
      lama.warnaBatang != warnaBatang ||
      lama.warnaBatangTerpilih != warnaBatangTerpilih ||
      lama.warnaGaris != warnaGaris;
}

/// Layar "Beban tagihan" (FR-28).
class BebanTagihanScreen extends ConsumerStatefulWidget {
  const BebanTagihanScreen({super.key, this.jamSekarang, this.jumlahBulan = 6});

  /// Jam yang dianggap "sekarang" (bisa disuntik saat uji & tangkapan layar).
  final DateTime Function()? jamSekarang;

  /// Panjang jendela bulan; bawaan 6 bulan terakhir termasuk bulan berjalan.
  final int jumlahBulan;

  @override
  ConsumerState<BebanTagihanScreen> createState() => _BebanTagihanScreenState();
}

class _BebanTagihanScreenState extends ConsumerState<BebanTagihanScreen> {
  /// Bulan yang sedang dilihat (kunci `YYYY-MM`); null = bulan berjalan.
  String? _dipilih;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  /// Ubah baris tagihan dari database menjadi model inti, lalu hitung.
  ///
  /// Baris tanpa nominal (dokumen non-moneter) dilewati: bukan beban uang.
  BebanTagihan _hitung(List<TagihanData> tagihan, List<KategoriData> kategori) {
    final daftar = <TagihanBeban>[
      for (final t in tagihan)
        if (t.jumlahSen != null)
          TagihanBeban(
            id: t.id,
            nama: t.nama,
            nominalSen: t.jumlahSen!,
            jatuhTempo: t.jatuhTempo,
            kategoriId: t.kategoriId,
            status: t.lunas ? TagihanBeban.lunas : TagihanBeban.belumLunas,
            aktif: t.statusAktif,
          ),
    ];
    return BebanTagihan.hitung(
      tagihan: daftar,
      kategori: <KategoriBeban>[
        for (final k in kategori) KategoriBeban(id: k.id, nama: k.nama),
      ],
      acuan: _sekarang,
      jumlahBulan: widget.jumlahBulan,
    );
  }

  @override
  Widget build(BuildContext context) {
    final aTagihan = ref.watch(semuaTagihanProvider);
    // Kategori tidak menahan tampilan: bila belum tiba, tagihan sementara masuk
    // kelompok "Tanpa kategori" dan namanya terkoreksi sendiri saat data tiba.
    final aKategori = ref.watch(kategoriProvider);
    final kategori = aKategori.value ?? const <KategoriData>[];

    final Widget isi;
    if (aTagihan.hasError) {
      isi = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Data tagihan belum bisa dibaca di perangkat ini. '
              'Coba buka lagi sebentar lagi.'),
        ),
      );
    } else if (!aTagihan.hasValue) {
      isi = const Center(child: CircularProgressIndicator());
    } else {
      isi = _isi(context, aTagihan.value!, kategori);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Beban tagihan')),
      body: isi,
    );
  }

  Widget _isi(
      BuildContext context, List<TagihanData> tagihan, List<KategoriData> kategori) {
    final tema = Theme.of(context);
    final beban = _hitung(tagihan, kategori);

    // Bulan terpilih: pilihan pengguna, atau bulan berjalan (bulan terakhir).
    final pilihanSah = _dipilih != null && beban.bulanKe(_dipilih) != null;
    final dipilih = pilihanSah ? _dipilih! : beban.bulanTerbaru.kunci;
    final bulan = beban.bulanKe(dipilih)!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: <Widget>[
        // (1) Pemilih bulan — semua bulan jendela, siap dipilih.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final b in beban.bulan)
              ChoiceChip(
                key: Key('pilih_bulan_${b.kunci}'),
                label: Text(b.labelPendek),
                selected: b.kunci == dipilih,
                onSelected: (_) => setState(() => _dipilih = b.kunci),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // (2) Kartu total bulan terpilih.
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Beban bulan ${bulan.labelPanjang}',
                    key: const Key('judul_bulan'),
                    style: tema.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  fmtUangDariSen(bulan.totalSen),
                  key: const Key('total_bulan'),
                  style: tema.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                if (bulan.kosong)
                  const Text(BebanTagihan.pesanBulanKosong)
                else
                  Text(bulan.jumlahSudahDibayar > 0
                      ? '${bulan.jumlah} tagihan jatuh tempo bulan ini · '
                          '${bulan.jumlahSudahDibayar} sudah dibayar'
                      : '${bulan.jumlah} tagihan jatuh tempo bulan ini'),
                const SizedBox(height: 6),
                Text('Angka ini menghitung semua tagihan yang jatuh tempo '
                    'bulan ini, ${BebanTagihan.catatanTermasukDibayar} — '
                    'beban, bukan sisa utang.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // (3) Grafik batang (digambar sendiri, CustomPaint).
        GrafikBebanTagihan(
          key: const Key('grafik_beban'),
          beban: beban,
          dipilih: dipilih,
        ),
        const SizedBox(height: 12),

        // (4) Rincian per kategori bulan terpilih.
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text('Rincian kategori — ${bulan.labelPanjang}',
                    key: const Key('judul_kategori'),
                    style: tema.textTheme.titleSmall),
              ),
              if (bulan.kosong)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 18),
                  child: Text(BebanTagihan.pesanBulanKosong),
                )
              else
                for (final bagian in bulan.perKategori)
                  _barisKategori(tema, bagian),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text('Bagian persen dihitung dari total beban bulan ini.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // (5) Angka tiap bulan pada jendela (ketuk baris untuk berpindah bulan).
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text('Beban tiap bulan',
                    style: tema.textTheme.titleSmall),
              ),
              for (final b in beban.bulan) _barisTabel(tema, b, dipilih),
            ],
          ),
        ),
        const SizedBox(height: 12),

      ],
    );
  }

  /// Satu baris angka bulan; ketuk untuk melihat bulan itu di kartu atas.
  Widget _barisTabel(ThemeData tema, BulanBeban b, String dipilih) {
    final terpilih = b.kunci == dipilih;
    return InkWell(
      onTap: () => setState(() => _dipilih = b.kunci),
      child: Padding(
        key: Key('baris_bulan_${b.kunci}'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                b.labelPendek,
                style: terpilih
                    ? tema.textTheme.titleSmall
                    : tema.textTheme.bodyMedium,
              ),
            ),
            Text('${b.jumlah} tagihan', style: tema.textTheme.bodySmall),
            const SizedBox(width: 12),
            Text(
              fmtUangDariSen(b.totalSen),
              style: terpilih
                  ? tema.textTheme.titleSmall
                  : tema.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// Satu baris rincian kategori: nama, nominal, jumlah, bagian %.
  Widget _barisKategori(ThemeData tema, BagianKategori bagian) {
    return Padding(
      key: Key('kategori_${bagian.nama}'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(bagian.nama, style: tema.textTheme.titleSmall),
              ),
              Text(fmtUangDariSen(bagian.totalSen),
                  style: tema.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Expanded(
                child: Text('${bagian.jumlah} tagihan',
                    style: tema.textTheme.bodySmall),
              ),
              Text(bagian.bagianTeks, style: tema.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: bagian.bagian,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
