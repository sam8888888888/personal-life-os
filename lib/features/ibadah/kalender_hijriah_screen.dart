/// Layar Kalender Hijriah (FR-90).
///
/// Semua teks menyebut "perhitungan", bukan penetapan resmi, dan pengguna
/// boleh memilih acuan serta koreksi hari (lihat catatanPenetapan).
library;

import 'package:flutter/material.dart';

import '../../core/ibadah/kalender_hijriah.dart';
import '../../core/ibadah/model_sholat.dart';

class KalenderHijriahScreen extends StatefulWidget {
  const KalenderHijriahScreen({
    super.key,
    this.jamSekarang,
    this.acuanAwal = AcuanHijriah.ummAlQura,
    this.koreksiAwal = 0,
  });

  final DateTime Function()? jamSekarang;
  final AcuanHijriah acuanAwal;
  final int koreksiAwal;

  @override
  State<KalenderHijriahScreen> createState() => _StateKalenderHijriah();
}

class _StateKalenderHijriah extends State<KalenderHijriahScreen> {
  static const int _batasKoreksi = 2;

  late AcuanHijriah _acuan;
  late int _koreksi;
  late int _tahun;
  late int _bulan;

  DateTime get _sekarang => (widget.jamSekarang ?? DateTime.now)();

  /// Tanggal sipil menurut jam perangkat (BUKAN UTC): kalender dipakai untuk
  /// "hari ini" pengguna, jadi jam 06.00 WIB harus tetap terbaca tanggal yang
  /// sama seperti di dinding, bukan tanggal UTC hari sebelumnya.
  DateTime get _tanggalHariIni =>
      DateTime(_sekarang.year, _sekarang.month, _sekarang.day);

  @override
  void initState() {
    super.initState();
    _acuan = widget.acuanAwal;
    _koreksi = widget.koreksiAwal;
    final TanggalHijriah? h = hijriahDariMasehi(_tanggalHariIni,
        acuan: _acuan, koreksiHari: _koreksi);
    _tahun = h?.tahun ?? 1447;
    _bulan = h?.bulan ?? 1;
  }

  BulanHijriah get _bulanHijriah => susunBulanHijriah(
        _tahun,
        _bulan,
        acuan: _acuan,
        koreksiHari: _koreksi,
      );

  void _geser(int delta) {
    setState(() {
      int b = _bulan + delta;
      int t = _tahun;
      if (b < 1) {
        b = 12;
        t -= 1;
      } else if (b > 12) {
        b = 1;
        t += 1;
      }
      _bulan = b;
      _tahun = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final BulanHijriah b = _bulanHijriah;
    final TanggalHijriah? hariIni = hijriahDariMasehi(_tanggalHariIni,
        acuan: _acuan, koreksiHari: _koreksi);

    return Scaffold(
      appBar: AppBar(title: const Text('Kalender Hijriah')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Bulan sebelumnya',
                onPressed: () => _geser(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(b.label,
                      style: tema.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
              IconButton(
                tooltip: 'Bulan berikutnya',
                onPressed: () => _geser(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Text(
            'Hari ini: ${hariIni?.label ?? 'belum tersedia'} '
            '(${tanggalPendek(_tanggalHariIni)})',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _GridBulan(bulan: b, hariIni: hariIni),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: DropdownButtonFormField<AcuanHijriah>(
                    initialValue: _acuan,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Acuan perhitungan',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<AcuanHijriah>>[
                      for (final AcuanHijriah a in AcuanHijriah.values)
                        DropdownMenuItem<AcuanHijriah>(
                          value: a,
                          child: Text(a.label),
                        ),
                    ],
                    onChanged: (AcuanHijriah? a) {
                      if (a == null) return;
                      setState(() => _acuan = a);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Koreksi hari'),
                  subtitle: Text(_koreksi == 0
                      ? 'Tanpa koreksi'
                      : '${_koreksi > 0 ? '+' : ''}$_koreksi hari'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Mundurkan satu hari',
                        onPressed: _koreksi <= -_batasKoreksi
                            ? null
                            : () => setState(() => _koreksi -= 1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        tooltip: 'Majukan satu hari',
                        onPressed: _koreksi >= _batasKoreksi
                            ? null
                            : () => setState(() => _koreksi += 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '${_acuan.keterangan} $catatanPenetapan',
                    style: tema.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Hari besar bulan ini', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (b.peringatan.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Belum ada data hari besar pada bulan ini'),
              ),
            )
          else
            for (final ({HariPentingHijriah hari, DateTime masehi}) p in b.peringatan)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: Text(p.hari.nama),
                  subtitle: Text('${p.hari.hari} ${b.namaBulan} - '
                      '${tanggalPendek(p.masehi)}\n${p.hari.keterangan}'),
                  isThreeLine: true,
                ),
              ),
        ],
      ),
    );
  }
}

class _GridBulan extends StatelessWidget {
  const _GridBulan({required this.bulan, required this.hariIni});

  final BulanHijriah bulan;
  final TanggalHijriah? hariIni;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final int geser = bulan.sel.isEmpty ? 0 : bulan.sel.first.kolom;
    final List<Widget> sel = <Widget>[
      for (final String h in namaHariSingkat)
        Center(
          child: Text(h,
              style: tema.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
      for (int i = 0; i < geser; i++) const SizedBox.shrink(),
      for (final SelKalenderHijriah s in bulan.sel)
        _SelHari(
          sel: s,
          aktif: hariIni != null &&
              s.hijriah.hari == hariIni!.hari &&
              s.hijriah.bulan == hariIni!.bulan &&
              s.hijriah.tahun == hariIni!.tahun,
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.85,
          children: sel,
        ),
      ),
    );
  }
}

class _SelHari extends StatelessWidget {
  const _SelHari({required this.sel, required this.aktif});

  final SelKalenderHijriah sel;
  final bool aktif;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: aktif ? tema.colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: sel.adaPeringatan
              ? tema.colorScheme.primary
              : tema.colorScheme.outlineVariant,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('${sel.hijriah.hari}',
                  style: tema.textTheme.bodyLarge?.copyWith(
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                  )),
              Text('${sel.masehi.day}/${sel.masehi.month}',
                  style: tema.textTheme.bodySmall),
              if (sel.adaPeringatan)
                Icon(Icons.star, size: 10, color: tema.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
