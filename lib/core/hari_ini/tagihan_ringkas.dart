/// Bentuk ringkas tagihan untuk Modul 0.
///
/// Sengaja bukan kelas Drift supaya lapisan logika Today tetap murni dan bisa
/// diuji tanpa basis data. Pemetaan dari `TagihanData` ada di lapisan UI
/// (`lib/features/hari_ini/pemetaan_tagihan.dart`).
library;

class TagihanRingkas {
  const TagihanRingkas({
    required this.id,
    required this.nama,
    required this.jatuhTempo,
    this.jumlahSen,
    this.jenis = 'tagihan',
    this.lunas = false,
    this.statusAktif = true,
    this.prioritas = 'biasa',
  });

  final int id;
  final String nama;
  final DateTime jatuhTempo;

  /// null untuk dokumen/non-moneter.
  final int? jumlahSen;
  final String jenis;
  final bool lunas;
  final bool statusAktif;
  final String prioritas;

  bool get dokumen => jenis == 'dokumen';
  bool get menuntutTindakan => statusAktif && !lunas;
}
