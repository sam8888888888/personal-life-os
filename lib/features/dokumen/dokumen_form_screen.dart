/// Form tambah / ubah dokumen (FR-128).
///
/// Satu layar penuh (bukan dialog) supaya semua kolom dokumen muat: nama,
/// jenis, nomor, pemilik, tanggal terbit, tanggal berakhir, nama berkas,
/// lead pengingat, kanal, catatan, dan saklar pengingat.
///
/// **Kejujuran berkas.** Kolom "Nama berkas" hanya mencatat NAMA berkas fisik
/// milik pengguna. Aplikasi tidak menyalin isinya dan belum ada enkripsi di
/// proyek ini — catatan itu ditulis di layar apa adanya.
///
/// Tanggal diisi dengan mengetik (`dd/mm/yyyy`, `yyyy-mm-dd`) atau lewat
/// pemilih tanggal. Jam "sekarang" selalu dari `waktuSekarang()`, dapat
/// dikunci saat pengujian lewat [jamSekarang].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/waktu.dart';
import '../../data/database/database.dart';
import '../../data/model/enums.dart';
import '../../data/repository/dokumen_repository.dart';
import 'dokumen_providers.dart';
import 'teks_dokumen.dart';

/// Label kanal pengingat yang dipakai form.
const Map<KanalPengingat, String> labelKanalPengingatDokumen =
    <KanalPengingat, String>{
  KanalPengingat.push: 'Notifikasi HP',
  KanalPengingat.whatsapp: 'WhatsApp',
  KanalPengingat.sms: 'SMS',
  KanalPengingat.telegram: 'Telegram',
};

class DokumenFormScreen extends ConsumerStatefulWidget {
  const DokumenFormScreen({super.key, this.dokumen, this.jamSekarang});

  /// Baris yang diubah; `null` = menambah dokumen baru.
  final DokumenData? dokumen;

  /// Sumber waktu opsional (untuk pengujian).
  final DateTime Function()? jamSekarang;

  @override
  ConsumerState<DokumenFormScreen> createState() => _DokumenFormScreenState();
}

class _DokumenFormScreenState extends ConsumerState<DokumenFormScreen> {
  final kendaliNama = TextEditingController();
  final kendaliNomor = TextEditingController();
  final kendaliPemilik = TextEditingController();
  final kendaliTerbit = TextEditingController();
  final kendaliBerlaku = TextEditingController();
  final kendaliBerkas = TextEditingController();
  final kendaliCatatan = TextEditingController();
  final kendaliLead = TextEditingController(text: leadDokumenBawaan);

  String jenis = 'lain';
  KanalPengingat kanal = KanalPengingat.push;
  bool aktif = true;
  bool menyimpan = false;
  String pesanGalat = '';

  bool get ubah => widget.dokumen != null;

  @override
  void initState() {
    super.initState();
    final d = widget.dokumen;
    if (d == null) return;
    kendaliNama.text = d.nama;
    kendaliNomor.text = d.nomor ?? '';
    kendaliPemilik.text = d.pemilik ?? '';
    kendaliTerbit.text = d.terbit == null ? '' : teksTanggalIsian(d.terbit!);
    kendaliBerlaku.text =
        d.berlakuSampai == null ? '' : teksTanggalIsian(d.berlakuSampai!);
    kendaliBerkas.text = d.berkasNama ?? '';
    kendaliCatatan.text = d.catatan ?? '';
    kendaliLead.text = d.leadHari;
    jenis = d.jenis;
    kanal = KanalPengingat.dariDb(d.kanalPengingat);
    aktif = d.aktif;
  }

