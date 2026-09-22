/// FR-22 — Lencana angka di ikon peluncur.
///
/// Angka = jumlah tagihan yang **jatuh tempo hari ini atau sudah lewat** dan
/// belum lunas. Dihitung dari data di perangkat; tidak ada yang dikirim ke
/// mana pun.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/kanal_lencana.dart';
import '../providers/app_providers.dart';
import '../utils/waktu.dart';

/// Saklar lencana (bawaan: nyala).
const String kunciLencanaAktif = 'lencana_aktif';

/// Baris minimum yang dibutuhkan untuk menghitung lencana — sengaja bukan
/// kelas Drift supaya bisa diuji tanpa basis data.
typedef BarisLencana = ({DateTime jatuhTempo, bool lunas, bool statusAktif});

/// Hitung angka lencana untuk [sekarang] (hari ini atau sudah lewat).
int jumlahLencana(Iterable<BarisLencana> daftar, DateTime sekarang) {
  final mulaiBesok = DateTime(sekarang.year, sekarang.month, sekarang.day)
      .add(const Duration(days: 1));
  return daftar
      .where((t) =>
          t.statusAktif && !t.lunas && t.jatuhTempo.isBefore(mulaiBesok))
      .length;
}

/// Saklar lencana dari pengaturan perangkat.
final lencanaAktifProvider = FutureProvider<bool>(
    (ref) => ref.watch(pengaturanRepoProvider).bacaSaklar(kunciLencanaAktif,
        bawaan: true));

/// Hitung & kirim angka lencana ke peluncur.
///
/// Dipisah dari widget supaya bisa diuji tanpa HP dan tanpa menunggu tampilan
/// (dan dipakai [PemantauLencana] untuk kerja sesungguhnya).
Future<int> kirimLencana({
  required Future<List<BarisLencana>> Function() baca,
  required LencanaIkon kanal,
  required bool nyala,
  DateTime? sekarang,
}) async {
  final baris = await baca();
  final jumlah = nyala ? jumlahLencana(baris, sekarang ?? waktuSekarang()) : 0;
  await kanal.pasang(jumlah);
  return jumlah;
}

/// Memasang lencana ikon setiap data tagihan berubah.
class PemantauLencana extends ConsumerStatefulWidget {
  const PemantauLencana({super.key, required this.child, this.layanan});

  final Widget child;

  /// Kanal uji boleh disuntikkan; bawaan = kanal Android sungguhan.
  final LencanaIkon? layanan;

  @override
  ConsumerState<PemantauLencana> createState() => _PemantauLencanaState();
}

class _PemantauLencanaState extends ConsumerState<PemantauLencana> {
  @override
  void initState() {
    super.initState();
    unawaited(perbarui());
  }

  /// Hitung & pasang lencana. Aman dipanggil berkali-kali.
  Future<void> perbarui() async {
    try {
      final nyala = ref.read(lencanaAktifProvider).value ?? true;
      await kirimLencana(
        baca: _baca,
        kanal: widget.layanan ?? const LencanaIkon(),
        nyala: nyala,
      );
    } catch (e) {
      debugPrint('lencana ikon gagal diperbarui: $e');
    }
  }

  Future<List<BarisLencana>> _baca() async {
    final repo = ref.read(tagihanRepoProvider);
    return (await repo.ambilSemua())
        .map((t) => (
              jatuhTempo: t.jatuhTempo,
              lunas: t.lunas,
              statusAktif: t.statusAktif,
            ))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tagihanAktifProvider, (_, _) => unawaited(perbarui()));
    ref.listen(lencanaAktifProvider, (_, _) => unawaited(perbarui()));
    return widget.child;
  }
}
