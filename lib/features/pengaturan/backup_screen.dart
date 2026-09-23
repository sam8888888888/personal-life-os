/// Layar "Cadangan & Pemulihan" (FR-24).
///
/// Ekspor: satu berkas JSON berisi seluruh tabel (dibaca lewat `db.allTables`).
/// Impor: pratinjau dulu → konfirmasi tegas → cadangan pengaman otomatis →
/// tulis dalam satu transaksi → verifikasi baca-balik.
///
/// Pemilihan berkas memakai daftar berkas di folder dokumen aplikasi (TANPA
/// paket pemilih berkas sistem), jadi impor hanya menyentuh berkas yang dibuat
/// aplikasi ini sendiri.
///
/// Nada bahasa mengikuti PRD §III-11: menjelaskan keadaan apa adanya, tanpa
/// kata yang menghakimi pengguna.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_log.dart';
import '../../core/backup/cadangan_otomatis.dart';
import '../../core/backup/ekspor_impor.dart';
import '../../data/database/enkripsi_basisdata.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../ibadah/pengaturan_ibadah.dart';
import 'cadangan_otomatis_layanan.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({
    super.key,
    this.layanan,
    this.layananOtomatis,
    this.folderCadangan,
    this.jamSekarang,
  });

  /// Layanan cadangan; bisa diganti saat pengujian.
  final LayananCadangan? layanan;

  /// Layanan cadangan otomatis (FR-137); bisa diganti saat pengujian.
  final LayananCadanganOtomatis? layananOtomatis;

  /// Folder cadangan; bisa diganti saat pengujian.
  final PenentuFolderCadangan? folderCadangan;

  /// Sumber waktu yang bisa disuntik (uji & tangkapan layar).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  late final LayananCadangan _layanan;
  late final LayananCadanganOtomatis _otomatis;

  List<BerkasCadangan> _berkas = const <BerkasCadangan>[];
  bool _autoAktif = cadanganOtomatisAktifBawaan;
  int _autoJeda = jedaCadanganOtomatisBawaan;
  DateTime? _autoTerakhir;
  HasilPeriksaKeutuhan? _autoPeriksa;
  String? _pesanOtomatis;
  bool _memuat = true;
  bool _sibuk = false;
  String? _pesan;

  HasilEkspor? _hasilEkspor;
  PratinjauCadangan? _pratinjau;
  String? _pesanPratinjau;
  HasilImpor? _hasilImpor;

  /// Frasa sandi untuk cadangan terenkripsi.
  ///
  /// Di sisi ekspor sifatnya opsional (kosong = pakai kunci perangkat ini);
  /// di sisi impor dipakai untuk membuka berkas yang dibuat di HP lain.
  final TextEditingController _sandi = TextEditingController();
  String? _sandiImpor;

  @override
  void dispose() {
    _sandi.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _layanan = widget.layanan ??
        LayananCadangan(
          db: ref.read(databaseProvider),
          penentuFolder: widget.folderCadangan,
          jam: widget.jamSekarang,
        );
    _otomatis = widget.layananOtomatis ??
        LayananCadanganOtomatis(
          setelan: SetelanBasisData(ref.read(pengaturanRepoProvider)),
          cadangan: _layanan,
          jam: widget.jamSekarang,
        );
    _muatBerkas();
    _muatOtomatis();
  }

  /// Baca setelan cadangan otomatis + hasil pemeriksaan terakhir.
  Future<void> _muatOtomatis() async {
    try {
      final bool aktif =
          await _otomatis.aktif().timeout(const Duration(seconds: 5));
      final int jeda =
          await _otomatis.jedaHari().timeout(const Duration(seconds: 5));
      final DateTime? akhir =
          await _otomatis.terakhir().timeout(const Duration(seconds: 5));
      final HasilPeriksaKeutuhan? periksa =
          await _otomatis.periksaTersimpan().timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _autoAktif = aktif;
        _autoJeda = jeda;
        _autoTerakhir = akhir;
        _autoPeriksa = periksa;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _pesanOtomatis = 'Setelan cadangan otomatis belum bisa dibaca: $e');
    }
  }

  Future<void> _ubahAutoAktif(bool nilai) async {
    setState(() {
      _autoAktif = nilai;
      _pesanOtomatis = null;
    });
    await _otomatis.setAktif(nilai);
    await _muatOtomatis();
  }

  Future<void> _ubahAutoJeda(int hari) async {
    setState(() {
      _autoJeda = hari;
      _pesanOtomatis = null;
    });
    await _otomatis.setJedaHari(hari);
    await _muatOtomatis();
  }

  Future<void> _jalankanOtomatis() async {
    setState(() {
      _sibuk = true;
      _pesanOtomatis = null;
    });
    final HasilCadanganOtomatis hasil = await _otomatis.jalankan(paksa: true);
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      _pesanOtomatis = hasil.pesan;
    });
    await _muatBerkas();
    await _muatOtomatis();
  }

  Future<void> _periksaKeutuhan() async {
    setState(() {
      _sibuk = true;
      _pesanOtomatis = null;
    });
    final HasilPeriksaKeutuhan hasil = await _otomatis.periksaKeutuhan();
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      _autoPeriksa = hasil;
      _pesanOtomatis = hasil.pesan;
    });
  }

  Future<void> _muatBerkas() async {
    setState(() => _memuat = true);
    List<BerkasCadangan> daftar = const <BerkasCadangan>[];
    String? pesan;
    try {
      // Folder dokumen disediakan lapisan platform. Bila lapisan itu tidak
      // menjawab (mis. saat diuji tanpa plugin), layar tidak boleh berputar
      // selamanya: beri batas waktu lalu lanjut dengan daftar kosong.
      daftar = await _layanan
          .daftarBerkas()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      pesan = 'Folder dokumen aplikasi belum bisa dibaca: $e';
    }
    if (!mounted) return;
    setState(() {
      _berkas = daftar;
      _memuat = false;
      if (pesan != null) _pesan = pesan;
    });
  }

  Future<void> _eksporSekarang() async {
    setState(() {
      _sibuk = true;
      _pesan = null;
      _hasilImpor = null;
    });
    String? pesan;
    HasilEkspor? hasil;
    try {
      final String sandi = _sandi.text.trim();
      hasil = await _layanan.ekspor(sandi: sandi.isEmpty ? null : sandi);
    } on GalatCadangan catch (e) {
      pesan = e.pesan;
    } catch (e) {
      pesan = 'Cadangan belum bisa dibuat: $e';
    }
    // FR-138: catat aksi ekspor SETELAH berkas selesai ditulis, supaya isi
    // cadangan tidak ikut berubah karena baris catatan ini.
    if (hasil != null) {
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.pengaturan,
        aksi: AksiAudit.ekspor,
        entitas: 'cadangan',
        sesudah: hasil.namaBerkas,
        ringkas: 'Cadangan dibuat: ${hasil.namaBerkas} '
            '(${hasil.totalBaris} baris).',
      );
    }
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      _hasilEkspor = hasil ?? _hasilEkspor;
      _pesan = pesan;
    });
    await _muatBerkas();
  }

  Future<void> _pilihBerkas(BerkasCadangan berkas, {String? sandi}) async {
    setState(() {
      _sibuk = true;
      _pesan = null;
      _hasilImpor = null;
      _pesanPratinjau = null;
    });
    PratinjauCadangan? lihat;
    String? pesan;
    final String? sandiDipakai = sandi ?? _sandiImpor;
    try {
      lihat = await _layanan.pratinjau(berkas.path, sandi: sandiDipakai);
    } on GalatCadanganButuhSandi catch (e) {
      // Berkas terenkripsi (mis. dibuat di HP lain): minta frasa sandi.
      if (!mounted) return;
      setState(() => _sibuk = false);
      final String? frasa = await _mintaSandi(pesan: e.pesan);
      if (!mounted) return;
      if (frasa == null) {
        setState(() => _pesanPratinjau = e.pesan);
        return;
      }
      return _pilihBerkas(berkas, sandi: frasa);
    } on GalatCadanganSandiSalah catch (e) {
      if (!mounted) return;
      setState(() => _sibuk = false);
      final String? frasa = await _mintaSandi(pesan: e.pesan);
      if (!mounted) return;
      if (frasa == null) {
        setState(() => _pesanPratinjau = e.pesan);
        return;
      }
      return _pilihBerkas(berkas, sandi: frasa);
    } on GalatCadangan catch (e) {
      pesan = e.pesan;
    } catch (e) {
      pesan = 'Berkas cadangan belum bisa diperiksa: $e';
    }
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      _pratinjau = lihat;
      _pesanPratinjau = pesan;
      if (lihat != null) _sandiImpor = sandiDipakai;
    });
  }

  /// Tanya frasa sandi untuk berkas cadangan terenkripsi.
  ///
  /// Mengembalikan null bila pengguna membatalkan (atau mengosongkan kolom) —
  /// pemanggil wajib menjelaskan apa adanya, bukan menganggap berhasil.
  Future<String?> _mintaSandi({required String pesan}) async {
    final pengendali = TextEditingController();
    if (!mounted) return null;
    final hasil = await showDialog<String>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Berkas cadangan terenkripsi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pesan),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sandi_impor'),
              controller: pengendali,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Frasa sandi',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('batal_sandi'),
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('pakai_sandi'),
            onPressed: () => Navigator.of(c).pop(pengendali.text.trim()),
            child: const Text('Buka berkas'),
          ),
        ],
      ),
    );
    pengendali.dispose();
    if (hasil == null || hasil.isEmpty) return null;
    return hasil;
  }

  void _tutupPratinjau() {
    setState(() {
      _pratinjau = null;
      _pesanPratinjau = null;
    });
  }

  /// Konfirmasi tegas: pengguna harus menyetujui di kotak dialog.
  ///
  /// Pemulihan dimulai dari ketukan tombol "Ya", bukan dari hasil dialog,
  /// supaya pekerjaan berkas & database berjalan tanpa menunggu animasi
  /// penutup dialog.
  Future<void> _mintaKonfirmasi() async {
    final PratinjauCadangan? lihat = _pratinjau;
    if (lihat == null) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Pulihkan data dari berkas ini?'),
        content: Text(
            'Seluruh data di perangkat ini akan diganti dengan isi berkas '
            '${lihat.namaBerkas} (${lihat.totalBaris} baris). Data yang '
            'sekarang ada disalin otomatis menjadi berkas cadangan pengaman '
            'lebih dahulu, jadi masih bisa dibuka kembali.'),
        actions: [
          TextButton(
            key: const Key('batal_impor'),
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('konfirmasi_impor'),
            onPressed: () {
              Navigator.of(c).pop();
              unawaited(_terapkan(lihat));
            },
            child: const Text('Ya, pulihkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _terapkan(PratinjauCadangan lihat) async {
    setState(() {
      _sibuk = true;
      _pesan = null;
    });
    HasilImpor hasil;
    try {
      hasil = await _layanan.impor(lihat.path,
          sudahDikonfirmasi: true, sandi: _sandiImpor);
    } on GalatCadangan catch (e) {
      hasil = HasilImpor(berhasil: false, pesan: e.pesan);
    } catch (e) {
      hasil = HasilImpor(
          berhasil: false,
          pesan: 'Pemulihan belum bisa dijalankan: $e');
    }
    // FR-138: hanya aksi yang benar-benar berhasil yang dicatat, dan ditulis
    // SESUDAH verifikasi baca-balik selesai.
    if (hasil.berhasil) {
      await catatAuditAman(
        ref.read(databaseProvider),
        modul: ModulAudit.pengaturan,
        aksi: AksiAudit.pulihkan,
        entitas: 'cadangan',
        sesudah: lihat.namaBerkas,
        ringkas: 'Data dipulihkan dari berkas ${lihat.namaBerkas}.',
      );
    }
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      _hasilImpor = hasil;
      _pratinjau = null;
      _pesanPratinjau = null;
    });
    await _muatBerkas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadangan & Pemulihan')),
      body: _memuat
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                ..._bagianEkspor(),
                const Divider(height: 36),
                ..._bagianOtomatis(),
                const Divider(height: 36),
                ..._bagianImpor(),
                if (_sibuk) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Sedang bekerja… mohon tunggu sebentar.'),
                ],
                if (_pesan != null) ...[
                  const SizedBox(height: 16),
                  _kotakPesan(_pesan!, key: const Key('pesan_cadangan')),
                ],
              ],
            ),
    );
  }

  List<Widget> _bagianEkspor() {
    final tema = Theme.of(context);
    final HasilEkspor? hasil = _hasilEkspor;
    return [
      Text('Cadangan data', style: tema.textTheme.titleMedium),
      const SizedBox(height: 6),
      const Text('Cadangan berisi seluruh data aplikasi dalam satu berkas '
          'di folder dokumen: tagihan, riwayat pembayaran, transaksi, '
          'anggaran, langganan, aset, kewajiban, dan pengaturan. Berkas itu '
          'bisa Anda salin ke HP baru.'),
      const SizedBox(height: 12),
      TextField(
        key: const Key('sandi_cadangan'),
        controller: _sandi,
        obscureText: true,
        enabled: !_sibuk,
        decoration: const InputDecoration(
          labelText: 'Frasa sandi cadangan (opsional)',
          helperText: 'Paling sedikit 8 karakter. Isi bila berkas akan '
              'dibuka di HP lain.',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Cadangan selalu ditulis TERENKRIPSI. Tanpa frasa sandi, berkas hanya '
        'bisa dibuka di HP ini (kuncinya disimpan di keamanan perangkat). '
        'Isi frasa sandi kalau berkasnya mau dipindah ke HP lain.',
        key: Key('catatan_sandi_cadangan'),
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 6),
      const Text(
        'Cadangan otomatis Android (Google Drive) DIMATIKAN: data Anda tidak '
        'diunggah ke mana pun tanpa sepengetahuan Anda. Gunakan berkas cadangan '
        'dari layar ini bila ingin menyimpan salinan di luar HP.',
        key: Key('catatan_cadangan_android'),
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 6),
      // Keadaan basis data di perangkat ini, apa adanya — termasuk bila
      // enkripsinya TIDAK bisa dipasang (jangan pernah diklaim aman).
      Text(
        keadaanBasisDataSaatIni == KeadaanBasisData.terenkripsi
            ? 'Basis data di HP ini TERENKRIPSI (kunci disimpan di keamanan '
                'perangkat).'
            : 'Basis data di HP ini BELUM terenkripsi. '
                '${pesanBasisDataSaatIni ?? ''}',
        key: const Key('keadaan_basis_data'),
        style: const TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('ekspor_sekarang'),
        onPressed: _sibuk ? null : _eksporSekarang,
        icon: const Icon(Icons.save_alt),
        label: const Text('Buat cadangan sekarang'),
      ),
      if (hasil != null) ...[
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Berkas cadangan tersimpan',
                    key: const Key('hasil_ekspor'),
                    style: tema.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(hasil.namaBerkas, key: const Key('nama_berkas_cadangan')),
                Text('Dibuat ${fmtTanggalAman(hasil.dibuatPada)} '
                    'pukul ${fmtJam(hasil.dibuatPada)}'),
                Text('${hasil.totalBaris} baris pada '
                    '${hasil.jumlahBaris.length} tabel'),
                const SizedBox(height: 8),
                ...hasil.jumlahBaris.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('${e.key}: ${e.value} baris',
                          key: Key('jumlah_baris_${e.key}')),
                    )),
                const SizedBox(height: 4),
                const Text('Folder: dokumen aplikasi (lihat keterangan di '
                    'bawah).'),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  /// FR-137: setelan cadangan otomatis, status terakhir, dan pemeriksaan
  /// keutuhan berkas cadangan.
  List<Widget> _bagianOtomatis() {
    final tema = Theme.of(context);
    final DateTime sekarang = (widget.jamSekarang ?? waktuSekarang)();
    final DateTime? akhir = _autoTerakhir;
    final Duration? sisa = sisaWaktuCadangan(
      aktif: _autoAktif,
      terakhir: akhir,
      sekarang: sekarang,
      jedaHari: _autoJeda,
    );
    final HasilPeriksaKeutuhan? periksa = _autoPeriksa;
    return [
      Text('Cadangan otomatis', style: tema.textTheme.titleMedium),
      const SizedBox(height: 6),
      const Text(
          'Bila dinyalakan, aplikasi membuat cadangan sendiri setiap kali '
          'dibuka setelah jeda terlewat. Hanya tiga berkas cadangan otomatis '
          'terbaru yang disimpan; berkas yang lebih lama dihapus. Cadangan '
          'buatan Anda sendiri tidak pernah dihapus.'),
      const SizedBox(height: 4),
      const Text(
          'Catatan: cadangan otomatis berjalan saat aplikasi dibuka. Saat '
          'aplikasi tertutup, penjadwal sistem belum dipakai — jadi cadangan '
          'menunggu sampai aplikasi dibuka lagi.'),
      SwitchListTile(
        key: const Key('saklar_cadangan_otomatis'),
        contentPadding: EdgeInsets.zero,
        value: _autoAktif,
        onChanged: _sibuk ? null : (bool? v) => _ubahAutoAktif(v ?? false),
        title: const Text('Buat cadangan otomatis'),
        subtitle: Text(_autoAktif ? 'Menyala' : 'Mati'),
      ),
      Row(
        children: [
          const Text('Jeda'),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              key: const Key('jeda_cadangan_otomatis'),
              initialValue: _autoJeda,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final int h in pilihanJedaCadanganHari)
                  DropdownMenuItem<int>(value: h, child: Text('$h hari')),
              ],
              onChanged: _sibuk
                  ? null
                  : (int? v) => _ubahAutoJeda(v ?? jedaCadanganOtomatisBawaan),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        akhir == null
            ? 'Cadangan otomatis belum pernah dijalankan.'
            : 'Cadangan otomatis terakhir: ${fmtTanggalAman(akhir)} '
                '${fmtJam(akhir)}',
        key: const Key('status_cadangan_otomatis'),
        style: tema.textTheme.bodySmall,
      ),
      if (_autoAktif)
        Text(
          sisa == null
              ? 'Cadangan berikutnya: saat aplikasi dibuka.'
              : sisa == Duration.zero
                  ? 'Cadangan berikutnya: saat aplikasi dibuka.'
                  : 'Cadangan berikutnya: sekitar '
                      '${sisa.inDays > 0 ? '${sisa.inDays} hari ' : ''}'
                      '${sisa.inHours % 24} jam lagi.',
          key: const Key('sisa_cadangan_otomatis'),
          style: tema.textTheme.bodySmall,
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            key: const Key('jalankan_cadangan_otomatis'),
            onPressed: _sibuk ? null : _jalankanOtomatis,
            icon: const Icon(Icons.autorenew),
            label: const Text('Jalankan sekarang'),
          ),
          OutlinedButton.icon(
            key: const Key('periksa_keutuhan_cadangan'),
            onPressed: _sibuk ? null : _periksaKeutuhan,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Periksa keutuhan berkas'),
          ),
        ],
      ),
      if (periksa != null) ...[
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hasil pemeriksaan keutuhan',
                    style: tema.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  periksa.pesan,
                  key: const Key('hasil_periksa_keutuhan'),
                  style: tema.textTheme.bodySmall,
                ),
                if (periksa.waktu != null)
                  Text(
                    'Diperiksa ${fmtTanggalAman(periksa.waktu!)} '
                    '${fmtJam(periksa.waktu!)}'
                    '${periksa.namaBerkas == null ? '' : ' · ${periksa.namaBerkas}'}',
                    style: tema.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ],
      if (_pesanOtomatis != null) ...[
        const SizedBox(height: 12),
        _kotakPesan(_pesanOtomatis!,
            key: const Key('pesan_cadangan_otomatis')),
      ],
    ];
  }

  List<Widget> _bagianImpor() {
    final tema = Theme.of(context);
    return [
      Text('Pulihkan dari cadangan', style: tema.textTheme.titleMedium),
      const SizedBox(height: 6),
      const Text('Ketuk satu berkas untuk melihat isinya (tanggal, versi '
          'skema, dan jumlah baris per tabel) sebelum ada data yang diubah.'),
      const SizedBox(height: 8),
      if (_berkas.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Belum ada berkas cadangan di folder dokumen aplikasi. Tekan '
            '"Buat cadangan sekarang" untuk membuat berkas pertama Anda.',
            key: const Key('cadangan_kosong'),
            style: tema.textTheme.bodyMedium,
          ),
        )
      else
        ..._berkas.map((b) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                key: Key('impor_berkas_${b.nama}'),
                leading: const Icon(Icons.description_outlined),
                title: Text(b.nama),
                subtitle: Text('Diubah ${fmtTanggalAman(b.diubahPada)} pukul '
                    '${fmtJam(b.diubahPada)} · ${_ukuran(b.ukuranByte)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _sibuk ? null : () => _pilihBerkas(b),
              ),
            )),
      if (_pesanPratinjau != null) ...[
        const SizedBox(height: 8),
        _kotakPesan(_pesanPratinjau!, key: const Key('pesan_pratinjau')),
      ],
      if (_pratinjau != null) ...[
        const SizedBox(height: 8),
        _kartuPratinjau(_pratinjau!),
      ],
      if (_hasilImpor != null) ...[
        const SizedBox(height: 12),
        _kartuHasilImpor(_hasilImpor!),
      ],
    ];
  }

  Widget _kartuPratinjau(PratinjauCadangan lihat) {
    final tema = Theme.of(context);
    return Card(
      key: const Key('pratinjau_impor'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Isi berkas ini', style: tema.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('Nama berkas: ${lihat.namaBerkas}'),
            Text('Dibuat: ${lihat.dibuatPada == null ? 'tidak dicatat di berkas' : '${fmtTanggalAman(lihat.dibuatPada!)} pukul ${fmtJam(lihat.dibuatPada!)}'}'),
            Text('Versi skema: ${lihat.versiSkema} · versi aplikasi: '
                '${lihat.versiAplikasi ?? 'tidak dicatat'}'),
            Text('Jumlah baris: ${lihat.totalBaris} baris pada '
                '${lihat.jumlahBaris.length} tabel'),
            const SizedBox(height: 8),
            ...lihat.jumlahBaris.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('${e.key}: ${e.value} baris',
                      key: Key('pratinjau_baris_${e.key}')),
                )),
            for (final c in lihat.catatanMigrasi) _catatan(c),
            if (lihat.tabelTidakDikenal.isNotEmpty)
              _catatan('Tabel di berkas yang tidak dikenal aplikasi ini: '
                  '${lihat.tabelTidakDikenal.join(', ')} (diabaikan).'),
            if (lihat.tabelTanpaCadangan.isNotEmpty)
              _catatan('Tabel aplikasi yang tidak ada di berkas: '
                  '${lihat.tabelTanpaCadangan.join(', ')} — isinya menjadi '
                  'kosong setelah pemulihan.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('pulihkan_berkas'),
                  onPressed: _sibuk ? null : _mintaKonfirmasi,
                  icon: const Icon(Icons.restore),
                  label: const Text('Pulihkan…'),
                ),
                OutlinedButton(
                  key: const Key('tutup_pratinjau'),
                  onPressed: _sibuk ? null : _tutupPratinjau,
                  child: const Text('Belum sekarang'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuHasilImpor(HasilImpor hasil) {
    final tema = Theme.of(context);
    return Card(
      key: const Key('hasil_impor'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hasil.berhasil
                ? 'Pemulihan selesai'
                : 'Pemulihan tidak dijalankan', style: tema.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(hasil.pesan, key: const Key('pesan_hasil_impor')),
            if (hasil.pathCadanganPengaman != null)
              Text('Cadangan pengaman sebelum pemulihan: '
                  '${hasil.pathCadanganPengaman!.split(Platform.pathSeparator).last}'),
            if (hasil.berhasil) ...[
              const SizedBox(height: 8),
              ...hasil.jumlahBarisTerbaca.entries.map((e) => Text(
                    '${e.key}: ${e.value} baris (diperiksa ulang)',
                    key: Key('verifikasi_baris_${e.key}'),
                  )),
            ] else ...[
              const SizedBox(height: 4),
              const Text('Data di perangkat Anda tidak diubah.'),
            ],
            if (hasil.kolomDiabaikan.isNotEmpty)
              _catatan('Kolom yang diabaikan (tidak dikenal aplikasi ini): '
                  '${hasil.kolomDiabaikan.join(', ')}.'),
          ],
        ),
      ),
    );
  }

  Widget _catatan(String teks) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('Catatan: $teks',
            style: const TextStyle(fontStyle: FontStyle.italic)),
      );

  Widget _kotakPesan(String teks, {Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(teks),
      );

  static String _ukuran(int byte) {
    if (byte < 1024) return '$byte byte';
    if (byte < 1024 * 1024) return '${(byte / 1024).toStringAsFixed(1)} KB';
    return '${(byte / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
