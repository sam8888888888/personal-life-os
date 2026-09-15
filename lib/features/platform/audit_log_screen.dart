/// FR-138 — Layar Catatan Aktivitas (Audit Log).
///
/// Isi layar:
/// * catatan perubahan penting, terbaru lebih dulu, dengan saringan modul;
/// * jumlah baris yang benar-benar ditampilkan (bukti angka, bukan klaim);
/// * ekspor ke berkas JSON atau teks di folder dokumen aplikasi;
/// * pembersihan catatan lebih tua dari 365 hari — hanya bila Anda menekan
///   tombolnya dan menyetujui konfirmasi.
///
/// Kejujuran data (PRD §III-11): catatan ini **tersimpan di perangkat Anda
/// saja, tidak dikirim ke mana pun**. Catatan itu ditulis apa adanya di layar,
/// bukan hanya di dokumentasi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/repository/audit_repository.dart';

/// Repositori audit untuk layar ini.
final auditRepoProvider = Provider<AuditRepository>(
    (ref) => AuditRepository(ref.watch(databaseProvider)));

/// Teks catatan lokal — satu sumber, dipakai layar dan uji.
const String catatanLokalAudit =
    'Catatan ini tersimpan di perangkat Anda saja, tidak dikirim ke mana pun.';

/// Batas baris yang ditampilkan sekali buka (disebut apa adanya di layar).
const int batasTampilAudit = 200;

/// Data satu kali pemuatan layar.
class DataAudit {
  const DataAudit({
    required this.baris,
    required this.jumlahCocok,
    required this.modulTersedia,
  });

  final List<AuditLogData> baris;

  /// Jumlah baris yang cocok saringan (bisa lebih besar dari [baris]).
  final int jumlahCocok;

  /// Modul yang benar-benar ada di data.
  final List<String> modulTersedia;

