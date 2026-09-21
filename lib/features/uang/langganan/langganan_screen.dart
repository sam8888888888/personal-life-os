/// Layar Langganan berulang (FR-68) — daftar, filter status, dan aksi baris.
///
/// Kriteria terima PRD: "Daftar langganan punya filter aktif/pause; menandai
/// pause menghentikan pengingat tanpa menghapus riwayat."
///
/// Cara memenuhinya tanpa mesin pengingat baru: satu langganan boleh menaut satu
/// baris `Tagihan` (kolom `tagihanId`), dan pengingat tetap dijadwalkan dari
/// tabel Tagihan oleh `lib/core/notifikasi/**`. `LanggananRepository.pause()`
/// mematikan `Tagihan.statusAktif` pada tagihan tertaut, sehingga pengingat
/// berhenti, sementara baris langganan dan riwayat pembayaran tetap ada.
///
/// Nada bahasa mengikuti PRD III-11: menjelaskan apa yang terjadi, tanpa
/// menyalahkan pengguna.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/tanggal_utils.dart';
import '../../../core/utils/uang_utils.dart';
import '../../../core/audit/audit_log.dart';
import '../../../core/laporan/tagihan_berhenti.dart';
import '../../../core/utils/waktu.dart';
import '../../../data/database/database.dart';
import '../../../data/model/enums.dart';
import '../../../data/repository/langganan_repository.dart';
import 'analitik_langganan.dart';
import 'deteksi_langganan.dart';
import 'form_langganan_screen.dart';

/// Repositori langganan untuk layar ini.
///
/// Dibuat lokal (bukan di `lib/core/providers/app_providers.dart`) supaya berkas
/// bersama itu tidak perlu disentuh dari modul ini.
final repoLanggananProvider = Provider<LanggananRepository>(
    (ref) => LanggananRepository(ref.watch(databaseProvider)));

/// Seluruh baris langganan, termasuk yang sudah berhenti (riwayat tetap tampil).
final daftarLanggananProvider =
    StreamProvider.autoDispose<List<LanggananData>>(
        (ref) => ref.watch(repoLanggananProvider).watchSemua());

/// Nominal pembayaran terakhir per tagihan (sen) — bukti deteksi tarif naik
/// (FR-70). Dibaca sekali, bukan per baris.
final pembayaranTerakhirProvider = FutureProvider.autoDispose<Map<int, int>>(
    (ref) => ref.watch(repoLanggananProvider).pembayaranTerakhirPerTagihan());

/// Saringan status pada daftar langganan.
enum FilterLangganan { semua, aktif, pause, berhenti }

/// true bila baris [l] termasuk saringan [f].
bool cocokFilter(LanggananData l, FilterLangganan f) {
  final status = StatusLangganan.dariDb(l.status);
  return switch (f) {
    FilterLangganan.semua => true,
    FilterLangganan.aktif => status == StatusLangganan.aktif,
    FilterLangganan.pause => status == StatusLangganan.pause,
    FilterLangganan.berhenti => status == StatusLangganan.berhenti,
  };
}

/// Perkiraan biaya per bulan dari baris langganan yang **aktif** (sen).
///
/// Memakai normalisasi resmi `LanggananRepository.nominalBulananSen`, jadi
/// angkanya selalu sama dengan `LanggananRepository.totalBulananSen()`.
/// Baris pause/berhenti tidak dihitung karena tidak menagih selama itu.
int totalBulananAktifSen(Iterable<LanggananData> daftar) {
  var total = 0;
  for (final l in daftar) {
    if (StatusLangganan.dariDb(l.status) == StatusLangganan.aktif) {
      total += LanggananRepository.nominalBulananSen(l);
    }
  }
  return total;
}

/// Tanggal kejadian berikutnya (>= hari ini) menurut siklusnya.
///
/// null untuk langganan yang sudah berhenti (tidak ada lagi jadwal).
DateTime? tanggalBerikutnya(LanggananData l, DateTime sekarang) {
  if (StatusLangganan.dariDb(l.status) == StatusLangganan.berhenti) return null;
  final f = Frekuensi.dariDb(l.siklus);
  if (f == Frekuensi.sekali) return l.tanggalMulai;
  final batas = DateTime(sekarang.year, sekarang.month, sekarang.day);
  var t = l.tanggalMulai;
  var langkah = 0;
  while (t.isBefore(batas) && langkah < 600) {
    final b = periodeBerikutnya(t, f);
    if (!b.isAfter(t)) break; // pengaman: hentikan bila tidak maju
    t = b;
    langkah++;
  }
  return t;
}

