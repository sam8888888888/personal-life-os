/// FR-132 — Kalender Keluarga.
///
/// Kriteria terima PRD: "Satu tampilan memuat agenda semua anggota dengan warna
/// berbeda."
///
/// Karena itu berkas ini mengurus dua hal dan tidak lebih:
/// 1. mengelompokkan agenda per hari (urut), dan
/// 2. memberi **warna berbeda per anggota** — warnanya diambil dari urutan
///    anggota yang hadir pada rentang itu, jadi dua anggota tidak pernah
///    kebagian warna sama (selama jumlah anggota ≤ jumlah palet).
///
/// Ulang tahun dihitung dari tanggal lahir anggota, termasuk "ke-berapa" pada
/// tahun berjalan.
library;

/// Satu baris agenda di kalender keluarga.
class AgendaKeluarga {
  const AgendaKeluarga({
    required this.tanggal,
    required this.judul,
    required this.modul,
    this.keterangan = '',
    this.anggotaId,
    this.selesai = false,
  });

  final DateTime tanggal;
  final String judul;

  /// tagihan · tugas · janji · perawatan · ulang_tahun · kegiatan
  final String modul;

  final String keterangan;

  /// null = agenda bukan milik anggota tertentu (mis. tagihan rumah).
  final int? anggotaId;

  final bool selesai;

  String get labelModul => switch (modul) {
        'tagihan' => 'Tagihan',
        'tugas' => 'Tugas',
        'janji' => 'Janji',
        'perawatan' => 'Perawatan',
        'ulang_tahun' => 'Ulang tahun',
        'kegiatan' => 'Kegiatan',
        _ => modul,
      };
}

/// Satu hari + agenda-agendanya.
class HariKeluarga {
  const HariKeluarga({required this.tanggal, required this.agenda});

  final DateTime tanggal;
  final List<AgendaKeluarga> agenda;

  bool get adaAgenda => agenda.isNotEmpty;
}

/// Palet warna anggota. Dipakai berurutan (indeks), bukan dihitung dari id,
/// supaya warna benar-benar berbeda antar anggota pada satu tampilan.
const List<int> paletWarnaAnggota = [
  0xFF1565C0,
  0xFF2E7D32,
  0xFF6A1B9A,
  0xFFAD1457,
  0xFFEF6C00,
  0xFF00838F,
  0xFF4E342E,
  0xFF283593,
];

/// Pemetaan anggota → indeks warna (urut menaik berdasarkan id).
Map<int, int> warnaAnggotaUntuk(Iterable<AgendaKeluarga> agenda) {
  final id = agenda
      .map((a) => a.anggotaId)
      .whereType<int>()
      .toSet()
      .toList()
    ..sort();
  return {
    for (var i = 0; i < id.length; i++) id[i]: i % paletWarnaAnggota.length,
  };
}

int warnaUntukAnggota(int? anggotaId, Map<int, int> peta) {
  if (anggotaId == null) return 0xFF616161; // abu: agenda bersama
  final i = peta[anggotaId];
  if (i == null) return 0xFF616161;
  return paletWarnaAnggota[i];
}

/// Susun kalender: saring rentang & anggota, urutkan per hari.
List<HariKeluarga> susunKalenderKeluarga({
  required List<AgendaKeluarga> agenda,
  required DateTime dari,
  required DateTime sampai,
  int? saringAnggota,
  Set<String>? saringModul,
}) {
  final awal = _awalHari(dari);
  final akhir = _awalHari(sampai);
  final lulus = agenda.where((a) {
    final t = _awalHari(a.tanggal);
    if (t.isBefore(awal) || t.isAfter(akhir)) return false;
    if (saringAnggota != null && a.anggotaId != saringAnggota) return false;
    if (saringModul != null && !saringModul.contains(a.modul)) return false;
    return true;
  }).toList()
    ..sort((a, b) => a.tanggal.compareTo(b.tanggal));

  final perHari = <DateTime, List<AgendaKeluarga>>{};
  for (final a in lulus) {
    perHari.putIfAbsent(_awalHari(a.tanggal), () => []).add(a);
  }
  final hari = perHari.keys.toList()..sort();
  return [
    for (final h in hari) HariKeluarga(tanggal: h, agenda: perHari[h]!),
  ];
}

/// Ulang tahun anggota pada tahun [tahun] (termasuk "ke-berapa").
///
/// Mengembalikan daftar agenda siap tampil; anggota tanpa tanggal lahir
/// dilewati (tidak dikarang).
List<AgendaKeluarga> ulangTahunAnggota({
  required Iterable<({int id, String nama, DateTime? lahir})> anggota,
  required int tahun,
}) {
  final hasil = <AgendaKeluarga>[];
  for (final a in anggota) {
    final lahir = a.lahir;
    if (lahir == null) continue;
    final tanggal = DateTime(tahun, lahir.month, lahir.day);
    final umur = tahun - lahir.year;
    if (umur < 0) continue;
    hasil.add(AgendaKeluarga(
      tanggal: tanggal,
      judul: 'Ulang tahun ${a.nama}',
      modul: 'ulang_tahun',
      keterangan: 'ke-$umur',
      anggotaId: a.id,
    ));
  }
  return hasil;
}

String ringkasKalender(List<HariKeluarga> hari) {
  if (hari.isEmpty) return 'Tidak ada agenda pada rentang ini.';
  var agenda = 0;
  for (final h in hari) {
    agenda += h.agenda.length;
  }
  return '$agenda agenda dalam ${hari.length} hari';
}

DateTime _awalHari(DateTime t) => DateTime(t.year, t.month, t.day);