  bool get kosong => baris.isEmpty;
}

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key, this.jamSekarang});

  /// Sumber waktu yang bisa disuntik uji (pola sama dengan layar lain).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  /// null = seluruh modul.
  String? _modul;
  late Future<DataAudit> _masaDepan;
  bool _sibuk = false;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  void initState() {
    super.initState();
    _masaDepan = _muat();
  }

  Future<DataAudit> _muat() async {
    final repo = ref.read(auditRepoProvider);
    final baris = await repo.daftar(modul: _modul, batas: batasTampilAudit);
    final jumlah = await repo.jumlah(modul: _modul);
    final modul = await repo.daftarModul();
    return DataAudit(
      baris: baris,
      jumlahCocok: jumlah,
      modulTersedia: modul,
    );
  }

  void _saring(String? modul) {
    setState(() {
      _modul = modul;
      _masaDepan = _muat();
    });
  }

  Future<void> _pesan(String teks) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _ekspor({required bool json}) async {
    if (_sibuk) return;
    setState(() => _sibuk = true);
    try {
      final repo = ref.read(auditRepoProvider);
      final hasil = json
          ? await repo.eksporJson(modul: _modul, pada: _sekarang)
          : await repo.eksporTeks(modul: _modul, pada: _sekarang);
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.pengaturan,
        aksi: AksiAudit.ekspor,
        entitas: 'audit_log',
        ringkas: 'Catatan aktivitas diekspor ke ${hasil.namaBerkas} '
            '(${hasil.jumlahBaris} baris)',
      );
      await _pesan('Berkas catatan dibuat: ${hasil.namaBerkas} · '
          '${hasil.jumlahBaris} baris'
          '${hasil.terpotong ? ' (dari ${hasil.totalBaris} baris cocok saringan)' : ''}');
    } catch (e) {
      await _pesan('Berkas catatan tidak bisa ditulis. Catatan di aplikasi '
          'tetap utuh. Penyebab: $e');
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  /// Pembersihan catatan lama — selalu lewat konfirmasi pengguna.
  Future<void> _bersihkan() async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Bersihkan catatan lama'),
        content: Text(
            'Catatan yang lebih tua dari $lamaSimpanAuditHari hari akan '
            'dihapus dari perangkat ini. Catatan yang lebih baru tetap ada. '
            'Lanjutkan?'),
        actions: [
          TextButton(
            key: const Key('batal_bersihkan'),
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('konfirmasi_bersihkan'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Bersihkan'),
          ),
        ],
      ),
    );
    if (setuju != true) return;
    try {
      final jumlah = await ref
          .read(auditRepoProvider)
          .bersihkan(simpanHari: lamaSimpanAuditHari, pada: _sekarang);
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.pengaturan,
        aksi: AksiAudit.bersihkan,
        entitas: 'audit_log',
        ringkas: 'Catatan lebih tua dari $lamaSimpanAuditHari hari dibersihkan '
            '($jumlah baris)',
      );
      await _pesan(jumlah == 0
          ? 'Tidak ada catatan yang lebih tua dari $lamaSimpanAuditHari hari.'
          : '$jumlah catatan lama dihapus dari perangkat ini.');
    } catch (e) {
      await _pesan('Pembersihan tidak bisa dijalankan sekarang. Penyebab: $e');
    }
    if (!mounted) return;
    setState(() {
      _masaDepan = _muat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Aktivitas'),
        actions: [
          IconButton(
            key: const Key('bersihkan_audit'),
            tooltip: 'Bersihkan catatan lebih tua dari $lamaSimpanAuditHari hari',
            onPressed: _bersihkan,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
      body: FutureBuilder<DataAudit>(
        future: _masaDepan,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Catatan tidak bisa dibaca saat ini. '
                  'Penyebab: ${snap.error}'),
            );
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _catatanLokal(tema),
              const SizedBox(height: 12),
              _ringkasan(data),
              const SizedBox(height: 12),
              _saringan(data),
              const SizedBox(height: 12),
              _tombolEkspor(),
              const SizedBox(height: 12),
              if (data.kosong)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Belum ada data catatan aktivitas. Catatan akan muncul '
                    'sendiri saat Anda mengubah angka penting, misalnya '
                    'menandai tagihan lunas.',
                  ),
                )
              else
                for (final b in data.baris) _kartuBaris(b),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _catatanLokal(ThemeData tema) => Card(
        key: const Key('catatan_lokal_audit'),
        color: tema.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.phonelink_lock_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(catatanLokalAudit)),
            ],
          ),
        ),
      );

  Widget _ringkasan(DataAudit data) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ringkasan',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Menampilkan ${data.baris.length} dari ${data.jumlahCocok} '
                  'catatan'
                  '${_modul == null ? ' (semua modul)' : ' (modul $_modul)'}.'),
              Text(
                data.jumlahCocok > data.baris.length
                    ? 'Sekali tampil dibatasi $batasTampilAudit baris terbaru; '
                        'sisanya tetap tersimpan.'
                    : 'Seluruh catatan yang cocok saringan ikut ditampilkan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );

  Widget _saringan(DataAudit data) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            key: const Key('saring_semua'),
            label: const Text('Semua modul'),
            selected: _modul == null,
            onSelected: (_) => _saring(null),
          ),
          for (final m in data.modulTersedia)
            FilterChip(
              key: Key('saring_$m'),
              label: Text(m),
              selected: _modul == m,
              onSelected: (_) => _saring(m),
            ),
        ],
      );

  Widget _tombolEkspor() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const Key('ekspor_json'),
            onPressed: _sibuk ? null : () => _ekspor(json: true),
            icon: const Icon(Icons.data_object),
            label: const Text('Ekspor JSON'),
          ),
          OutlinedButton.icon(
            key: const Key('ekspor_teks'),
            onPressed: _sibuk ? null : () => _ekspor(json: false),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Ekspor teks'),
          ),
        ],
      );

  Widget _kartuBaris(AuditLogData b) {
    final tema = Theme.of(context);
    final nilai = <String>[
      if (b.nilaiSebelum != null && b.nilaiSebelum!.isNotEmpty) b.nilaiSebelum!,
      if (b.nilaiSesudah != null && b.nilaiSesudah!.isNotEmpty) b.nilaiSesudah!,
    ];
    return Card(
      key: Key('baris_audit_${b.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.ringkas),
            const SizedBox(height: 4),
            Text(
              '${fmtTanggalAman(b.waktu)} ${fmtJam(b.waktu)} · ${b.modul} · '
              '${b.aksi} · sumber: ${b.sumber}',
              style: tema.textTheme.bodySmall,
            ),
            if (nilai.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Nilai: ${nilai.join(' \u2192 ')}',
                  style: tema.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
