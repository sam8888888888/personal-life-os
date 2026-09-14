/// Model catatan sholat harian (FR-88 Pelacakan 5 Waktu Sholat).
///
/// Bahasa model sengaja NETRAL (aturan III-11 PRD): yang disimpan hanya
/// "tercatat" / "belum tercatat". Tidak ada skor, tidak ada penilaian, tidak
/// ada kata menghakimi. Jumlah maksimum selalu 5 (lima waktu wajib); Syuruq
/// tidak pernah dihitung karena bukan waktu sholat.
library;

import 'model_sholat.dart';

/// Kunci tanggal `YYYY-MM-DD` (selalu dengan nol depan), dari tanggal sipil
/// kota pilihan pengguna — bukan tanggal perangkat.
String tanggalKunci(DateTime sipil) =>
    '${sipil.year.toString().padLeft(4, '0')}-'
    '${sipil.month.toString().padLeft(2, '0')}-'
    '${sipil.day.toString().padLeft(2, '0')}';

/// Ubah kunci `YYYY-MM-DD` menjadi `DateTime` jam 00:00 UTC (penanda tanggal).
/// Mengembalikan null bila kunci tidak berbentuk `YYYY-MM-DD`.
DateTime? tanggalDariKunci(String kunci) {
  if (!kunciSah(kunci)) return null;
  final int tahun = int.parse(kunci.substring(0, 4));
  final int bulan = int.parse(kunci.substring(5, 7));
  final int hari = int.parse(kunci.substring(8, 10));
  if (bulan < 1 || bulan > 12 || hari < 1 || hari > 31) return null;
  return DateTime.utc(tahun, bulan, hari);
}

/// Benar bila [kunci] berbentuk `YYYY-MM-DD` (dipakai penyimpanan agar kunci
/// yang salah tidak pernah masuk berkas).
bool kunciSah(String kunci) =>
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(kunci);

/// Catatan satu hari: tanggal sipil + waktu wajib yang sudah ditandai.
class CatatanSholat {
  const CatatanSholat({required this.tanggal, required this.tercatat});

  /// Semua waktu wajib ditandai (dipakai tombol "Tandai semua tercatat").
  factory CatatanSholat.penuh(String tanggal) =>
      CatatanSholat(tanggal: tanggal, tercatat: WaktuSholat.wajibSaja.toSet());

  /// Tanggal sipil kota, bentuk `YYYY-MM-DD`.
  final String tanggal;

  /// Himpunan penanda. Hanya waktu wajib yang dihitung (Syuruq diabaikan),
  /// jadi isi yang tidak wajar pun tidak bisa membuat jumlah melebihi 5.
  final Set<WaktuSholat> tercatat;

  /// 0..5 — jumlah waktu WAJIB yang tercatat.
  int get jumlah =>
      WaktuSholat.wajibSaja.where((WaktuSholat w) => tercatat.contains(w)).length;

  /// Benar bila kelima waktu wajib tercatat.
  bool get lengkap => jumlah == WaktuSholat.wajibSaja.length;

  /// Benar bila [w] tercatat (Syuruq selalu false: bukan sholat wajib).
  bool tercatatPada(WaktuSholat w) => w.wajib && tercatat.contains(w);

  /// Daftar kode penanda yang urut (untuk disimpan di berkas & diuji).
  List<String> get kodeTercatat => <String>[
        for (final WaktuSholat w in WaktuSholat.wajibSaja)
          if (tercatat.contains(w)) w.name,
      ];

  /// Salinan dengan penanda berbeda (tanggal tetap).
  CatatanSholat salinDengan({Set<WaktuSholat>? tercatat}) => CatatanSholat(
        tanggal: tanggal,
        tercatat: tercatat ?? this.tercatat,
      );

  /// Salinan dengan satu waktu diubah statusnya.
  CatatanSholat dengan(WaktuSholat w, bool tercatat) {
    if (!w.wajib) return this;
    final Set<WaktuSholat> baru = Set<WaktuSholat>.from(this.tercatat);
    if (tercatat) {
      baru.add(w);
    } else {
      baru.remove(w);
    }
    return salinDengan(tercatat: baru);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tanggal': tanggal,
        'tercatat': kodeTercatat,
      };

  factory CatatanSholat.fromJson(Map<String, dynamic> j) {
    final Object? isi = j['tercatat'];
    final Set<WaktuSholat> penanda = <WaktuSholat>{};
    if (isi is List) {
      for (final Object? kode in isi) {
        if (kode is! String) continue;
        for (final WaktuSholat w in WaktuSholat.wajibSaja) {
          if (w.name == kode) penanda.add(w);
        }
      }
    }
    return CatatanSholat(
      tanggal: (j['tanggal'] ?? '') as String,
      tercatat: penanda,
    );
  }

  @override
  String toString() =>
      'CatatanSholat($tanggal, $jumlah/5: ${kodeTercatat.join(", ")})';

  @override
  bool operator ==(Object other) =>
      other is CatatanSholat &&
      other.tanggal == tanggal &&
      other.jumlah == jumlah &&
      kodeTercatat.join(',') == other.kodeTercatat.join(',');

  @override
  int get hashCode => Object.hash(tanggal, kodeTercatat.join(','));
}

/// Catatan kosong untuk satu tanggal (0 dari 5).
CatatanSholat kosongPada(String tanggal) =>
    CatatanSholat(tanggal: tanggal, tercatat: const <WaktuSholat>{});
