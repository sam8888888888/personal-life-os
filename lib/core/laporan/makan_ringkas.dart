/// FR-110 — catatan makan ringkas (quick log), murni tanpa I/O.
///
/// Prinsip modul kesehatan (PRD §7.4 & III-11): aplikasi MENCATAT dan
/// MENUNJUKKAN apa yang ditulis pengguna. Tidak ada penilaian "sehat/tidak",
/// tidak ada hitungan kalori otomatis, tidak ada kalimat menyalahkan.
library;

/// Jenis waktu makan yang dipakai formulir cepat.
const List<String> jenisMakan = <String>[
  'sarapan',
  'makan_siang',
  'makan_malam',
  'camilan',
];

/// Label yang ditampilkan untuk tiap jenis.
String labelMakan(String jenis) => switch (jenis) {
      'sarapan' => 'Sarapan',
      'makan_siang' => 'Makan siang',
      'makan_malam' => 'Makan malam',
      'camilan' => 'Camilan',
      _ => jenis,
    };

/// Satu catatan makan.
class BarisMakan {
  const BarisMakan({
    required this.jenis,
    required this.isi,
    required this.waktu,
    this.porsi,
    this.mutu,
    this.id,
  });

  final int? id;
  final String jenis;
  final String isi;
  final String? porsi;

  /// Penilaian pengguna sendiri: baik / cukup / kurang (boleh kosong).
  final String? mutu;
  final DateTime waktu;
}

/// Isi satu jenis waktu makan pada satu hari.
class IsiJenisMakan {
  const IsiJenisMakan({
    required this.jenis,
    required this.label,
    required this.jumlahCatatan,
    required this.isi,
  });

  final String jenis;
  final String label;
  final int jumlahCatatan;
  final List<String> isi;

  /// Apakah jenis ini sudah tercatat hari itu.
  bool get tercatat => jumlahCatatan > 0;
}

/// Ringkasan catatan makan satu hari.
class RingkasMakanHari {
  const RingkasMakanHari({
    required this.tanggal,
    required this.jumlahCatatan,
    required this.perJenis,
    required this.belumTercatat,
    required this.jamPertama,
    required this.jamTerakhir,
  });

  final DateTime tanggal;
  final int jumlahCatatan;
  final List<IsiJenisMakan> perJenis;

  /// Jenis waktu makan yang belum ada catatannya hari ini (apa adanya).
  final List<String> belumTercatat;
  final DateTime? jamPertama;
  final DateTime? jamTerakhir;

  /// Rentang jam antara catatan pertama dan terakhir (null bila < 2 catatan).
  Duration? get rentangJam {
    if (jamPertama == null || jamTerakhir == null) return null;
    return jamTerakhir!.difference(jamPertama!);
  }
}

/// Tanda hari yang sama (tanggal kalender).
bool hariMakanSama(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Ringkas catatan makan pada hari [acuan].
RingkasMakanHari ringkasMakanHari(
  List<BarisMakan> catatan, {
  required DateTime acuan,
}) {
  final hariIni = catatan.where((c) => hariMakanSama(c.waktu, acuan)).toList()
    ..sort((a, b) => a.waktu.compareTo(b.waktu));

  final perJenis = <IsiJenisMakan>[];
  final belum = <String>[];
  for (final jenis in jenisMakan) {
    final isiJenis = hariIni.where((c) => c.jenis == jenis).toList();
    perJenis.add(IsiJenisMakan(
      jenis: jenis,
      label: labelMakan(jenis),
      jumlahCatatan: isiJenis.length,
      isi: isiJenis.map((c) => c.isi).toList(),
    ));
    if (isiJenis.isEmpty) belum.add(jenis);
  }

  return RingkasMakanHari(
    tanggal: DateTime(acuan.year, acuan.month, acuan.day),
    jumlahCatatan: hariIni.length,
    perJenis: perJenis,
    belumTercatat: belum,
    jamPertama: hariIni.isEmpty ? null : hariIni.first.waktu,
    jamTerakhir: hariIni.isEmpty ? null : hariIni.last.waktu,
  );
}

/// Jumlah catatan makan per hari (untuk grafik sederhana).
class BatangMakan {
  const BatangMakan({
    required this.tanggal,
    required this.jumlah,
    required this.label,
  });

  final DateTime tanggal;
  final int jumlah;
  final String label;
}

/// Jumlah catatan per hari untuk [hari] hari terakhir.
List<BatangMakan> batangMakan(
  List<BarisMakan> catatan, {
  required DateTime acuan,
  int hari = 7,
}) {
  const namaHari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  final hasil = <BatangMakan>[];
  for (var i = hari - 1; i >= 0; i--) {
    final tgl =
        DateTime(acuan.year, acuan.month, acuan.day).subtract(Duration(days: i));
    final jumlah = catatan.where((c) => hariMakanSama(c.waktu, tgl)).length;
    hasil.add(BatangMakan(
      tanggal: tgl,
      jumlah: jumlah,
      label: namaHari[tgl.weekday - 1],
    ));
  }
  return hasil;
}

/// Isi yang paling sering dicatat (untuk tombol cepat/biasaan pengguna).
List<String> isiTersering(List<BarisMakan> catatan, {int batas = 5}) {
  final hitung = <String, int>{};
  for (final c in catatan) {
    final isi = c.isi.trim();
    if (isi.isEmpty) continue;
    hitung.update(isi.toLowerCase(), (v) => v + 1, ifAbsent: () => 1);
  }
  final urut = hitung.entries.toList()
    ..sort((a, b) => b.value == a.value
        ? a.key.compareTo(b.key)
        : b.value.compareTo(a.value));
  return urut.take(batas).map((e) => e.key).toList();
}

/// Jumlah hari berturut-turut (sampai [acuan]) yang punya catatan makan.
///
/// Dipakai hanya sebagai keterangan "tercatat beberapa hari berturut-turut",
/// bukan penilaian kepatuhan.
int hariBerturutTercatat(List<BarisMakan> catatan, {required DateTime acuan}) {
  var jumlah = 0;
  var hari = DateTime(acuan.year, acuan.month, acuan.day);
  while (true) {
    final ada = catatan.any((c) => hariMakanSama(c.waktu, hari));
    if (!ada) break;
    jumlah++;
    hari = hari.subtract(const Duration(days: 1));
  }
  return jumlah;
}
