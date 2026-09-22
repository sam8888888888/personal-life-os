#!/usr/bin/env python3
"""Wiring B — garansi (FR-126) & perawatan (FR-125) muncul di Perhatian Today.

Idempoten.
"""
import pathlib, sys

repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
b = lambda p: (repo / p).read_text(encoding="utf-8")
t = lambda p, s: (repo / p).write_text(s, encoding="utf-8")

# --------------------------------------------------- 1. provider data Perhatian
p = "lib/features/rumah/rumah_providers.dart"
s = b(p)
if "garansiDekatProvider" not in s:
    s = s.replace(
        "import '../../core/providers/app_providers.dart';",
        "import '../../core/providers/app_providers.dart';\n"
        "import '../../core/utils/waktu.dart';\n"
        "import '../../data/database/database.dart';", 1)
    s += """
/// Aset yang garansinya berakhir ≤ 30 hari (FR-126) — untuk Perhatian Today.
final garansiDekatProvider = FutureProvider<List<AsetData>>(
    (ref) => ref.watch(repoRumahProvider).garansiDekat(waktuSekarang()));

/// Jadwal perawatan yang jatuh tempo ≤ 14 hari (FR-125).
final perawatanDekatProvider = FutureProvider<List<PerawatanData>>((ref) =>
    ref.watch(repoRumahProvider).perawatanJatuhTempo(waktuSekarang(),
        hariKeDepan: 14));
"""
    t(p, s)
    print("OK: provider garansi & perawatan ditambahkan")
else:
    print("LEWAT: provider sudah ada")

# ------------------------------------------------- 2. model: jenis + data baru
p = "lib/core/hari_ini/model_hari_ini.dart"
s = b(p)
if "garansiAset" not in s:
    s = s.replace(
        "enum JenisPerhatian { tagihanTerlambat, hambatanSistem, tenggatDekat, dokumenKedaluwarsa }",
        "enum JenisPerhatian {\n"
        "  tagihanTerlambat,\n"
        "  hambatanSistem,\n"
        "  tenggatDekat,\n"
        "  dokumenKedaluwarsa,\n"
        "  garansiAset,\n"
        "  perawatanAset,\n"
        "}", 1)
    s = s.replace(
        "        JenisPerhatian.dokumenKedaluwarsa => 3,",
        "        JenisPerhatian.dokumenKedaluwarsa => 3,\n"
        "        JenisPerhatian.garansiAset => 4,\n"
        "        JenisPerhatian.perawatanAset => 5,", 1)
    s += """
/// Ringkas garansi aset untuk Perhatian (FR-126).
class RingkasGaransiAset {
  const RingkasGaransiAset({
    required this.asetId,
    required this.nama,
    required this.sampai,
  });

  final int asetId;
  final String nama;
  final DateTime sampai;
}

/// Ringkas jadwal perawatan untuk Perhatian (FR-125).
class RingkasPerawatanAset {
  const RingkasPerawatanAset({
    required this.perawatanId,
    required this.nama,
    required this.berikutnya,
    this.asetId,
  });

  final int perawatanId;
  final String nama;
  final DateTime berikutnya;
  final int? asetId;
}
"""
    t(p, s)
    print("OK: jenis & kelas ringkas garansi/perawatan ditambahkan")
else:
    print("LEWAT: model sudah ada")

