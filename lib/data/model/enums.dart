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

// ---------------------------------------------------------------------------
// Enum kas & kekayaan (skema v3 — FR-68/71/72/76)
// ---------------------------------------------------------------------------

/// Arah arus kas satu transaksi (FR-71).
enum JenisArus {
  pemasukan('pemasukan'),
  pengeluaran('pengeluaran');

  const JenisArus(this.nilaiDb);
  final String nilaiDb;

  static JenisArus dariDb(String? v) =>
      JenisArus.values.firstWhere((e) => e.nilaiDb == v, orElse: () => JenisArus.pengeluaran);

  /// Faktor pengali untuk menghitung arus kas bersih (pemasukan positif).
  int get tanda => this == JenisArus.pemasukan ? 1 : -1;

  String get label => this == JenisArus.pemasukan ? 'Pemasukan' : 'Pengeluaran';
}

/// Sifat arus sebuah kategori — bahan awal FR-68 (kategori mana yang lazim
/// berulang). Nilainya hanya saran tampilan, bukan aturan pengingat.
enum SifatArus {
  berulang('berulang'),
  sekali('sekali'),
  campuran('campuran');

  const SifatArus(this.nilaiDb);
  final String nilaiDb;

  static SifatArus dariDb(String? v) =>
      SifatArus.values.firstWhere((e) => e.nilaiDb == v, orElse: () => SifatArus.campuran);

  String get label => switch (this) {
        SifatArus.berulang => 'Berulang (bulanan)',
        SifatArus.sekali => 'Sekali bayar',
        SifatArus.campuran => 'Berulang & sekali',
      };
}

/// Status langganan (FR-68). Hanya [aktif] yang menghasilkan pengingat.
enum StatusLangganan {
  aktif('aktif'),
  pause('pause'),
  berhenti('berhenti');

  const StatusLangganan(this.nilaiDb);
  final String nilaiDb;

  static StatusLangganan dariDb(String? v) => StatusLangganan.values
      .firstWhere((e) => e.nilaiDb == v, orElse: () => StatusLangganan.aktif);

  /// true = pengingat tagihan tertaut dihidupkan.
  bool get mengingatkan => this == StatusLangganan.aktif;

  String get label => switch (this) {
        StatusLangganan.aktif => 'Aktif',
        StatusLangganan.pause => 'Pause',
        StatusLangganan.berhenti => 'Berhenti',
      };
}

/// Jenis aset (FR-76).
enum JenisAset {
  kas('kas'),
  bank('bank'),
  investasi('investasi'),
  properti('properti'),
  kendaraan('kendaraan'),
  emas('emas'),
  kripto('kripto'),
  bisnis('bisnis'),
  lain('lain');

  const JenisAset(this.nilaiDb);
  final String nilaiDb;

  static JenisAset dariDb(String? v) =>
      JenisAset.values.firstWhere((e) => e.nilaiDb == v, orElse: () => JenisAset.lain);

  String get label => switch (this) {
        JenisAset.kas => 'Kas',
        JenisAset.bank => 'Bank',
        JenisAset.investasi => 'Investasi',
        JenisAset.properti => 'Properti',
        JenisAset.kendaraan => 'Kendaraan',
        JenisAset.emas => 'Emas',
        JenisAset.kripto => 'Kripto',
        JenisAset.bisnis => 'Bisnis',
        JenisAset.lain => 'Lain-lain',
      };
}

/// Jenis kewajiban (FR-76; dipakai FR-74/75 saat Debt Manager dikerjakan).
enum JenisKewajiban {
  kartuKredit('kartu_kredit'),
  kpr('kpr'),
  pinjaman('pinjaman'),
  cicilan('cicilan'),
  lain('lain');

  const JenisKewajiban(this.nilaiDb);
  final String nilaiDb;

  static JenisKewajiban dariDb(String? v) => JenisKewajiban.values
      .firstWhere((e) => e.nilaiDb == v, orElse: () => JenisKewajiban.lain);

  String get label => switch (this) {
        JenisKewajiban.kartuKredit => 'Kartu kredit',
        JenisKewajiban.kpr => 'KPR',
        JenisKewajiban.pinjaman => 'Pinjaman',
        JenisKewajiban.cicilan => 'Cicilan',
        JenisKewajiban.lain => 'Lain-lain',
      };
}
