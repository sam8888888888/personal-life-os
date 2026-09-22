/// FR-31 & FR-151 — widget layar utama (7 hari ke depan + total, bisa ditekan).
///
/// Pembagian tugas yang disengaja:
/// * **Dart** menyusun isi ringkasan (judul, total, tiga baris terdekat,
///   tombol aksi) — bagian ini bisa diuji tanpa HP.
/// * **Android (Kotlin)** hanya menampilkan kiriman itu di widget dan
///   meneruskan ketukan kembali ke aplikasi lewat `lifeos/rute`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/kanal_widget.dart';
import '../providers/app_providers.dart';
import '../utils/tanggal_utils.dart';
import '../utils/uang_utils.dart';
import '../utils/waktu.dart';

/// Saklar widget (bawaan: nyala).
const String kunciWidgetAktif = 'widget_aktif';

/// Jumlah hari yang ditampilkan widget.
const int hariWidget = 7;

/// Jumlah baris tagihan di widget (batas ruang widget).
const int maksBarisWidget = 3;

/// Baris minimum untuk menyusun widget — bisa diuji tanpa basis data.
typedef BarisWidget = ({
  int id,
  String nama,
  DateTime jatuhTempo,
  int? jumlahSen,
});

/// Isi widget yang dikirim ke Android.
class RingkasWidgetLayar {
  const RingkasWidgetLayar({
    required this.judul,
    required this.total,
    required this.catatan,
    required this.baris,
    required this.idBaris,
    this.aksiId,
  });

  final String judul;
  final String total;
  final String catatan;
  final List<String> baris;
  final List<String> idBaris;

  /// Id tagihan terdekat — dipakai tombol "Tandai lunas" di widget.
  final String? aksiId;

  bool get kosong => baris.isEmpty;
}

/// Susun isi widget dari daftar tagihan (murni, tanpa basis data).
RingkasWidgetLayar susunRingkasWidget(
  Iterable<BarisWidget> daftar,
  DateTime sekarang, {
  int hari = hariWidget,
  int maksBaris = maksBarisWidget,
}) {
  final batas = sekarang.add(Duration(days: hari));
  final mulaiHariIni =
      DateTime(sekarang.year, sekarang.month, sekarang.day);
  final mendatang = daftar
      .where((t) =>
          (t.jatuhTempo.isAfter(mulaiHariIni) ||
              t.jatuhTempo.isAtSameMomentAs(mulaiHariIni)) &&
          !t.jatuhTempo.isAfter(batas))
      .toList()
    ..sort((a, b) => a.jatuhTempo.compareTo(b.jatuhTempo));
  final tampil = mendatang.take(maksBaris).toList(growable: false);
  final totalSen = mendatang.fold<int>(
      0, (jumlah, t) => jumlah + (t.jumlahSen ?? 0));
  final hariIni = mendatang
      .where((t) =>
          t.jatuhTempo.year == sekarang.year &&
          t.jatuhTempo.month == sekarang.month &&
          t.jatuhTempo.day == sekarang.day)
      .length;

  final baris = <String>[
    for (final t in tampil)
      '${fmtTanggalPendekAman(t.jatuhTempo)} · ${t.nama}'
      '${t.jumlahSen == null ? '' : ' — ${fmtRpDariSen(t.jumlahSen!)}'}',
  ];

  return RingkasWidgetLayar(
    judul: hariIni > 0
        ? '$hariIni tagihan jatuh tempo hari ini'
        : '${mendatang.length} tagihan $hari hari ke depan',
    total: 'Total ${fmtRpDariSen(totalSen)}',
    catatan: 'Diperbarui ${fmtTanggalPendekAman(sekarang)} ${fmtJam(sekarang)}',
    baris: baris,
    idBaris: [for (final t in tampil) t.id.toString()],
    aksiId: tampil.isEmpty ? null : tampil.first.id.toString(),
  );
}

/// Saklar widget dari pengaturan perangkat.
final widgetAktifProvider = FutureProvider<bool>((ref) => ref
    .watch(pengaturanRepoProvider)
    .bacaSaklar(kunciWidgetAktif, bawaan: true));

/// Susun & kirim isi widget ke Android.
///
/// Dipisah dari widget supaya bisa diuji tanpa HP (dipakai [PemantauWidget]
/// untuk kerja sesungguhnya).
Future<RingkasWidgetLayar> kirimWidgetRingkas({
  required Future<List<BarisWidget>> Function() baca,
  required KanalWidget kanal,
  required bool nyala,
  DateTime? sekarang,
}) async {
  final ringkas = nyala
      ? susunRingkasWidget(await baca(), sekarang ?? waktuSekarang())
      : const RingkasWidgetLayar(
          judul: 'Widget dimatikan',
          total: '',
          catatan: 'Nyalakan di Pengaturan → Ikon & widget.',
          baris: [],
          idBaris: [],
        );
  await kanal.perbarui(
    judul: ringkas.judul,
    total: ringkas.total,
    catatan: ringkas.catatan,
    baris: ringkas.baris,
    idBaris: ringkas.idBaris,
    aksiId: ringkas.aksiId,
  );
  return ringkas;
}

/// Mengirim isi widget ke Android setiap data tagihan berubah.
class PemantauWidget extends ConsumerStatefulWidget {
  const PemantauWidget({super.key, required this.child, this.kanal});

  final Widget child;

  /// Kanal uji boleh disuntikkan; bawaan = kanal Android sungguhan.
  final KanalWidget? kanal;

  @override
  ConsumerState<PemantauWidget> createState() => _PemantauWidgetState();
}

class _PemantauWidgetState extends ConsumerState<PemantauWidget> {
  @override
  void initState() {
    super.initState();
    unawaited(perbarui());
  }

  /// Hitung & kirim isi widget. Aman dipanggil berkali-kali.
  Future<void> perbarui() async {
    try {
      final nyala = ref.read(widgetAktifProvider).value ?? true;
      await kirimWidgetRingkas(
        baca: _baca,
        kanal: widget.kanal ?? const KanalWidget(),
        nyala: nyala,
      );
    } catch (e) {
      debugPrint('widget layar utama gagal diperbarui: $e');
    }
  }

  Future<List<BarisWidget>> _baca() async {
    final semua = await ref.read(tagihanRepoProvider).ambilSemua();
    return [
      for (final t in semua)
        if (t.statusAktif && !t.lunas)
          (
            id: t.id,
            nama: t.nama,
            jatuhTempo: t.jatuhTempo,
            jumlahSen: t.jumlahSen,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tagihanAktifProvider, (_, _) => unawaited(perbarui()));
    ref.listen(widgetAktifProvider, (_, _) => unawaited(perbarui()));
    return widget.child;
  }
}