# ------------------------------------------- 3. penyusun: DataHariIni + butir
p = "lib/core/hari_ini/penyusun_hari_ini.dart"
s = b(p)
if "RingkasGaransiAset" not in s and "garansiAset" not in s:
    # 3a. konstruktor & field & salinDengan
    s = s.replace("""    this.sumberCuaca = '',
    this.daring = true,
  });""", """    this.sumberCuaca = '',
    this.daring = true,
    this.garansiAset = const [],
    this.perawatanAset = const [],
  });""", 1)
    s = s.replace("""  final String sumberCuaca;
  final bool daring;""", """  final String sumberCuaca;
  final bool daring;

  /// Garansi aset yang berakhir ≤ 30 hari (FR-126).
  final List<RingkasGaransiAset> garansiAset;

  /// Jadwal perawatan aset yang jatuh tempo ≤ 14 hari (FR-125).
  final List<RingkasPerawatanAset> perawatanAset;""", 1)
    s = s.replace("""        sumberCuaca: sumberCuaca,
        daring: daring ?? this.daring,
      );""", """        sumberCuaca: sumberCuaca,
        daring: daring ?? this.daring,
        garansiAset: garansiAset,
        perawatanAset: perawatanAset,
      );""", 1)
    # 3b. butir Perhatian
    anchor = """  butir.sort((a, b) {"""
    tambahan = """  for (final g in data.garansiAset) {
    final sisa = sisaHariKe(data.sekarang, g.sampai);
    butir.add(ButirPerhatian(
      id: 'garansi-${g.asetId}',
      jenis: JenisPerhatian.garansiAset,
      judul: 'Garansi hampir berakhir',
      // Alasan wajib membawa data nyata (§5.1).
      alasan: '${g.nama} · garansi sampai ${fmtTanggalAman2(g.sampai)}'
          '${sisa < 0 ? ' (sudah lewat ${-sisa} hari)' : ' · $sisa hari lagi'}',
      labelTombol: 'Buka aset',
      rute: '/rumah/aset/${g.asetId}',
      tingkat: sisa < 0 ? TingkatPrioritas.merah : TingkatPrioritas.kuning,
    ));
  }

  for (final w in data.perawatanAset) {
    final sisa = sisaHariKe(data.sekarang, w.berikutnya);
    butir.add(ButirPerhatian(
      id: 'perawatan-${w.perawatanId}',
      jenis: JenisPerhatian.perawatanAset,
      judul: 'Perawatan mendekat',
      alasan: '${w.nama} · jadwal ${fmtTanggalAman2(w.berikutnya)}'
          '${sisa < 0 ? ' (lewat ${-sisa} hari)' : ' · $sisa hari lagi'}',
      labelTombol: w.asetId == null ? 'Buka Aksi' : 'Buka aset',
      rute: w.asetId == null ? '/aksi/perawatan' : '/rumah/aset/${w.asetId}',
      tingkat: sisa < 0 ? TingkatPrioritas.oranye : TingkatPrioritas.kuning,
    ));
  }

"""
    if anchor not in s:
        print("GAGAL: jangkar butir.sort tidak ditemukan"); sys.exit(1)
    s = s.replace(anchor, tambahan + anchor, 1)
    # 3c. bantuan format tanggal tanpa locale
    if "String fmtTanggalAman2(" not in s:
        s = s.rstrip("\n") + """

/// Format tanggal tanpa data locale (dipakai alasan Perhatian).
///
/// Tidak memakai `DateFormat` ber-locale: layar Today bisa dibangun sebelum
/// `initializeDateFormatting` jalan.
String fmtTanggalAman2(DateTime d) {
  const bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${d.day} ${bulan[d.month - 1]} ${d.year}';
}
"""
    t(p, s)
    print("OK: penyusun hari ini menambahkan garansi & perawatan")
else:
    print("LEWAT: penyusun sudah ada")

# ------------------------------------------------- 4. layar Today memuat data
p = "lib/features/hari_ini/hari_ini_screen.dart"
s = b(p)
if "garansiDekatProvider" not in s:
    anchor = "    final tinjauanAktif = ref.watch(tinjauanMalamAktifProvider).value ?? true;"
    sisip = anchor + """

    // FR-126 & FR-125: garansi aset yang hampir berakhir + perawatan yang
    // mendekat, keduanya muncul sebagai Perhatian (maks 5 butir).
    final garansiAset = ref.watch(garansiDekatProvider).value ?? const <AsetData>[];
    final perawatanDekat =
        ref.watch(perawatanDekatProvider).value ?? const <PerawatanData>[];"""
    if anchor not in s:
        print("GAGAL: jangkar tinjauanAktif tidak ditemukan"); sys.exit(1)
    s = s.replace(anchor, sisip, 1)
    s = s.replace("""      namaPanggilan: widget.namaPanggilan,
    );""", """      namaPanggilan: widget.namaPanggilan,
      garansiAset: [
        for (final a in garansiAset)
          if (a.garansiSampai != null)
            RingkasGaransiAset(
                asetId: a.id, nama: a.nama, sampai: a.garansiSampai!),
      ],
      perawatanAset: [
        for (final w in perawatanDekat)
          RingkasPerawatanAset(
            perawatanId: w.id,
            nama: w.nama,
            berikutnya: w.berikutnya,
            asetId: w.asetId,
          ),
      ],
    );""", 1)
    # impor
    s = s.replace("import '../../core/hari_ini/penyusun_hari_ini.dart';",
                  "import '../../core/hari_ini/penyusun_hari_ini.dart';\n"
                  "import '../../data/database/database.dart';\n"
                  "import '../rumah/rumah_providers.dart';", 1)
    t(p, s)
    print("OK: layar Today memuat garansi & perawatan")
else:
    print("LEWAT: layar Today sudah ada")
print("SELESAI wiring B")
