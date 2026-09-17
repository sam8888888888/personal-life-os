/// Form tambah/ubah tagihan — UC-1: tambah tagihan < 30 detik.
library;

import '../../core/utils/waktu.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audit/audit_log.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/tanggal_utils.dart';
import '../../core/utils/uang_utils.dart';
import '../../data/database/database.dart';
import '../../data/model/enums.dart';
import '../../data/repository/template_tagihan.dart';
import 'ikon_warna_kategori.dart';
import 'kelola_kategori_tagihan_screen.dart';

class FormTagihanScreen extends ConsumerStatefulWidget {
  const FormTagihanScreen({super.key, this.id});

  /// null = tambah baru, bukan null = ubah.
  final int? id;

  @override
  ConsumerState<FormTagihanScreen> createState() => _FormTagihanScreenState();
}

class _FormTagihanScreenState extends ConsumerState<FormTagihanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _jumlah = TextEditingController();
  final _catatan = TextEditingController();
  final _tautan = TextEditingController();

  DateTime _jatuhTempo = waktuSekarang();
  Frekuensi _frekuensi = Frekuensi.bulanan;
  // FR-10: default cerdas H-3, H-1, dan hari-H.
  Set<int> _lead = {3, 1, 0};
  TimeOfDay _jam = const TimeOfDay(hour: 9, minute: 0);
  PrioritasTagihan _prioritas = PrioritasTagihan.biasa;
  int? _kategoriId;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _muatData();
  }

  Future<void> _muatData() async {
    final db = ref.read(databaseProvider);
    final t = await (db.select(db.tagihan)..where((x) => x.id.equals(widget.id!)))
        .getSingleOrNull();
    if (t == null) return;
    // PB-14: jangan menyentuh state kalau layar sudah ditutup.
    if (!mounted) return;
    setState(() {
      _nama.text = t.nama;
      _jumlah.text = t.jumlahSen == null ? '' : (t.jumlahSen! / 100).round().toString();
      _catatan.text = t.catatan ?? '';
      _tautan.text = t.tautanBayar ?? '';
      _jatuhTempo = t.jatuhTempo;
      _frekuensi = Frekuensi.dariDb(t.frekuensi);
      _lead = teksKeLead(t.pengingatLeadHari).toSet();
      final bagian = t.pengingatJam.split(':');
      _jam = TimeOfDay(
          hour: int.tryParse(bagian.first) ?? 9,
          minute: bagian.length > 1 ? (int.tryParse(bagian[1]) ?? 0) : 0);
      _prioritas = PrioritasTagihan.dariDb(t.prioritas);
      _kategoriId = t.kategoriId;
    });
  }

  /// Kategori yang masih ada di daftar. Kategori yang sudah dihapus (atau
  /// daftar yang belum termuat) diperlakukan sebagai "Tanpa kategori".
  int? _kategoriIdTerpakai(List<KategoriData> kategori) {
    if (_kategoriId == null) return null;
    return kategori.any((k) => k.id == _kategoriId) ? _kategoriId : null;
  }

  /// Pintu ke layar "Kategori tagihan" (FR-08). Daftar kategori di form ini
  /// ikut segar sesudahnya karena `kategoriProvider` adalah stream.
  Future<void> _bukaKelolaKategori() async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => const KelolaKategoriTagihanScreen(),
    ));
  }

  @override
  void dispose() {
    _nama.dispose();
    _jumlah.dispose();
    _catatan.dispose();
    _tautan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kategori = ref.watch(kategoriProvider).value ?? const <KategoriData>[];
    // FR-08: nilai dropdown HARUS ada di dalam daftar item, kalau tidak Flutter
    // melempar galat. Kategori yang belum termuat atau sudah dihapus di layar
    // "Kategori tagihan" diperlakukan sebagai "Tanpa kategori".
    final nilaiKategori = _kategoriIdTerpakai(kategori);
    return Form(
      key: _formKey,
      // SingleChildScrollView + Column (bukan ListView): semua kolom tetap
      // hidup, jadi validasi form tidak terlewat walau kolom tergulir keluar
      // layar. Penting agar tagihan bernama kosong tidak bisa tersimpan.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          const Text('Cepat mengisi dari template:',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: daftarTemplate
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(t.nama),
                          avatar: const Icon(Icons.auto_awesome, size: 16),
                          onPressed: () => setState(() {
                            _nama.text = t.nama;
                            _jumlah.text = (t.perkiraanSen / 100).round().toString();
                            _frekuensi = t.frekuensi;
                            _lead = t.leadHari.toSet();
                            _catatan.text = t.catatan ?? '';
                          }),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nama,
            decoration: const InputDecoration(
                labelText: 'Nama tagihan *', hintText: 'Contoh: Listrik PLN'),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama tagihan wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _jumlah,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Jumlah (Rp) *', hintText: '150000 atau 150rb'),
            validator: (v) {
              final n = parseRupiah(v);
              if (n == null || n <= 0) return 'Jumlah tidak valid';
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Ikon & warna kategori ikut terlihat (FR-08).
          KeyedSubtree(
            key: const Key('dropdown_kategori'),
            child: DropdownButtonFormField<int?>(
              // Kunci ikut nilai: saat data kategori berubah, kolom ini dibuat
              // ulang dengan nilai yang sah (tidak tertinggal di kategori yang
              // sudah tidak ada).
              key: ValueKey('pilih_kategori_$nilaiKategori'),
              initialValue: nilaiKategori,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                const DropdownMenuItem(
                    value: null,
                    child: Row(children: [
                      Icon(Icons.label_off_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Tanpa kategori'),
                    ])),
                ...kategori.map((k) => DropdownMenuItem(
                      value: k.id,
                      child: Row(children: [
                        Icon(ikonTagihan(k.ikon),
                            size: 18, color: warnaTagihan(k.warna)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(k.nama,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    )),
              ],
              onChanged: (v) => setState(() => _kategoriId = v),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('buka_kelola_kategori'),
              onPressed: _bukaKelolaKategori,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Kelola kategori'),
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: _pilihTanggal,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Jatuh tempo *'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmtTanggalId(_jatuhTempo)),
                  const Icon(Icons.calendar_month),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Frekuensi>(
            initialValue: _frekuensi,
            decoration: const InputDecoration(labelText: 'Pengulangan'),
            items: Frekuensi.values
                .map((f) => DropdownMenuItem(value: f, child: Text(_labelFrekuensi(f))))
                .toList(),
            onChanged: (v) => setState(() => _frekuensi = v ?? Frekuensi.bulanan),
          ),
          const SizedBox(height: 16),
          const Text('Pengingat (hari sebelum jatuh tempo)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [60, 30, 14, 7, 3, 1, 0]
                .map((d) => FilterChip(
                      label: Text(d == 0 ? 'Hari-H' : 'H-$d'),
                      selected: _lead.contains(d),
                      onSelected: (pilih) => setState(() {
                        if (pilih) {
                          _lead.add(d);
                        } else {
                          _lead.remove(d);
                        }
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pilihJam,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Jam pengingat'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_jam.hour.toString().padLeft(2, '0')}:'
                      '${_jam.minute.toString().padLeft(2, '0')}'),
                  const Icon(Icons.alarm),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PrioritasTagihan>(
            initialValue: _prioritas,
            decoration: const InputDecoration(labelText: 'Prioritas'),
            items: PrioritasTagihan.values
                .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name[0].toUpperCase() + p.name.substring(1))))
                .toList(),
            onChanged: (v) =>
                setState(() => _prioritas = v ?? PrioritasTagihan.biasa),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _catatan,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tautan,
            decoration: const InputDecoration(
                labelText: 'Tautan pembayaran (opsional)',
                hintText: 'https://...'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _simpan,
            icon: const Icon(Icons.save),
            label: Text(widget.id == null ? 'Simpan tagihan' : 'Simpan perubahan'),
          ),
          if (widget.id != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _hapus,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus tagihan ini'),
            ),
          ],
          ],
        ),
      ),
    );
  }

  String _labelFrekuensi(Frekuensi f) {
    switch (f) {
      case Frekuensi.sekali:
        return 'Sekali saja';
      case Frekuensi.mingguan:
        return 'Setiap minggu';
      case Frekuensi.duaMingguan:
        return 'Setiap 2 minggu';
      case Frekuensi.bulanan:
        return 'Setiap bulan';
      case Frekuensi.duaBulanan:
        return 'Setiap 2 bulan';
      case Frekuensi.kuartalan:
        return 'Setiap 3 bulan';
      case Frekuensi.semesteran:
        return 'Setiap 6 bulan';
      case Frekuensi.tahunan:
        return 'Setiap tahun';
      case Frekuensi.kustomHari:
        return 'Kustom (hari)';
    }
  }

  Future<void> _pilihTanggal() async {
    final pilih = await showDatePicker(
      context: context,
      initialDate: _jatuhTempo,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
    );
    if (pilih != null) setState(() => _jatuhTempo = pilih);
  }

  Future<void> _pilihJam() async {
    final pilih = await showTimePicker(context: context, initialTime: _jam);
    if (pilih != null) setState(() => _jam = pilih);
  }

  Future<void> _simpan() async {
    // pengaman ganda: validasi form + pemeriksaan nilai mentah
    final valid = _formKey.currentState!.validate();
    final jumlahMentah = parseRupiah(_jumlah.text);
    if (!valid ||
        _nama.text.trim().isEmpty ||
        jumlahMentah == null ||
        jumlahMentah <= 0) {
      _formKey.currentState!.validate();
      return;
    }
    final repo = ref.read(tagihanRepoProvider);
    // KategoriId yang ditulis = yang terlihat di layar (bukan id kategori yang
    // sudah dihapus di layar "Kategori tagihan").
    final daftarKategori = ref.read(kategoriProvider).value;
    final kategoriId = daftarKategori == null
        ? _kategoriId
        : _kategoriIdTerpakai(daftarKategori);
    final jumlahSen = rupiahKeSen(jumlahMentah);
    final jam = '${_jam.hour.toString().padLeft(2, '0')}:'
        '${_jam.minute.toString().padLeft(2, '0')}';
    final lead = leadKeTeks(_lead.toList());

    try {
      if (widget.id == null) {
        final baru = await repo.tambah(TagihanCompanion.insert(
          nama: _nama.text.trim(),
          jumlahSen: Value(jumlahSen),
          jatuhTempo: _jatuhTempo,
          kategoriId: Value(kategoriId),
          frekuensi: Value(_frekuensi.nilaiDb),
          pengingatLeadHari: Value(lead),
          pengingatJam: Value(jam),
          prioritas: Value(_prioritas.nilaiDb),
          catatan: Value(_catatan.text.trim().isEmpty ? null : _catatan.text.trim()),
          tautanBayar: Value(_tautan.text.trim().isEmpty ? null : _tautan.text.trim()),
        ));
        await _catatAudit(
          AksiAudit.buat,
          entitasId: '${baru.id}',
          ringkas: 'Tagihan "${baru.nama}" dibuat, jatuh tempo '
              '${fmtTanggalAman(baru.jatuhTempo)}.',
        );
      } else {
        final diubah = await repo.ubah(
          TagihanCompanion(
            nama: Value(_nama.text.trim()),
            jumlahSen: Value(jumlahSen),
            jatuhTempo: Value(_jatuhTempo),
            kategoriId: Value(kategoriId),
            frekuensi: Value(_frekuensi.nilaiDb),
            pengingatLeadHari: Value(lead),
            pengingatJam: Value(jam),
            prioritas: Value(_prioritas.nilaiDb),
            catatan: Value(_catatan.text.trim().isEmpty ? null : _catatan.text.trim()),
            tautanBayar: Value(_tautan.text.trim().isEmpty ? null : _tautan.text.trim()),
          ),
          id: widget.id!,
        );
        // PB-13: jangan bilang "tersimpan" kalau tidak ada baris yang berubah
        // (mis. tagihan sudah dihapus di layar lain).
        if (diubah > 0) {
          await _catatAudit(
            AksiAudit.ubah,
            entitasId: '${widget.id}',
            ringkas: 'Tagihan "${_nama.text.trim()}" diubah, jatuh tempo '
                '${fmtTanggalAman(_jatuhTempo)}.',
          );
        }
        if (diubah == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Perubahan tidak diterapkan: tagihan tidak ditemukan '
                    '(mungkin sudah dihapus).')));
          }
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.id == null
                ? 'Tagihan tersimpan.'
                : 'Perubahan tersimpan.')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  /// FR-138: satu baris catatan aktivitas per aksi pengguna.
  ///
  /// Ditulis dari LAYAR (bukan dari repository) karena satu aksi pengguna hanya
  /// melakukan SATU tulisan basis data yang ditunggu; tulisan kedua di dalam
  /// method repository membuat uji widget macet (drift menunggu siklus pump).
  Future<void> _catatAudit(
    String aksi, {
    required String entitasId,
    required String ringkas,
  }) async {
    if (widget.id == null && aksi != AksiAudit.buat) return;
    await catatAuditAman(
      ref.read(databaseProvider),
      modul: ModulAudit.tagihan,
      aksi: aksi,
      entitas: 'tagihan',
      entitasId: entitasId,
      ringkas: ringkas,
    );
  }

  Future<void> _hapus() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus tagihan?'),
        content: const Text(
            'Tagihan dan seluruh riwayat pembayarannya akan dihapus permanen. '
            'Untuk sekadar menghentikan pengingat, gunakan "Nonaktifkan" pada daftar.'),
        actions: [
          TextButton(onPressed: () => c.pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => c.pop(true), child: const Text('Hapus')),
        ],
      ),
    );
    if (yakin != true) return;
    await ref.read(tagihanRepoProvider).hapus(widget.id!);
    await _catatAudit(
      AksiAudit.hapus,
      entitasId: '${widget.id}',
      ringkas: 'Tagihan "${_nama.text.trim()}" dihapus beserta riwayatnya.',
    );
    if (mounted) context.pop();
  }
}
