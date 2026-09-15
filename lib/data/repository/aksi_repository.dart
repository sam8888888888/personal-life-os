/// Repositori rantai Tujuan -> Proyek -> Tugas (FR-78) dan tugas cepat (FR-79).
///
/// Aturan yang dijaga di sini (PRD FR-78 & catatan tugas):
/// 1. Menghapus tujuan atau proyek **tidak menghapus tugas**. Tautan tugas
///    disetel null lebih dulu supaya pekerjaan pengguna tidak hilang karena
///    satu ketukan salah.
/// 2. Progres dihitung dari data di bawahnya (tugas selesai / seluruh tugas).
///    Tujuan tanpa tugas berprogres kosong — bukan 0% yang menyesatkan.
/// 3. Tugas cepat (FR-79) = tugas berdiri sendiri: `proyekId` dan `tujuanId`
///    keduanya null, sehingga bisa disimpan tanpa memilih apa pun.
///
/// Bahasa mengikuti PRD III-11: menjelaskan keadaan, tanpa menilai pengguna.
library;

import 'package:drift/drift.dart';

import '../../core/utils/waktu.dart';
import '../database/database.dart';

/// Baris tabel `tugas`.
///
/// Kode yang dihasilkan Drift menamai kelas baris `tugas` sebagai `Tuga`
/// (bentuk tunggal otomatis dari `Tugas`). Alias ini dipakai modul Aksi agar
/// nama di lapisan fitur tetap jelas, tanpa menyentuh `database.g.dart`.
typedef BarisTugas = Tuga;

/// Progres satu tujuan, dihitung dari proyek & tugas di bawahnya.
class ProgresTujuan {
  const ProgresTujuan({
    required this.totalTugas,
    required this.tugasSelesai,
    required this.totalProyek,
    required this.proyekSelesai,
  });

  /// Tugas yang terhitung: tugas langsung di tujuan ini + tugas semua
  /// proyek yang menempel pada tujuan ini.
  final int totalTugas;
  final int tugasSelesai;
  final int totalProyek;
  final int proyekSelesai;

  /// Persen tugas selesai. Tujuan tanpa tugas = 0 (layar menuliskan
  /// "Belum ada tugas", bukan "0%"), supaya angka tidak menyesatkan.
  int get persen =>
      totalTugas == 0 ? 0 : ((tugasSelesai * 100) / totalTugas).round();

  bool get adaTugas => totalTugas > 0;
}

/// Jumlah tugas satu proyek (dipakai daftar proyek FR-78).
class JumlahTugasProyek {
  const JumlahTugasProyek({required this.total, required this.selesai});

  final int total;
  final int selesai;

  int get persen => total == 0 ? 0 : ((selesai * 100) / total).round();
}

/// Repositori aksi & tujuan. Satu pintu untuk FR-78 dan FR-79.
class AksiRepository {
  AksiRepository(this.db);

  final AppDatabase db;

  /// Nomor urut pembantu supaya id unik walau beberapa baris dibuat pada
  /// mikrodetik yang sama (mis. saat impor atau uji).
  static int _urutanId = 0;

  /// Area hidup yang dipakai PRD (FR-78 / FR-82).
  static const List<String> areaHidup = <String>[
    'pribadi',
    'keluarga',
    'kerja',
    'keuangan',
    'ibadah',
    'kesehatan',
  ];

  /// Status tujuan (FR-78).
  static const List<String> statusTujuan = <String>[
    'aktif',
    'tercapai',
    'dijeda',
    'arsip',
  ];

  /// Status proyek.
  static const List<String> statusProyek = <String>[
    'aktif',
    'selesai',
    'dijeda',
    'arsip',
  ];

  /// Prioritas tugas (FR-78) — dipakai untuk urutan tampil, bukan untuk
  /// menegur pengguna.
  static const List<String> prioritasTugas = <String>[
    'biasa',
    'penting',
    'kritis',
  ];