/// Kalimat jujur untuk baris yang sedang pause (dipakai juga oleh uji).
String kalimatPause(LanggananData l) {
  final b = StringBuffer('Pause');
  if (l.pauseSejak != null) b.write(' sejak ${fmtTanggalId(l.pauseSejak!)}');
  if (l.pauseSampai != null) b.write(' sampai ${fmtTanggalId(l.pauseSampai!)}');
  b.write(': pengingat berhenti');
  if (l.pauseSampai != null) b.write(' sampai tanggal itu');
  b.write(', riwayat tetap ada.');
  return b.toString();
}

/// Hasil dialog pause; null berarti pengguna menutup dialog (batal).
/// FR-46: catatan pembayaran (id tagihan + tanggal) untuk mendeteksi tagihan
/// yang berhenti muncul. Dibuat lokal di modul ini, seperti provider lain di
/// berkas ini.
final riwayatBayarProvider = FutureProvider.autoDispose<
    List<({int tagihanId, DateTime tanggalBayar})>>((ref) async {
  final baris = await ref.watch(tagihanRepoProvider).riwayatDenganId();
  return [
    for (final b in baris)
      (tagihanId: b.tagihanId, tanggalBayar: b.tanggalBayar),
  ];
});

class PilihanPause {
  const PilihanPause(this.sampai);

  /// null = pause tanpa batas tanggal.
  final DateTime? sampai;
}

class LanggananScreen extends ConsumerStatefulWidget {
  const LanggananScreen({super.key, this.jamSekarang});

  /// Sumber waktu yang bisa disuntik uji (pola sama seperti layar lain).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<LanggananScreen> createState() => _LanggananScreenState();
}

class _LanggananScreenState extends ConsumerState<LanggananScreen> {
  FilterLangganan _filter = FilterLangganan.semua;

  DateTime get _sekarang => widget.jamSekarang?.call() ?? waktuSekarang();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(daftarLanggananProvider);
    final daftarTagihan =
        ref.watch(semuaTagihanProvider).value ?? const <TagihanData>[];
    final namaTagihan = <int, String>{
      for (final t in daftarTagihan) t.id: t.nama,
    };
    final nominalTagihan = <int, int>{
      for (final t in daftarTagihan)
        if (t.jumlahSen != null) t.id: t.jumlahSen!,
    };
    final pembayaranTerakhir =
        ref.watch(pembayaranTerakhirProvider).value ?? const <int, int>{};

