/// FR-39 (+ dasar FR-59) — Layar Pemindai SMS/Notifikasi Bank.
///
/// Alur yang dipegang: izin dulu (bawaan mati) → pindai di perangkat →
/// usulan → pengguna yang memutuskan (catat pengeluaran / tandai lunas /
/// abaikan). Tidak ada yang otomatis dan tidak ada yang keluar dari HP.
library;

import 'package:drift/drift.dart' show DoNothing, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/parsing/pemindai_bank.dart';
import '../../core/platform/kanal_media.dart' show KanalGagal;
import '../../core/platform/kanal_sms.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/batch12_providers.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import '../../data/repository/pemindai_bank_repository.dart';
import '../../data/repository/tagihan_repository.dart';

class PemindaiBankScreen extends ConsumerStatefulWidget {
  const PemindaiBankScreen({super.key});

  @override
  ConsumerState<PemindaiBankScreen> createState() =>
      _PemindaiBankScreenState();
}

class _PemindaiBankScreenState extends ConsumerState<PemindaiBankScreen> {
  final _kanal = KanalSms();
  bool _izin = false;
  bool _siap = false;
  bool _sedangPindai = false;
  List<PemindaianBankData> _baris = const [];
  RingkasPindaiBank? _ringkas;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final repo = ref.read(repoPemindaiBankProvider);
    final izin = await repo.izinMenyala();
    final baris = await repo.daftar();
    final ringkas = await repo.ringkas();
    if (!mounted) return;
    setState(() {
      _izin = izin;
      _baris = baris;
      _ringkas = ringkas;
      _siap = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pemindai SMS Bank')),
      body: !_siap
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _izin,
                          title: const Text('Izinkan memindai SMS bank'),
                          subtitle: const Text(
                              'Bawaan mati. Bisa dimatikan kapan saja.'),
                          onChanged: _ubahIzin,
                        ),
                        const Text(catatanPemindaiBank,
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _izin && !_sedangPindai ? _pindai : null,
                  icon: _sedangPindai
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: const Text('Pindai 30 hari terakhir'),
                ),
                if (_pesan != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_pesan!,
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                if (_ringkas != null)
                  Card(
                    child: ListTile(
                      dense: true,
                      title: const Text('Hasil pindai terakhir'),
                      subtitle: Text(_ringkas!.dasar),
                    ),
                  ),
                for (final b in _baris) _kartu(context, b),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Future<void> _ubahIzin(bool menyala) async {
    final repo = ref.read(repoPemindaiBankProvider);
    if (menyala) {
      try {
        final tersedia = await _kanal.tersedia();
        if (!tersedia) {
          _kabar('Perangkat ini tidak menyediakan pembacaan SMS.');
          return;
        }
        final diberi = await _kanal.izinDiberikan() || await _kanal.mintaIzin();
        if (!diberi) {
          _kabar('Izin baca SMS belum diberikan, jadi pemindaian dimatikan.');
          await repo.setIzin(false);
          await _muat();
          return;
        }
      } catch (e) {
        _kabar(e is KanalGagal ? e.pesan : 'Izin gagal diminta: $e');
        return;
      }
    }
    await repo.setIzin(menyala);
    await _muat();
  }

  Future<void> _pindai() async {
    setState(() => _sedangPindai = true);
    try {
      final repo = ref.read(repoPemindaiBankProvider);
      final sejak = DateTime.now().subtract(const Duration(days: 30));
      final pesan = await _kanal.bacaSejak(sejak);
      final sudah = await repo.idSudahDiproses();
      final bank = saringPesanBank(
        [
          for (final p in pesan)
            PesanBank(
              sumber: p.pengirim,
              teks: p.isi,
              waktu: p.waktu,
              id: p.id,
            ),
        ],
        sejak: sejak,
        sudahDiproses: sudah,
      );
      final hasil = [for (final p in bank) pindaiPesanBank(p)];
      final tersimpan = await repo.simpanHasil(hasil);
      _kabar(hasil.isEmpty
          ? 'Tidak ada SMS bank baru dalam 30 hari terakhir.'
          : '${hasil.length} pesan diperiksa · $tersimpan usulan baru '
              'disimpan${ringkasPindaiBank(hasil).belumDikenali.isEmpty ? '' : ' · '
                  '${ringkasPindaiBank(hasil).belumDikenali.length} belum bisa '
                  'dikenali'}');
      await _muat();
    } on KanalGagal catch (e) {
      _kabar(e.pesan);
    } catch (e) {
      _kabar('Pemindaian gagal: $e');
    } finally {
      if (mounted) setState(() => _sedangPindai = false);
    }
  }

  void _kabar(String teks) {
    if (!mounted) return;
    setState(() => _pesan = teks);
  }

  Widget _kartu(BuildContext context, PemindaianBankData b) {
    final mesin = ref.read(repoPemindaiBankProvider).keMesin(b);
    final status = StatusPindai.dariKode(b.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${b.sumber} · ${b.waktuPesan.day}/${b.waktuPesan.month}/'
                '${b.waktuPesan.year}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(mesin.kalimat),
            if (b.nominalSen != null)
              Text('Nominal ${fmtRpDariSen(b.nominalSen!)}',
                  style: const TextStyle(fontSize: 12)),
            Text('Keyakinan ${b.keyakinan}% · $status',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                if (status == StatusPindai.baru) ...[
                  TextButton.icon(
                    onPressed: () => _catatPengeluaran(context, b, mesin),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Catat pengeluaran'),
                  ),
                  TextButton.icon(
                    onPressed: () => _cocokkanTagihan(context, b, mesin),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Cocokkan tagihan'),
                  ),
                  TextButton.icon(
                    onPressed: () => _abaikan(b),
                    icon: const Icon(Icons.block),
                    label: const Text('Abaikan'),
                  ),
                ] else
                  TextButton.icon(
                    onPressed: () => _hapus(b),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Buang dari daftar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _catatPengeluaran(
      BuildContext context, PemindaianBankData b, HasilPindaiBank mesin) async {
    final nominal = mesin.nominalSen;
    if (nominal == null || nominal <= 0) {
      _kabar('Pesan ini tidak menyebut nominal, jadi belum bisa dicatat.');
      return;
    }
    final db = ref.read(databaseProvider);
    final idTransaksi =
        'bank-${b.id}-${mesin.pesan.waktu.millisecondsSinceEpoch}';
    await db.into(db.transaksi).insert(
          TransaksiCompanion.insert(
            idTransaksi: idTransaksi,
            jenis: const Value('pengeluaran'),
            tanggal: DateTime(
                mesin.pesan.waktu.year,
                mesin.pesan.waktu.month,
                mesin.pesan.waktu.day),
            jumlahSen: nominal,
            catatan: Value(
                'Dari SMS ${mesin.pesan.sumber}: ${mesin.keterangan ?? '-'}'),
            sumber: const Value('pemindai_bank'),
          ),
          onConflict: DoNothing(),
        );
    await ref
        .read(repoPemindaiBankProvider)
        .tandai(b.id, StatusPindai.dicatat);
    _kabar('Pengeluaran dicatat dari pesan ${mesin.pesan.sumber}.');
    await _muat();
  }

  Future<void> _cocokkanTagihan(
      BuildContext context, PemindaianBankData b, HasilPindaiBank mesin) async {
    final repo = ref.read(repoPemindaiBankProvider);
    final kandidat = await repo.kandidatTagihan();
    final cocok = cocokkanDenganTagihan(mesin, kandidat);
    if (cocok == null) {
      _kabar('Tidak ada tagihan yang nominalnya sama dengan pesan ini. '
          'Lebih baik catat sebagai pengeluaran saja.');
      return;
    }
    final idTagihan = await repo.idTagihanDari(cocok);
    if (idTagihan == null) {
      _kabar('Tagihan "${cocok.nama}" sudah tidak aktif.');
      return;
    }
    if (!context.mounted) return;
    final setuju = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Tandai "${cocok.nama}" lunas?'),
        content: Text('Pesan ${mesin.pesan.sumber} bernilai '
            '${fmtRpDariSen(mesin.nominalSen ?? 0)} cocok dengan tagihan '
            '${fmtRpDariSen(cocok.jumlahSen)}. Tandai lunas sekarang?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Tandai lunas')),
        ],
      ),
    );
    if (setuju != true) return;
    await TagihanRepository(ref.read(databaseProvider))
        .tandaiLunas(idTagihan, tanggalBayar: mesin.pesan.waktu);
    await repo.tandai(b.id, StatusPindai.ditandaiLunas);
    _kabar('Tagihan "${cocok.nama}" ditandai lunas.');
    await _muat();
  }

  Future<void> _abaikan(PemindaianBankData b) async {
    await ref.read(repoPemindaiBankProvider).tandai(b.id, StatusPindai.diabaikan);
    await _muat();
  }

  Future<void> _hapus(PemindaianBankData b) async {
    await ref.read(repoPemindaiBankProvider).hapus(b.id);
    await _muat();
  }
}