  /// Tanggal tanpa jam (perbandingan hari kalender).
  static DateTime hariSaja(DateTime t) => DateTime(t.year, t.month, t.day);

  static String _idBaru(String awalan) {
    _urutanId++;
    return '$awalan-${waktuSekarang().microsecondsSinceEpoch}-$_urutanId';
  }

  /// Label area hidup untuk tampilan.
  static String labelArea(String area) => switch (area) {
        'pribadi' => 'Pribadi',
        'keluarga' => 'Keluarga',
        'kerja' => 'Kerja',
        'keuangan' => 'Keuangan',
        'ibadah' => 'Ibadah',
        'kesehatan' => 'Kesehatan',
        _ => area,
      };

  /// Label status untuk tampilan.
  static String labelStatus(String status) => switch (status) {
        'aktif' => 'Aktif',
        'tercapai' => 'Tercapai',
        'selesai' => 'Selesai',
        'dijeda' => 'Dijeda',
        'arsip' => 'Arsip',
        _ => status,
      };

  /// Label prioritas tugas.
  static String labelPrioritas(String prioritas) => switch (prioritas) {
        'penting' => 'Penting',
        'kritis' => 'Kritis',
        _ => 'Biasa',
      };

  /// Kalimat target tujuan: angka + satuan bila ada, teks bila ada, atau
  /// "Tanpa target angka" — bukan angka kosong yang menyesatkan.
  static String ringkasTarget(TujuanData t) {
    final bagian = <String>[];
    if (t.targetAngka != null) {
      final satuan = (t.satuan ?? '').trim();
      bagian.add(satuan.isEmpty ? '${t.targetAngka}' : '${t.targetAngka} $satuan');
    }
    if ((t.targetTeks ?? '').trim().isNotEmpty) bagian.add(t.targetTeks!.trim());
    return bagian.isEmpty ? 'Tanpa target angka' : bagian.join(' · ');
  }

  /// Jarak ke tanggal target dalam kalimat jujur (tanpa menghakimi).
  static String teksTanggalTarget(DateTime? target, DateTime sekarang) {
    if (target == null) return 'Tanpa tanggal target';
    final selisih = hariSaja(target).difference(hariSaja(sekarang)).inDays;
    if (selisih > 1) return 'Sisa $selisih hari';
    if (selisih == 1) return 'Besok';
    if (selisih == 0) return 'Hari ini';
    if (selisih == -1) return 'Sehari setelah tanggal target';
    return '${-selisih} hari setelah tanggal target';
  }

  // -------------------------------------------------------------------------
  // Tujuan (FR-78)
  // -------------------------------------------------------------------------