  @override
  void dispose() {
    kendaliNama.dispose();
    kendaliNomor.dispose();
    kendaliPemilik.dispose();
    kendaliTerbit.dispose();
    kendaliBerlaku.dispose();
    kendaliBerkas.dispose();
    kendaliCatatan.dispose();
    kendaliLead.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(ubah ? 'Ubah dokumen' : 'Dokumen baru')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TextField(
            key: const Key('form_dokumen_nama'),
            controller: kendaliNama,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nama dokumen',
              hintText: 'Contoh: KTP',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('form_dokumen_jenis'),
            initialValue: jenis,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Jenis'),
            items: [
              for (final e in labelJenisDokumen.entries)
                DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => jenis = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('form_dokumen_nomor'),
            controller: kendaliNomor,
            decoration: const InputDecoration(
              labelText: 'Nomor dokumen (opsional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('form_dokumen_pemilik'),
            controller: kendaliPemilik,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Pemilik (opsional)',
              hintText: 'Contoh: nama anggota keluarga',
            ),
          ),
          const SizedBox(height: 12),
          _barisTanggal(
            kunci: 'form_dokumen_terbit',
            kunciTombol: 'pilih_terbit',
            label: 'Tanggal terbit (opsional)',
            kendali: kendaliTerbit,
          ),
          const SizedBox(height: 12),
          _barisTanggal(
            kunci: 'form_dokumen_berlaku',
            kunciTombol: 'pilih_berlaku',
            label: 'Berlaku sampai (opsional)',
            kendali: kendaliBerlaku,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('form_dokumen_lead'),
            controller: kendaliLead,
            decoration: const InputDecoration(
              labelText: 'Ingatkan berapa hari sebelum berakhir',
              helperText: 'Pisahkan dengan koma, contoh: $leadDokumenBawaan',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<KanalPengingat>(
            key: const Key('form_dokumen_kanal'),
            initialValue: kanal,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kanal pengingat'),
            items: [
              for (final e in labelKanalPengingatDokumen.entries)
                DropdownMenuItem<KanalPengingat>(
                    value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => kanal = v);
            },
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            key: const Key('form_dokumen_aktif'),
            value: aktif,
            contentPadding: EdgeInsets.zero,
            title: const Text('Pengingat masa berlaku'),
            subtitle: const Text('Matikan bila dokumen ini tidak perlu diingatkan.'),
            onChanged: (v) => setState(() => aktif = v),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('form_dokumen_berkas'),
            controller: kendaliBerkas,
            decoration: const InputDecoration(
              labelText: 'Nama berkas (opsional)',
              hintText: 'Contoh: ktp-2026.pdf',
            ),
          ),
          const SizedBox(height: 8),
          Card(
            key: const Key('catatan_berkas_form'),
            color: tema.colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(catatanBerkasJujur),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('form_dokumen_catatan'),
            controller: kendaliCatatan,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Contoh: disimpan di lemari berkas',
            ),
          ),
          if (pesanGalat.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                pesanGalat,
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          // Kedua tombol dibungkus Expanded: tema aplikasi memakai
          // `minimumSize: Size.fromHeight(48)` (lebar minimum tak hingga),
          // sehingga tombol isi butuh batas lebar yang pasti dari induknya.
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('batal_dokumen'),
                  onPressed:
                      menyimpan ? null : () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('simpan_dokumen'),
                  onPressed: menyimpan ? null : _simpan,
                  child: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barisTanggal({
    required String kunci,
    required String kunciTombol,
    required String label,
    required TextEditingController kendali,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: Key(kunci),
            controller: kendali,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'dd/mm/yyyy',
            ),
          ),
        ),
        IconButton(
          key: Key(kunciTombol),
          tooltip: 'Pilih tanggal',
          icon: const Icon(Icons.calendar_month),
          onPressed: () => _pilihTanggal(kendali),
        ),
      ],
    );
  }

  Future<void> _pilihTanggal(TextEditingController kendali) async {
    final awal = parseTanggal(kendali.text) ?? (widget.jamSekarang ?? waktuSekarang)();
    final hasil = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: DateTime(awal.year - 60),
      lastDate: DateTime(awal.year + 40),
    );
    if (hasil == null) return;
    kendali.text = teksTanggalIsian(hasil);
  }

  Future<void> _simpan() async {
    final nama = kendaliNama.text.trim();
    if (nama.isEmpty) {
      setState(() => pesanGalat = 'Nama dokumen belum diisi.');
      return;
    }
    final terbit = parseTanggal(kendaliTerbit.text);
    if (kendaliTerbit.text.trim().isNotEmpty && terbit == null) {
      setState(() => pesanGalat = 'Tanggal terbit belum terbaca. Contoh: 31/12/2026.');
      return;
    }
    final berlaku = parseTanggal(kendaliBerlaku.text);
    if (kendaliBerlaku.text.trim().isNotEmpty && berlaku == null) {
      setState(() => pesanGalat =
          'Tanggal berakhir belum terbaca. Contoh: 31/12/2026.');
      return;
    }

    setState(() {
      menyimpan = true;
      pesanGalat = '';
    });
    final repo = ref.read(repoDokumenProvider);
    try {
      await repo
          .simpan(
            id: widget.dokumen?.id,
            nama: nama,
            jenis: jenis,
            nomor: kendaliNomor.text,
            pemilik: kendaliPemilik.text,
            terbit: terbit,
            berlakuSampai: berlaku,
            berkasNama: kendaliBerkas.text,
            catatan: kendaliCatatan.text,
            leadHari: kendaliLead.text,
            kanalPengingat: kanal.nilaiDb,
            aktif: aktif,
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        menyimpan = false;
        pesanGalat = e is ArgumentError
            ? '${e.message}'
            : 'Dokumen "$nama" belum bisa disimpan saat ini.';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}


