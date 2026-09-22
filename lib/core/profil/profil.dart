/// FR-44 — Multi-profil terpisah (pribadi / keluarga / usaha).
///
/// Cara kerja (dipilih supaya data lama TIDAK rusak):
/// * setiap profil punya **berkas basis data sendiri** di folder aplikasi;
/// * profil bawaan memakai nama berkas lama (`personal_life_os`) sehingga
///   pengguna yang sudah memakai aplikasi ini tidak kehilangan apa pun;
/// * daftar profil disimpan di berkas kecil `profil.json` (bukan tabel basis
///   data) supaya daftar tetap bisa dibaca walau profil mana pun sedang aktif.
library;

import 'dart:convert';
import 'dart:io';

/// Jenis profil — hanya penanda untuk tampilan, bukan pembatas fitur.
enum JenisProfil {
  pribadi('Pribadi'),
  keluarga('Keluarga'),
  usaha('Usaha');

  const JenisProfil(this.label);
  final String label;

  static JenisProfil dari(String? teks) => JenisProfil.values.firstWhere(
        (j) => j.name == teks,
        orElse: () => JenisProfil.pribadi,
      );
}

/// Id profil bawaan.
const String idProfilPribadi = 'pribadi';

/// Nama berkas basis data untuk sebuah profil.
///
/// Profil pribadi memakai nama lama supaya data pengguna yang sudah ada tetap
/// terbaca; profil lain memakai akhiran id-nya.
String namaBerkasDatabase(String idProfil) => idProfil == idProfilPribadi
    ? 'personal_life_os'
    : 'personal_life_os_$idProfil';

/// Satu profil.
class Profil {
  const Profil({required this.id, required this.nama, required this.jenis});

  final String id;
  final String nama;
  final JenisProfil jenis;

  bool get bawaan => id == idProfilPribadi;

  Map<String, Object?> kePeta() =>
      {'id': id, 'nama': nama, 'jenis': jenis.name};

  static Profil dariPeta(Map<String, Object?> peta) => Profil(
        id: (peta['id'] as String?) ?? idProfilPribadi,
        nama: (peta['nama'] as String?) ?? 'Pribadi',
        jenis: JenisProfil.dari(peta['jenis'] as String?),
      );
}

/// Daftar profil + mana yang sedang dipakai.
class DaftarProfil {
  const DaftarProfil({required this.daftar, required this.aktif});

  final List<Profil> daftar;
  final String aktif;

  /// Daftar bawaan (satu profil pribadi) — dipakai sebelum berkas dibaca.
  static const DaftarProfil bawaan = DaftarProfil(
    daftar: [Profil(id: idProfilPribadi, nama: 'Pribadi', jenis: JenisProfil.pribadi)],
    aktif: idProfilPribadi,
  );

  Profil get profilAktif => daftar.firstWhere(
        (p) => p.id == aktif,
        orElse: () => daftar.first,
      );

  String get namaBerkasAktif => namaBerkasDatabase(aktif);

  DaftarProfil salin({List<Profil>? daftar, String? aktif}) => DaftarProfil(
        daftar: daftar ?? this.daftar,
        aktif: aktif ?? this.aktif,
      );

  Map<String, Object?> kePeta() => {
        'aktif': aktif,
        'daftar': [for (final p in daftar) p.kePeta()],
      };

  static DaftarProfil dariPeta(Map<String, Object?> peta) {
    final mentah = peta['daftar'];
    final daftar = <Profil>[
      if (mentah is List)
        for (final m in mentah)
          if (m is Map) Profil.dariPeta(m.cast<String, Object?>()),
    ];
    if (daftar.isEmpty) return bawaan;
    final aktif = (peta['aktif'] as String?) ?? daftar.first.id;
    final adaAktif = daftar.any((p) => p.id == aktif);
    return DaftarProfil(
        daftar: daftar, aktif: adaAktif ? aktif : daftar.first.id);
  }
}

/// Penyimpan daftar profil (berkas `profil.json` di folder dokumen aplikasi).
class ProfilLayanan {
  ProfilLayanan({required this.folder});

  final Directory folder;

  File get berkas => File('${folder.path}${Platform.pathSeparator}profil.json');

