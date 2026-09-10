/// Model enum inti Personal Life OS.
/// Disimpan sebagai TEXT di database agar migrasi ke depan mudah.
library;

enum Frekuensi {
  sekali('sekali'),
  mingguan('mingguan'),
  duaMingguan('dua_mingguan'),
  bulanan('bulanan'),
  duaBulanan('dua_bulanan'),
  kuartalan('kuartalan'),
  semesteran('semesteran'),
  tahunan('tahunan'),
  kustomHari('kustom_hari');

  const Frekuensi(this.nilaiDb);
  final String nilaiDb;

  static Frekuensi dariDb(String? v) =>
      Frekuensi.values.firstWhere((e) => e.nilaiDb == v, orElse: () => Frekuensi.bulanan);

  /// Berulang otomatis (membuat periode berikutnya saat dilunasi)?
  bool get berulang => this != Frekuensi.sekali;
}

enum KanalPengingat {
  push('push'),
  whatsapp('wa'),
  sms('sms'),
  telegram('telegram');

  const KanalPengingat(this.nilaiDb);
  final String nilaiDb;

  static KanalPengingat dariDb(String? v) =>
      KanalPengingat.values.firstWhere((e) => e.nilaiDb == v, orElse: () => KanalPengingat.push);
}

/// Urutan prioritas (untuk ikon/badge).
enum PrioritasTagihan {
  biasa('biasa'),
  penting('penting'),
  kritis('kritis');

  const PrioritasTagihan(this.nilaiDb);
  final String nilaiDb;
  static PrioritasTagihan dariDb(String? v) =>
      PrioritasTagihan.values.firstWhere((e) => e.nilaiDb == v, orElse: () => PrioritasTagihan.biasa);
}