  /// Simpan tujuan baru atau ubah tujuan yang sudah ada.
  Future<TujuanData> simpanTujuan({
    int? id,
    required String nama,
    String area = 'pribadi',
    String? targetTeks,
    int? targetAngka,
    String? satuan,
    DateTime? tanggalTarget,
    String status = 'aktif',
    int urutan = 0,
    String? catatan,
  }) async {
    if (nama.trim().isEmpty) {
      throw ArgumentError('Nama tujuan tidak boleh kosong.');
    }
    if (!statusTujuan.contains(status)) {
      throw ArgumentError('Status tujuan harus salah satu dari $statusTujuan.');
    }
    if (!areaHidup.contains(area)) {
      throw ArgumentError('Area hidup harus salah satu dari $areaHidup.');
    }
    final sekarang = waktuSekarang();
    final idTujuan = id == null ? _idBaru('tj') : await _idTujuanLama(id);
    final isi = TujuanCompanion(
      id: id == null ? const Value.absent() : Value(id),
      idTujuan: Value(idTujuan),
      nama: Value(nama.trim()),
      area: Value(area),
      targetTeks: Value(targetTeks),
      targetAngka: Value(targetAngka),
      satuan: Value(satuan),
      tanggalTarget: Value(tanggalTarget),
      status: Value(status),
      urutan: Value(urutan),
      catatan: Value(catatan),
      selesaiPada: Value(status == 'tercapai' ? sekarang : null),
      diubahPada: Value(sekarang),
    );
    if (id == null) {
      return db.into(db.tujuan).insertReturning(
            isi,
            mode: InsertMode.insertOrReplace,
          );
    }
    await (db.update(db.tujuan)..where((t) => t.id.equals(id))).write(isi);
    return (db.select(db.tujuan)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<String> _idTujuanLama(int id) async {
    final baris = await (db.select(db.tujuan)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return baris?.idTujuan ?? _idBaru('tj');
  }

  /// Daftar tujuan; [status] null = semua status.
  Future<List<TujuanData>> ambilTujuan({String? status}) {
    final q = db.select(db.tujuan)
      ..where((t) => status == null ? const Constant(true) : t.status.equals(status))
      ..orderBy([
        (t) => OrderingTerm.asc(t.urutan),
        (t) => OrderingTerm.asc(t.nama),
      ]);
    return q.get();
  }

  Stream<List<TujuanData>> watchTujuan({String? status}) {
    final q = db.select(db.tujuan)
      ..where((t) => status == null ? const Constant(true) : t.status.equals(status))
      ..orderBy([
        (t) => OrderingTerm.asc(t.urutan),
        (t) => OrderingTerm.asc(t.nama),
      ]);
    return q.watch();
  }

  Future<TujuanData?> ambilTujuanSatu(int id) =>
      (db.select(db.tujuan)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Ubah status tujuan (mis. menandai tercapai).
  Future<TujuanData> ubahStatusTujuan(int id, String status) async {
    if (!statusTujuan.contains(status)) {
      throw ArgumentError('Status tujuan harus salah satu dari $statusTujuan.');
    }
    final sekarang = waktuSekarang();
    await (db.update(db.tujuan)..where((t) => t.id.equals(id))).write(
      TujuanCompanion(
        status: Value(status),
        selesaiPada: Value(status == 'tercapai' ? sekarang : null),
        diubahPada: Value(sekarang),
      ),
    );
    return (db.select(db.tujuan)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Hapus tujuan. Proyek dan tugas di bawahnya TIDAK dihapus: tautan
  /// `tujuanId` disetel null lebih dulu (aturan FR-78/PRD).
  ///
  /// Tugas yang menempel pada proyek tetap memakai `proyekId`-nya, karena
  /// proyeknya masih ada dan tetap bisa dikerjakan.
  Future<int> hapusTujuan(int id) async {
    final proyekAnak = await (db.select(db.proyek)
          ..where((p) => p.tujuanId.equals(id)))
        .get();
    final idProyek = proyekAnak.map((p) => p.id).toList(growable: false);
    await (db.update(db.tugas)..where((t) => t.tujuanId.equals(id)))
        .write(const TugasCompanion(tujuanId: Value(null)));
    if (idProyek.isNotEmpty) {
      await (db.update(db.proyek)..where((p) => p.tujuanId.equals(id)))
          .write(const ProyekCompanion(tujuanId: Value(null)));
    }
    return (db.delete(db.tujuan)..where((t) => t.id.equals(id))).go();
  }

  // -------------------------------------------------------------------------
  // Proyek (FR-78)
  // -------------------------------------------------------------------------

  Future<ProyekData> simpanProyek({
    int? id,
    int? tujuanId,
    required String nama,
    String? catatan,
    String status = 'aktif',
    DateTime? tenggat,
    int urutan = 0,
  }) async {
    if (nama.trim().isEmpty) {
      throw ArgumentError('Nama proyek tidak boleh kosong.');
    }
    if (!statusProyek.contains(status)) {
      throw ArgumentError('Status proyek harus salah satu dari $statusProyek.');
    }
    final sekarang = waktuSekarang();
    if (id == null) {
      return db.into(db.proyek).insertReturning(
            ProyekCompanion.insert(
              idProyek: _idBaru('pr'),
              tujuanId: Value(tujuanId),
              nama: nama.trim(),
              catatan: Value(catatan),
              status: Value(status),
              tenggat: Value(tenggat),
              urutan: Value(urutan),
              selesaiPada: Value(status == 'selesai' ? sekarang : null),
              diubahPada: Value(sekarang),
            ),
          );
    }
    final lama = await (db.select(db.proyek)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    if (lama == null) {
      throw ArgumentError('Proyek dengan id $id tidak ditemukan.');
    }
    await (db.update(db.proyek)..where((p) => p.id.equals(id))).write(
      ProyekCompanion(
        tujuanId: Value(tujuanId),
        nama: Value(nama.trim()),
        catatan: Value(catatan),
        status: Value(status),
        tenggat: Value(tenggat),
        urutan: Value(urutan),
        selesaiPada: Value(status == 'selesai' ? sekarang : null),
        diubahPada: Value(sekarang),
      ),
    );
    return (db.select(db.proyek)..where((p) => p.id.equals(id))).getSingle();
  }

  /// Daftar proyek; [tujuanId] null = semua proyek.
  Future<List<ProyekData>> ambilProyek({int? tujuanId}) {
    final q = db.select(db.proyek)
      ..where((p) =>
          tujuanId == null ? const Constant(true) : p.tujuanId.equals(tujuanId))
      ..orderBy([
        (p) => OrderingTerm.asc(p.urutan),
        (p) => OrderingTerm.asc(p.nama),
      ]);
    return q.get();
  }

  Stream<List<ProyekData>> watchProyek({int? tujuanId}) {
    final q = db.select(db.proyek)
      ..where((p) =>
          tujuanId == null ? const Constant(true) : p.tujuanId.equals(tujuanId))
      ..orderBy([
        (p) => OrderingTerm.asc(p.urutan),
        (p) => OrderingTerm.asc(p.nama),
      ]);
    return q.watch();
  }

  Future<ProyekData?> ambilProyekSatu(int id) =>
      (db.select(db.proyek)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Hapus proyek. Tugas di bawahnya TIDAK dihapus: `proyekId` disetel null
  /// lebih dulu, sehingga tugas menjadi tugas berdiri sendiri.
  Future<int> hapusProyek(int id) async {
    await (db.update(db.tugas)..where((t) => t.proyekId.equals(id)))
        .write(const TugasCompanion(proyekId: Value(null)));
    return (db.delete(db.proyek)..where((p) => p.id.equals(id))).go();
  }

  /// Jumlah tugas (selesai/total) untuk setiap proyek.
  Future<Map<int, JumlahTugasProyek>> jumlahTugasPerProyek() async {
    final semua = await (db.select(db.tugas)).get();
    final peta = <int, JumlahTugasProyek>{};
    for (final t in semua) {
      final pid = t.proyekId;
      if (pid == null) continue;
      final lama = peta[pid];
      peta[pid] = JumlahTugasProyek(
        total: (lama?.total ?? 0) + 1,
        selesai: (lama?.selesai ?? 0) + (t.selesai ? 1 : 0),
      );
    }
    return peta;
  }

  // -------------------------------------------------------------------------
  // Tugas (FR-78 & FR-79)
  // -------------------------------------------------------------------------

  Future<BarisTugas> simpanTugas({
    int? id,
    int? tujuanId,
    int? proyekId,
    required String nama,
    String? catatan,
    DateTime? jatuhTempo,
    String? jamPengingat,
    String frekuensi = 'sekali',
    int? kustomHariN,
    String prioritas = 'biasa',
    bool selesai = false,
    int urutan = 0,
  }) async {
    if (nama.trim().isEmpty) {
      throw ArgumentError('Nama tugas tidak boleh kosong.');
    }
    if (!prioritasTugas.contains(prioritas)) {
      throw ArgumentError('Prioritas harus salah satu dari $prioritasTugas.');
    }
    if (proyekId != null) {
      final p = await ambilProyekSatu(proyekId);
      if (p == null) {
        throw ArgumentError('Proyek dengan id $proyekId tidak ditemukan.');
      }
      // Tugas yang masuk ke proyek otomatis menempel pada tujuan proyek itu
      // (bila proyek belum punya tujuan, tautannya dibiarkan apa adanya).
      tujuanId ??= p.tujuanId;
    }
    final sekarang = waktuSekarang();
    if (id == null) {
      return db.into(db.tugas).insertReturning(
            TugasCompanion.insert(
              idTugas: _idBaru('tg'),
              tujuanId: Value(tujuanId),
              proyekId: Value(proyekId),
              nama: nama.trim(),
              catatan: Value(catatan),
              jatuhTempo: Value(jatuhTempo),
              jamPengingat: Value(jamPengingat),
              frekuensi: Value(frekuensi),
              kustomHariN: Value(kustomHariN),
              prioritas: Value(prioritas),
              selesai: Value(selesai),
              selesaiPada: Value(selesai ? sekarang : null),
              urutan: Value(urutan),
              diubahPada: Value(sekarang),
            ),
          );
    }
    final lama = await (db.select(db.tugas)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (lama == null) {
      throw ArgumentError('Tugas dengan id $id tidak ditemukan.');
    }
    await (db.update(db.tugas)..where((t) => t.id.equals(id))).write(
      TugasCompanion(
        tujuanId: Value(tujuanId),
        proyekId: Value(proyekId),
        nama: Value(nama.trim()),
        catatan: Value(catatan),
        jatuhTempo: Value(jatuhTempo),
        jamPengingat: Value(jamPengingat),
        frekuensi: Value(frekuensi),
        kustomHariN: Value(kustomHariN),
        prioritas: Value(prioritas),
        selesai: Value(selesai),
        selesaiPada: Value(selesai ? (lama.selesaiPada ?? sekarang) : null),
        urutan: Value(urutan),
        diubahPada: Value(sekarang),
      ),
    );
    return (db.select(db.tugas)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Simpan tugas cepat (FR-79): berdiri sendiri, tanpa proyek & tanpa tujuan.
  Future<BarisTugas> simpanTugasCepat(
    String nama, {
    DateTime? jatuhTempo,
    String? jamPengingat,
    String frekuensi = 'sekali',
    String prioritas = 'biasa',
  }) =>
      simpanTugas(
        nama: nama,
        jatuhTempo: jatuhTempo,
        jamPengingat: jamPengingat,
        frekuensi: frekuensi,
        prioritas: prioritas,
      );

  /// Daftar tugas; saringan null = tanpa saringan.
  Future<List<BarisTugas>> ambilTugas({
    int? proyekId,
    int? tujuanId,
    bool? selesai,
    bool cepatSaja = false,
  }) async {
    final q = db.select(db.tugas)
      ..where((t) {
        Expression<bool> syarat = const Constant(true);
        if (proyekId != null) syarat = syarat & t.proyekId.equals(proyekId);
        if (tujuanId != null) syarat = syarat & t.tujuanId.equals(tujuanId);
        if (selesai != null) syarat = syarat & t.selesai.equals(selesai);
        if (cepatSaja) {
          syarat = syarat & t.proyekId.isNull() & t.tujuanId.isNull();
        }
        return syarat;
      })
      ..orderBy([
        (t) => OrderingTerm.asc(t.urutan),
        (t) => OrderingTerm.asc(t.nama),
      ]);
    return q.get();
  }

  Stream<List<BarisTugas>> watchTugas({
    int? proyekId,
    int? tujuanId,
    bool? selesai,
  }) {
    final q = db.select(db.tugas)
      ..where((t) {
        Expression<bool> syarat = const Constant(true);
        if (proyekId != null) syarat = syarat & t.proyekId.equals(proyekId);
        if (tujuanId != null) syarat = syarat & t.tujuanId.equals(tujuanId);
        if (selesai != null) syarat = syarat & t.selesai.equals(selesai);
        return syarat;
      })
      ..orderBy([
        (t) => OrderingTerm.asc(t.urutan),
        (t) => OrderingTerm.asc(t.nama),
      ]);
    return q.watch();
  }

  /// Tandai tugas selesai / batal selesai.
  Future<BarisTugas> tandaiSelesai(int id, {bool selesai = true}) async {
    await (db.update(db.tugas)..where((t) => t.id.equals(id))).write(
      TugasCompanion(
        selesai: Value(selesai),
        selesaiPada: Value(selesai ? waktuSekarang() : null),
        diubahPada: Value(waktuSekarang()),
      ),
    );
    return (db.select(db.tugas)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> hapusTugas(int id) =>
      (db.delete(db.tugas)..where((t) => t.id.equals(id))).go();

  /// Tugas cepat yang masih perlu dikerjakan hari ini (FR-79).
  ///
  /// Isi: tugas berdiri sendiri, belum selesai, dan jatuh temponya kosong
  /// atau paling lambat hari ini. Urut: yang punya jatuh tempo lebih dulu,
  /// lalu urutan, lalu nama.
  Future<List<BarisTugas>> tugasCepatHariIni({DateTime? sekarang}) async {
    final kini = hariSaja(sekarang ?? waktuSekarang());
    final cepat = await ambilTugas(selesai: false, cepatSaja: true);
    final hasil = cepat
        .where((t) =>
            t.jatuhTempo == null || !hariSaja(t.jatuhTempo!).isAfter(kini))
        .toList()
      ..sort((a, b) {
        final ka = a.jatuhTempo;
        final kb = b.jatuhTempo;
        if (ka == null && kb == null) {
          return a.urutan != b.urutan ? a.urutan - b.urutan : a.nama.compareTo(b.nama);
        }
        if (ka == null) return 1;
        if (kb == null) return -1;
        final c = ka.compareTo(kb);
        return c != 0 ? c : a.nama.compareTo(b.nama);
      });
    return hasil;
  }

  // -------------------------------------------------------------------------
  // Progres (FR-78)
  // -------------------------------------------------------------------------

  /// Progres satu tujuan: tugas langsung + tugas semua proyeknya.
  Future<ProgresTujuan> progresTujuan(int tujuanId) async {
    final proyek = await ambilProyek(tujuanId: tujuanId);
    final idProyek = proyek.map((p) => p.id).toSet();
    final tugas = await (db.select(db.tugas)).get();
    final milik = tugas
        .where((t) =>
            t.tujuanId == tujuanId ||
            (t.proyekId != null && idProyek.contains(t.proyekId)))
        .toList();
    return ProgresTujuan(
      totalTugas: milik.length,
      tugasSelesai: milik.where((t) => t.selesai).length,
      totalProyek: proyek.length,
      proyekSelesai: proyek.where((p) => p.status == 'selesai').length,
    );
  }

  /// Progres semua tujuan sekaligus (satu kali baca, dipakai daftar tujuan).
  Future<Map<int, ProgresTujuan>> progresSemuaTujuan() async {
    final tujuan = await ambilTujuan();
    final proyek = await ambilProyek();
    final tugas = await (db.select(db.tugas)).get();
    final proyekPerTujuan = <int, List<ProyekData>>{};
    for (final p in proyek) {
      final tid = p.tujuanId;
      if (tid == null) continue;
      proyekPerTujuan.putIfAbsent(tid, () => <ProyekData>[]).add(p);
    }
    final hasil = <int, ProgresTujuan>{};
    for (final t in tujuan) {
      final anak = proyekPerTujuan[t.id] ?? const <ProyekData>[];
      final idProyek = anak.map((p) => p.id).toSet();
      final milik = tugas
          .where((g) =>
              g.tujuanId == t.id ||
              (g.proyekId != null && idProyek.contains(g.proyekId)))
          .toList();
      hasil[t.id] = ProgresTujuan(
        totalTugas: milik.length,
        tugasSelesai: milik.where((g) => g.selesai).length,
        totalProyek: anak.length,
        proyekSelesai: anak.where((p) => p.status == 'selesai').length,
      );
    }
    return hasil;
  }
}