    // FR-46: tagihan berulang yang catatan pembayarannya sudah berhenti.
    final riwayatBayar = ref.watch(riwayatBayarProvider).value ??
        const <({int tagihanId, DateTime tanggalBayar})>[];
    final berhenti = deteksiTagihanBerhenti(
      tagihan: daftarTagihan,
      riwayat: riwayatBayar,
      sekarang: _sekarang,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Langganan')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tambah_langganan'),
        onPressed: () => _bukaForm(),
        icon: const Icon(Icons.add),
        label: const Text('Langganan'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
            child: Text('Tidak bisa memuat daftar langganan saat ini.')),
        data: (semua) => _isi(
            semua, namaTagihan, nominalTagihan, pembayaranTerakhir, berhenti),
      ),
    );
  }

  Widget _isi(
    List<LanggananData> semua,
    Map<int, String> namaTagihan,
    Map<int, int> nominalTagihan,
    Map<int, int> pembayaranTerakhir,
    List<TagihanBerhenti> berhenti,
  ) {
    final terfilter = semua.where((l) => cocokFilter(l, _filter)).toList();
    final totalSen = totalBulananAktifSen(semua);
    final jmlAktif = semua
        .where((l) => StatusLangganan.dariDb(l.status) == StatusLangganan.aktif)
        .length;
    final jmlPause = semua
        .where((l) => StatusLangganan.dariDb(l.status) == StatusLangganan.pause)
        .length;

    // FR-69 & FR-70 — dihitung dari daftar yang sama, tanpa query baru.
    final ringkasan = hitungRingkasanLangganan(semua, _sekarang);
    final temuan = deteksiLangganan(
      daftar: semua,
      sekarang: _sekarang,
      pembayaranTerakhirSen: pembayaranTerakhir,
      nominalTagihanSen: nominalTagihan,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        _kartuTotal(totalSen, jmlAktif, jmlPause, semua.length),
        const SizedBox(height: 2),
        Text('Setara ${fmtRpDariSen(totalSen * 12)} per tahun',
            key: const Key('total_tahunan')),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SegmentedButton<FilterLangganan>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            segments: const [
              ButtonSegment(
                  value: FilterLangganan.semua,
                  label: Text('Semua', key: Key('filter_semua'))),
              ButtonSegment(
                  value: FilterLangganan.aktif,
                  label: Text('Aktif', key: Key('filter_aktif'))),
              ButtonSegment(
                  value: FilterLangganan.pause,
                  label: Text('Pause', key: Key('filter_pause'))),
              ButtonSegment(
                  value: FilterLangganan.berhenti,
                  label: Text('Berhenti', key: Key('filter_berhenti'))),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
        ),
        const SizedBox(height: 4),
        Text('${terfilter.length} dari ${semua.length} langganan tampil'),
        const SizedBox(height: 4),
        if (terfilter.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Belum ada langganan pada saringan ini. Tekan tombol "Langganan" '
              'di kanan bawah untuk menambah.',
              textAlign: TextAlign.center,
            ),
          )
        else
          ...terfilter.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _kartuBaris(l, namaTagihan, semua),
              )),
        // FR-69/FR-70 — wawasan diletakkan di bawah daftar supaya saringan
        // status dan baris langganan tetap dekat dengan bagian atas layar.
        const SizedBox(height: 12),
        KartuAnalitikLangganan(ringkasan: ringkasan),
        if (temuan.isNotEmpty) ...[
          const SizedBox(height: 12),
          PanelPerhatianLangganan(
            temuan: temuan,
            onTandaiDipakai: _tandaiDipakai,
            onSesuaikanNominal: _sesuaikanNominal,
          ),
        ],
        if (berhenti.isNotEmpty) ...[
          const SizedBox(height: 12),
          PanelTagihanBerhenti(
            daftar: berhenti,
            onMatikanPengingat: _matikanPengingat,
          ),
        ],
      ],
    );
  }

  Widget _kartuTotal(int totalSen, int jmlAktif, int jmlPause, int jmlSemua) {
    final tema = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total langganan per bulan', style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              fmtRpDariSen(totalSen),
              key: const Key('total_bulanan'),
              style: tema.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('$jmlAktif aktif · $jmlPause pause (tidak dihitung) · '
                '${jmlSemua - jmlAktif - jmlPause} berhenti'),
            const SizedBox(height: 4),
            Text(
              'Angka perkiraan: siklus mingguan dan tahunan dinormalkan ke bulan.',
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuBaris(
      LanggananData l, Map<int, String> namaTagihan, List<LanggananData> semua) {
    final tema = Theme.of(context);
    final status = StatusLangganan.dariDb(l.status);
    final siklus = Frekuensi.dariDb(l.siklus);
    final berikut = tanggalBerikutnya(l, _sekarang);
    final normalSen = LanggananRepository.nominalBulananSen(l);
    final tagihanId = l.tagihanId;

    return Card(
      key: Key('baris_langganan_${l.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(l.nama, style: tema.textTheme.titleMedium)),
                Container(
                  key: Key('lencana_${l.id}'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(status.label, style: tema.textTheme.labelSmall),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${fmtRpDariSen(l.nominalSen)} · ${labelSiklusLangganan(siklus)}'),
            if (normalSen != l.nominalSen)
              Text('Setara ${fmtRpDariSen(normalSen)} per bulan',
                  style: tema.textTheme.bodySmall),
            Text('Mulai ${fmtTanggalId(l.tanggalMulai)}'),
            Text(berikut == null
                ? 'Tidak ada jadwal lagi (sudah berhenti)'
                : 'Berikutnya ${fmtTanggalId(berikut)}'),
            Text(
              tagihanId == null
                  ? 'Belum tertaut tagihan — belum masuk pengingat'
                  : 'Tertaut tagihan: '
                      '${namaTagihan[tagihanId] ?? 'tagihan #$tagihanId'}',
            ),
            if (status == StatusLangganan.pause)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(kalimatPause(l),
                    key: Key('catatan_pause_${l.id}'),
                    style: tema.textTheme.bodySmall),
              ),
            if (!l.perpanjangOtomatis)
              Text('Perpanjangan otomatis: mati',
                  style: tema.textTheme.bodySmall),
            const SizedBox(height: 2),
            Wrap(
              spacing: 2,
              children: [
                if (status != StatusLangganan.aktif)
                  _tombol('Aktifkan', Icons.play_arrow_outlined,
                      Key('aksi_aktifkan_${l.id}'), () => _aktifkan(l)),
                if (status != StatusLangganan.pause)
                  _tombol('Pause', Icons.pause_circle_outline,
                      Key('aksi_pause_${l.id}'), () => _pause(l)),
                if (status != StatusLangganan.berhenti)
                  _tombol('Berhenti', Icons.stop_circle_outlined,
                      Key('aksi_berhenti_${l.id}'), () => _berhentikan(l)),
                if (tagihanId == null)
                  _tombol('Tautkan ke tagihan', Icons.link,
                      Key('aksi_tautkan_${l.id}'), () => _tautkan(l, semua))
                else
                  _tombol('Lepas tautan', Icons.link_off,
                      Key('aksi_lepas_${l.id}'), () => _lepasTautan(l)),
                _tombol('Ubah', Icons.edit_outlined, Key('aksi_ubah_${l.id}'),
                    () => _bukaForm(id: l.id)),
                _tombol('Hapus', Icons.delete_outline, Key('aksi_hapus_${l.id}'),
                    () => _hapusDenganKonfirmasi(l)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tombol(String label, IconData ikon, Key key, VoidCallback aksi) =>
      TextButton.icon(
        key: key,
        onPressed: aksi,
        icon: Icon(ikon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );

  // --------------------------------------------------------------------
  // Aksi
  // --------------------------------------------------------------------

  void _bukaForm({int? id}) {
    // Dibuka lewat Navigator (bukan go_router): `lib/app_router.dart` dipegang
    // pekerja lain, jadi modul ini tidak menambah rute di sana.
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FormLanggananScreen(id: id)));
  }

  /// FR-70 — tandai langganan masih dipakai hari ini.
  /// FR-138 — catatan aktivitas modul langganan.
  ///
  /// Satu helper supaya semua aksi langganan meninggalkan catatan dengan bentuk
  /// sama, dan penulisan catatan tidak pernah menggagalkan aksinya.
  Future<void> _audit(String aksi, LanggananData l, String ringkas) =>
      catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.langganan,
        aksi: aksi,
        entitas: 'langganan',
        entitasId: '${l.id}',
        ringkas: ringkas,
      );

  /// FR-46: matikan pengingat tagihan yang langganannya sudah berhenti.
  /// Tagihannya TIDAK dihapus — hanya tidak lagi diingatkan.
  Future<void> _matikanPengingat(int tagihanId) async {
    final jumlah = await ref.read(tagihanRepoProvider).nonaktifkan(tagihanId);
    if (!mounted) return;
    // Hitungan ulang setelah data berubah.
    ref.invalidate(riwayatBayarProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(jumlah > 0
          ? 'Pengingat dimatikan — datanya tetap tersimpan.'
          : 'Tagihan ini sudah tidak aktif.'),
    ));
  }

  Future<void> _tandaiDipakai(LanggananData l) async {
    await ref.read(repoLanggananProvider).tandaiDipakai(l.id);
    await _audit(AksiAudit.tandai, l,
        'Langganan "${l.nama}" ditandai masih dipakai.');
    if (!mounted) return;
    _pesan('"${l.nama}" ditandai masih dipakai hari ini.');
  }

  /// FR-70 — samakan nominal dengan bukti terbaru, setelah dikonfirmasi.
  Future<void> _sesuaikanNominal(LanggananData l, int acuanSen) async {
    final setuju = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sesuaikan nominal langganan?'),
        content: Text('"${l.nama}" diubah dari ${fmtRpDariSen(l.nominalSen)} '
            'menjadi ${fmtRpDariSen(acuanSen)} (angka bukti terakhir). '
            'Riwayat pembayaran tidak diubah.'),
        actions: [
          TextButton(
            key: const Key('sesuaikan_batal'),
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('sesuaikan_simpan'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Sesuaikan'),
          ),
        ],
      ),
    );
    if (setuju != true) return;
    await ref.read(repoLanggananProvider).ubah(l.id, nominalSen: acuanSen);
    await _audit(
        AksiAudit.ubah,
        l,
        'Nominal langganan "${l.nama}" disesuaikan dari '
        '${fmtRpDariSen(l.nominalSen)} menjadi ${fmtRpDariSen(acuanSen)}.');
    if (!mounted) return;
    _pesan('Nominal "${l.nama}" disesuaikan menjadi '
        '${fmtRpDariSen(acuanSen)}.');
  }

  Future<void> _pause(LanggananData l) async {
    final pilihan = await showDialog<PilihanPause>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('Pause "${l.nama}" sampai kapan?'),
        children: [
          _opsiPause(c, 'pause_1_minggu', 'Pause 1 minggu',
              _sekarang.add(const Duration(days: 7))),
          _opsiPause(c, 'pause_1_bulan', 'Pause 1 bulan',
              tambahBulan(_sekarang, 1)),
          _opsiPause(c, 'pause_3_bulan', 'Pause 3 bulan',
              tambahBulan(_sekarang, 3)),
          _opsiPause(c, 'pause_tanpa_batas', 'Tanpa batas tanggal', null),
          _opsiPausePilihTanggal(c),
        ],
      ),
    );
    if (pilihan == null) return;
    await ref.read(repoLanggananProvider).pause(l.id, sampai: pilihan.sampai);
    await _audit(AksiAudit.ubah, l,
        'Langganan "${l.nama}" dipause (pengingat berhenti, riwayat tetap).');
    if (!mounted) return;
    final sampai = pilihan.sampai;
    _pesan(sampai == null
        ? 'Pengingat langganan "${l.nama}" berhenti sampai diaktifkan lagi. '
            'Riwayat tetap tersimpan.'
        : 'Pengingat langganan "${l.nama}" berhenti sampai '
            '${fmtTanggalId(sampai)}. Riwayat tetap tersimpan.');
  }

  SimpleDialogOption _opsiPause(
          BuildContext c, String kunci, String label, DateTime? sampai) =>
      SimpleDialogOption(
        key: Key(kunci),
        onPressed: () => Navigator.of(c).pop(PilihanPause(sampai)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(sampai == null
              ? label
              : '$label (sampai ${fmtTanggalId(sampai)})'),
        ),
      );

  SimpleDialogOption _opsiPausePilihTanggal(BuildContext c) => SimpleDialogOption(
        key: const Key('pause_pilih_tanggal'),
        onPressed: () async {
          final pilih = await showDatePicker(
            context: c,
            initialDate: tambahBulan(_sekarang, 1),
            firstDate: _sekarang,
            lastDate: DateTime(_sekarang.year + 5, _sekarang.month, _sekarang.day),
            locale: const Locale('id', 'ID'),
          );
          if (pilih == null) return;
          if (c.mounted) Navigator.of(c).pop(PilihanPause(pilih));
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('Pilih tanggal sendiri'),
        ),
      );

  Future<void> _aktifkan(LanggananData l) async {
    await ref.read(repoLanggananProvider).aktifkan(l.id);
    await _audit(AksiAudit.ubah, l,
        'Langganan "${l.nama}" diaktifkan kembali (pengingat hidup).');
    if (!mounted) return;
    _pesan('Langganan "${l.nama}" aktif lagi. Pengingatnya hidup kembali.');
  }

  Future<void> _berhentikan(LanggananData l) async {
    final yakin = await _konfirmasi(
      judul: 'Tandai berhenti?',
      isi: '"${l.nama}" tidak lagi dihitung di total bulanan dan pengingatnya '
          'dimatikan. Baris langganan dan riwayat pembayaran tetap tersimpan.',
      labelYa: 'Berhenti',
    );
    if (yakin != true) return;
    await ref.read(repoLanggananProvider).hentikan(l.id);
    await _audit(AksiAudit.ubah, l,
        'Langganan "${l.nama}" ditandai berhenti (riwayat tetap tersimpan).');
    if (!mounted) return;
    _pesan('Langganan "${l.nama}" ditandai berhenti. Riwayat tetap tersimpan.');
  }

  Future<void> _lepasTautan(LanggananData l) async {
    await ref.read(repoLanggananProvider).lepasTautan(l.id);
    await _audit(AksiAudit.ubah, l, 'Tautan langganan "${l.nama}" dilepas.');
    if (!mounted) return;
    _pesan('Tautan "${l.nama}" dilepas. Tagihan itu kembali mengingatkan '
        'sampai dimatikan sendiri.');
  }

  Future<void> _tautkan(LanggananData l, List<LanggananData> semua) async {
    final semuaTagihan = await ref.read(tagihanRepoProvider).ambilSemua();
    if (!mounted) return;
    // Satu tagihan hanya untuk satu langganan (indeks unik di skema), jadi yang
    // sudah dipakai langganan lain tidak ditawarkan.
    final terpakai = {
      for (final x in semua)
        if (x.id != l.id && x.tagihanId != null) x.tagihanId!,
    };
    final pilihan = <TagihanData>[
      ...semuaTagihan.where((t) => !terpakai.contains(t.id)),
    ];
    if (pilihan.isEmpty) {
      _pesan('Belum ada tagihan yang bisa ditautkan. Tambah tagihan dulu di '
          'menu Tagihan.');
      return;
    }
    final idDipilih = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Tautkan ke tagihan mana?'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Pengingat langganan ini akan mengikuti tagihan yang dipilih, '
              'termasuk saat di-pause.',
              style: Theme.of(c).textTheme.bodySmall,
            ),
          ),
          ...pilihan.map((t) => SimpleDialogOption(
                key: Key('pilih_tagihan_${t.id}'),
                onPressed: () => Navigator.of(c).pop(t.id),
                child: Text('${t.nama} · '
                    '${fmtRpDariSen(t.jumlahSen ?? 0)}'),
              )),
        ],
      ),
    );
    if (idDipilih == null) return;
    try {
      await ref.read(repoLanggananProvider).tautkanKeTagihan(l.id, idDipilih);
      await _audit(AksiAudit.ubah, l,
          'Langganan "${l.nama}" ditautkan ke tagihan.');
      if (!mounted) return;
      _pesan('Langganan "${l.nama}" kini tertaut ke tagihan itu.');
    } catch (e) {
      if (!mounted) return;
      _pesan('Tidak bisa menautkan: $e');
    }
  }

  Future<void> _hapusDenganKonfirmasi(LanggananData l) async {
    final yakin = await _konfirmasi(
      judul: 'Hapus baris langganan?',
      isi: '"${l.nama}" akan hilang dari daftar ini. Riwayat pembayaran '
          'tagihannya tetap tersimpan. Untuk sekadar menghentikan pengingat, '
          'pilih "Berhenti" atau "Pause".',
      labelYa: 'Hapus',
    );
    if (yakin != true) return;
    // Aturan hapus (hidupkan tagihan tertaut, riwayat tetap) ada di repository,
    // bukan di layar — satu tempat untuk semua pemanggil.
    await ref.read(repoLanggananProvider).hapus(l.id);
    await _audit(AksiAudit.hapus, l, 'Baris langganan "${l.nama}" dihapus.');
    if (!mounted) return;
    _pesan('Baris langganan "${l.nama}" dihapus.');
  }

  Future<bool?> _konfirmasi({
    required String judul,
    required String isi,
    required String labelYa,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(judul),
          content: Text(isi),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.of(c).pop(true), child: Text(labelYa)),
          ],
        ),
      );

  void _pesan(String teks) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(teks)));
}