  /// Baca daftar; berkas belum ada = daftar bawaan (tidak dibuat dulu).
  Future<DaftarProfil> muat() async {
    try {
      if (!berkas.existsSync()) return DaftarProfil.bawaan;
      final isi = jsonDecode(await berkas.readAsString());
      if (isi is! Map) return DaftarProfil.bawaan;
      return DaftarProfil.dariPeta(isi.cast<String, Object?>());
    } catch (_) {
      // Berkas rusak jangan membuat aplikasi mati: pakai daftar bawaan.
      return DaftarProfil.bawaan;
    }
  }

  Future<DaftarProfil> _simpan(DaftarProfil baru) async {
    if (!folder.existsSync()) folder.createSync(recursive: true);
    await berkas.writeAsString(jsonEncode(baru.kePeta()));
    return baru;
  }

  /// Ubah profil yang dipakai (hanya bila id-nya ada).
  Future<DaftarProfil> ganti(String id) async {
    final kini = await muat();
    if (!kini.daftar.any((p) => p.id == id)) {
      throw ArgumenProfil('Profil "$id" tidak ada.');
    }
    return _simpan(kini.salin(aktif: id));
  }

  /// Tambah profil baru. Id dibuat dari nama (huruf kecil, tanda hubung).
  Future<DaftarProfil> tambah(String nama, JenisProfil jenis) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw const ArgumenProfil('Nama profil tidak boleh kosong.');
    }
    final kini = await muat();
    if (kini.daftar.length >= 6) {
      throw const ArgumenProfil('Paling banyak 6 profil.');
    }
    var id = _jadikanId(bersih);
    if (id == idProfilPribadi) id = '$id-2';
    var putaran = 2;
    while (kini.daftar.any((p) => p.id == id)) {
      id = '${_jadikanId(bersih)}-$putaran';
      putaran++;
    }
    final baru = Profil(id: id, nama: bersih, jenis: jenis);
    return _simpan(kini.salin(daftar: [...kini.daftar, baru]));
  }

  Future<DaftarProfil> gantiNama(String id, String nama) async {
    final bersih = nama.trim();
    if (bersih.isEmpty) {
      throw const ArgumenProfil('Nama profil tidak boleh kosong.');
    }
    final kini = await muat();
    if (!kini.daftar.any((p) => p.id == id)) {
      throw ArgumenProfil('Profil "$id" tidak ada.');
    }
    return _simpan(kini.salin(
      daftar: [
        for (final p in kini.daftar)
          if (p.id == id)
            Profil(id: p.id, nama: bersih, jenis: p.jenis)
          else
            p,
      ],
    ));
  }

  /// Hapus profil (dan berkas basis datanya). Profil bawaan & profil aktif
  /// tidak boleh dihapus — pengguna diminta berpindah dulu.
  Future<DaftarProfil> hapus(String id) async {
    final kini = await muat();
    if (id == idProfilPribadi) {
      throw const ArgumenProfil('Profil "Pribadi" tidak bisa dihapus.');
    }
    if (id == kini.aktif) {
      throw const ArgumenProfil('Pindah ke profil lain dulu, baru dihapus.');
    }
    if (!kini.daftar.any((p) => p.id == id)) {
      throw ArgumenProfil('Profil "$id" tidak ada.');
    }
    _hapusBerkasProfil(id);
    return _simpan(kini.salin(
      daftar: [for (final p in kini.daftar) if (p.id != id) p],
    ));
  }

  /// Hapus berkas basis data sebuah profil (usaha terbaik; galat diabaikan).
  void _hapusBerkasProfil(String id) {
    for (final akhiran in ['.sqlite', '.sqlite-wal', '.sqlite-shm', '.sqlite-journal']) {
      final f = File(
          '${folder.path}${Platform.pathSeparator}${namaBerkasDatabase(id)}$akhiran');
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {
        // berkas mungkin sedang dipakai; bukan alasan menggagalkan tindakan
      }
    }
  }

  static String _jadikanId(String nama) {
    final dasar = nama
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return dasar.isEmpty ? 'profil' : dasar;
  }
}

/// Kesalahan argumen pada pengelolaan profil.
class ArgumenProfil implements Exception {
  const ArgumenProfil(this.pesan);
  final String pesan;

  @override
  String toString() => pesan;
}
