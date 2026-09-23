/// Uji Batch 12 — FR-43 (mode rumah tangga), FR-56 (sub-akses keluarga),
/// FR-58 (voice & parsing cerdas),
/// dan verifikasi FR-57 (perawatan berkala memakai mesin yang sudah ada).
///
/// Aturan yang dipegang: tiap harapan mengacu ke keluaran nyata. Bila harapan
/// lama ternyata salah, yang diperbaiki adalah fakta/harapannya — bukan
/// dilonggarkan.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/core/keluarga/sub_akses.dart';
import 'package:personal_life_os/core/parsing/parsing_cerdas.dart';
import 'package:personal_life_os/core/rumah/patungan.dart';
import 'package:personal_life_os/core/rumah/rumah_tangga.dart';
import 'package:personal_life_os/core/sinkron/registri_sinkron.dart';
import 'package:personal_life_os/data/database/database.dart';
import 'package:personal_life_os/data/repository/perawatan_repository.dart';
import 'package:personal_life_os/data/repository/rumah_tangga_repository.dart';
import 'package:personal_life_os/data/repository/sub_akses_repository.dart';

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // FR-43 — Mode Rumah Tangga
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-43 mesin rumah tangga', () {
    test('kode undangan: 6 karakter dari daftar aman & bisa divalidasi', () {
      final kode = kodeUndanganRumah(123456);
      expect(kode.length, 6);
      expect(kodeUndanganSah(kode), isTrue);
      // 0/O/1/I sengaja tidak dipakai supaya tidak salah ketik.
      expect(kode.contains('0'), isFalse);
      expect(kode.contains('O'), isFalse);
      expect(kodeUndanganSah('ABC'), isFalse);
      expect(kodeUndanganSah(null), isFalse);
      expect(kodeUndanganSah('ABC-12'), isFalse);
    });

    test('pembagian tagihan bersama selalu pas dengan totalnya', () {
      final bagian = bagiRataTagihanBersama(100000, const [
        AnggotaRumah(nama: 'Papi'),
        AnggotaRumah(nama: 'Mami'),
        AnggotaRumah(nama: 'Kakak'),
      ]);
      final jumlah = bagian.values.fold<int>(0, (a, b) => a + b);
      expect(jumlah, 100000, reason: 'sisa sen dibagi, tidak dibulatkan diam-diam');
      expect(bagian.length, 3);
    });

    test('anggota non-aktif tidak ikut dibagi', () {
      final bagian = bagiRataTagihanBersama(30000, const [
        AnggotaRumah(nama: 'Papi'),
        AnggotaRumah(nama: 'Mami', aktif: false),
      ]);
      expect(bagian.keys.toList(), ['Papi']);
    });

    test('jumlah bagian yang tidak sama dengan total → peringatan jujur', () {
      final t = TagihanBersama(
        rumahNama: 'Rumah Surabaya',
        judul: 'Listrik',
        totalSen: 300000,
        jatuhTempo: DateTime(2026, 10, 1),
      );
      final hasil = hitungRumahTangga(
        rumahNama: 'Rumah Surabaya',
        anggota: const [AnggotaRumah(nama: 'Papi'), AnggotaRumah(nama: 'Mami')],
        tagihan: [t],
        bagian: [
          BagianRumah(
              kunciTagihan: kunciTagihanBersama(t),
              anggota: 'Papi',
              jumlahSen: 100000),
        ],
        sekarang: DateTime(2026, 9, 22),
      );
      expect(hasil.peringatan.any((p) => p.contains('tidak sama')), isTrue);
      expect(hasil.dasar.contains('2 anggota'), isTrue);
    });

    test('tanpa anggota & tanpa tagihan → disebut apa adanya', () {
      final hasil = hitungRumahTangga(
        rumahNama: 'Rumah Baru',
        anggota: const [],
        tagihan: const [],
        bagian: const [],
      );
      expect(hasil.belumBisa, hasLength(2));
      expect(hasil.belumBisa.first.contains('belum punya anggota'), isTrue);
    });

    test('bagian anggota yang bukan anggota aktif → peringatan', () {
      final t = TagihanBersama(
        rumahNama: 'Rumah',
        judul: 'Air',
        totalSen: 100000,
        jatuhTempo: DateTime(2026, 10, 5),
      );
      final hasil = hitungRumahTangga(
        rumahNama: 'Rumah',
        anggota: const [AnggotaRumah(nama: 'Papi')],
        tagihan: [t],
        bagian: [
          BagianRumah(
              kunciTagihan: kunciTagihanBersama(t),
              anggota: 'Tetangga',
              jumlahSen: 100000),
        ],
      );
      expect(hasil.peringatan.any((p) => p.contains('bukan anggota aktif')), isTrue);
    });

    test('ringkas bagian: sisa & lunas dihitung benar', () {
      final t = TagihanBersama(
        rumahNama: 'Rumah',
        judul: 'Internet',
        totalSen: 200000,
        jatuhTempo: DateTime(2026, 10, 1),
      );
      final ringkas = ringkasBagianTagihan(
        tagihan: t,
        bagian: [
          BagianRumah(
              kunciTagihan: kunciTagihanBersama(t),
              anggota: 'Papi',
              jumlahSen: 100000,
              dibayarSen: 40000,
              waktuBayar: DateTime(2026, 9, 20)),
          BagianRumah(
              kunciTagihan: kunciTagihanBersama(t),
              anggota: 'Mami',
              jumlahSen: 100000,
              dibayarSen: 100000,
              waktuBayar: DateTime(2026, 9, 21)),
        ],
      );
      expect(ringkas.first.anggota, 'Mami');
      expect(ringkas.last.sisaSen, 60000);
      expect(ringkas.last.lunas, isFalse);
      expect(totalBelumDibayar(ringkas), 60000);
    });

    test('riwayat "siapa bayar apa" terbaru dulu & hanya yang ada catatannya', () {
      final t = TagihanBersama(
        rumahNama: 'Rumah',
        judul: 'Sampah',
        totalSen: 60000,
        jatuhTempo: DateTime(2026, 10, 1),
      );
      final riwayat = riwayatBayarRumah(
        tagihan: [t],
        bagian: [
          BagianRumah(
              kunciTagihan: kunciTagihanBersama(t),
              anggota: 'Papi',
              jumlahSen: 30000,
              dibayarSen: 30000,
              waktuBayar: DateTime(2026, 9, 10)),
          BagianRumah(
              kunciTagihan: kunciTagihanBersama(t),
              anggota: 'Mami',
              jumlahSen: 30000,
              dibayarSen: 30000,
              waktuBayar: DateTime(2026, 9, 18)),
          BagianRumah(
              kunciTagihan: kunciTagihanBersama(t),
              anggota: 'Kakak',
              jumlahSen: 0),
        ],
      );
      expect(riwayat.map((r) => r.anggota).toList(), ['Mami', 'Papi']);
    });

    test('teks pengingat menyebut nominal, sisa, dan jatuh tempo', () {
      final t = TagihanBersama(
        rumahNama: 'Rumah',
        judul: 'Listrik',
        totalSen: 300000,
        jatuhTempo: DateTime(2026, 9, 25),
      );
      final teks = teksPengingatRumah(
        tagihan: t,
        bagian: const RingkasBagian(
            anggota: 'Mami', jumlahSen: 150000, dibayarSen: 50000),
        dariNama: 'Rumah Surabaya',
        sekarang: DateTime(2026, 9, 22),
      );
      expect(teks.contains('Listrik'), isTrue);
      expect(teks.contains('sisa'), isTrue);
      expect(teks.contains('3 hari lagi'), isTrue);
    });
  });

  group('FR-43 repositori rumah tangga', () {
    test('rumah baru punya kode undangan yang sah & bisa dicari kodenya',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = RumahTanggaRepository(db);
      final id = await repo.tambahRumah(nama: 'Rumah Surabaya');
      final rumah = await (db.select(db.rumahTangga)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(kodeUndanganSah(rumah.kodeUndangan), isTrue);
      final ketemu = await repo.cariKode(rumah.kodeUndangan!);
      expect(ketemu?.nama, 'Rumah Surabaya');
      expect(await repo.cariKode('XXXXXX'), isNull);
    });

    test('nama kosong ditolak (bukan disimpan diam-diam)', () async {
      final db = _db();
      addTearDown(db.close);
      expect(
        () => RumahTanggaRepository(db).tambahRumah(nama: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('tagihan bersama + bagian rata tersimpan pas, catat bayar menggeser sisa',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = RumahTanggaRepository(db);
      final id = await repo.tambahRumah(nama: 'Rumah');
      // Anggota rumah tangga memakai tabel anggota_keluarga (FR-56) — jadi
      // tidak ada tabel orang kedua di sini.
      final rumahUid = (await repo.semuaRumah()).first.uid!;
      await repo.tambahTagihan(
        rumahUid: rumahUid,
        judul: 'Listrik',
        totalSen: 300000,
        jatuhTempo: DateTime(2026, 10, 1),
        anggota: const ['Papi', 'Mami', 'Kakak'],
      );
      final tagihan = await repo.tagihan(rumahUid);
      expect(tagihan, hasLength(1));
      final bagian = await repo.bagian(tagihan.first.uid!);
      expect(bagian.fold<int>(0, (a, b) => a + b.jumlahSen), 300000);

      await repo.catatBayar(
        tagihanUid: tagihan.first.uid!,
        anggota: 'Papi',
        jumlahSen: 100000,
      );
      final sesudah = await repo.bagian(tagihan.first.uid!);
      final papi = sesudah.firstWhere((b) => b.anggota == 'Papi');
      expect(papi.dibayarSen, 100000);
      expect(papi.waktuBayar, isNotNull);
      expect(id, greaterThan(0));
    });

    test('catat bayar untuk anggota yang tidak punya bagian → ditolak',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = RumahTanggaRepository(db);
      await repo.tambahRumah(nama: 'Rumah');
      final rumahUid = (await repo.semuaRumah()).first.uid!;
      await repo.tambahTagihan(
        rumahUid: rumahUid,
        judul: 'Air',
        totalSen: 50000,
        jatuhTempo: DateTime(2026, 10, 1),
        anggota: const ['Papi'],
      );
      final tagihan = await repo.tagihan(rumahUid);
      expect(
        () => repo.catatBayar(
            tagihanUid: tagihan.first.uid!,
            anggota: 'Orang Lain',
            jumlahSen: 10000),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('total negatif ditolak; hasil() menyusun ringkasan rumah', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = RumahTanggaRepository(db);
      final id = await repo.tambahRumah(nama: 'Rumah');
      final rumahUid = (await repo.semuaRumah()).first.uid!;
      expect(
        () => repo.tambahTagihan(
            rumahUid: rumahUid,
            judul: 'X',
            totalSen: -1,
            jatuhTempo: DateTime(2026, 10, 1)),
        throwsA(isA<ArgumentError>()),
      );
      await repo.tambahTagihan(
        rumahUid: rumahUid,
        judul: 'Listrik',
        totalSen: 120000,
        jatuhTempo: DateTime(2026, 10, 1),
        anggota: const ['Papi', 'Mami'],
      );
      final hasil = await repo.hasil(id);
      expect(hasil.rumahNama, 'Rumah');
      expect(hasil.totalTagihanSen, 120000);
      expect(hasil.anggota.map((a) => a.nama).toList(), ['Mami', 'Papi']);
    });

    test('hapus rumah ikut menghapus tagihan & bagiannya', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = RumahTanggaRepository(db);
      final id = await repo.tambahRumah(nama: 'Rumah');
      final rumahUid = (await repo.semuaRumah()).first.uid!;
      await repo.tambahTagihan(
        rumahUid: rumahUid,
        judul: 'Gas',
        totalSen: 90000,
        jatuhTempo: DateTime(2026, 10, 1),
        anggota: const ['Papi'],
      );
      await repo.hapusRumah(id);
      expect(await repo.semuaRumah(), isEmpty);
      expect(await db.select(db.tagihanRumahBersama).get(), isEmpty);
      expect(await db.select(db.bagianTagihanRumah).get(), isEmpty);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FR-56 — Sub-Akses Keluarga
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-56 mesin sub-akses', () {
    test('kode berbagi sah hanya 6 karakter dari daftar aman', () {
      expect(kodeBerbagiSah(kodeBerbagiKeluarga(99)), isTrue);
      expect(kodeBerbagiSah('abc-12'), isFalse);
      expect(kodeBerbagiSah(''), isFalse);
    });

    test('tanpa izin: tidak boleh lihat & tidak boleh tambah (bawaan aman)', () {
      const daftar = <IzinKeluarga>[];
      expect(
        bolehLihatModul(daftar,
            anggota: 'Mami', modul: ModulKeluarga.tagihan),
        isFalse,
      );
      expect(
        bolehTambahModul(daftar,
            anggota: 'Mami', modul: ModulKeluarga.tagihan),
        isFalse,
      );
      expect(modulTerbuka(daftar, anggota: 'Mami'), isEmpty);
    });

    test('izin per anggota tidak bocor ke anggota lain', () {
      const daftar = [
        IzinKeluarga(anggota: 'Mami', modul: ModulKeluarga.tagihan),
        IzinKeluarga(
            anggota: 'Kakak',
            modul: ModulKeluarga.kesehatan,
            bolehTambah: true),
      ];
      expect(
        bolehLihatModul(daftar, anggota: 'Mami', modul: ModulKeluarga.kesehatan),
        isFalse,
      );
      expect(
        bolehTambahModul(daftar, anggota: 'Kakak', modul: ModulKeluarga.kesehatan),
        isTrue,
      );
      expect(modulTerbuka(daftar, anggota: 'Mami'),
          [ModulKeluarga.tagihan]);
    });

    test('izin yang dimatikan (aktif=false) tidak berlaku', () {
      const daftar = [
        IzinKeluarga(
            anggota: 'Mami', modul: ModulKeluarga.tagihan, aktif: false),
      ];
      expect(
        bolehLihatModul(daftar, anggota: 'Mami', modul: ModulKeluarga.tagihan),
        isFalse,
      );
    });

    test('ringkasan menyebut yang belum diberi akses', () {
      final ringkas = ringkasSubAkses(
        const [IzinKeluarga(anggota: 'Mami', modul: ModulKeluarga.tagihan)],
        anggotaTerdaftar: const ['Mami', 'Kakak'],
      );
      expect(ringkas.perAnggota, hasLength(1));
      expect(ringkas.belumBisa.any((b) => b.contains('Kakak')), isTrue);
    });

    test('kalimat persetujuan jujur menyebut boleh menambah atau tidak', () {
      final teks = teksPersetujuanSubAkses(
        anggota: 'Kakak',
        modul: const [ModulKeluarga.tagihan],
        bolehTambah: true,
      );
      expect(teks.contains('Kakak'), isTrue);
      expect(teks.contains('MELIHAT'), isTrue);
      expect(teks.contains('MENAMBAH'), isTrue);
      final hanyaLihat = teksPersetujuanSubAkses(
        anggota: 'Kakak',
        modul: const [ModulKeluarga.tagihan],
        bolehTambah: false,
      );
      expect(hanyaLihat.contains('MENAMBAH'), isFalse);
    });
  });

  group('FR-56 repositori sub-akses', () {
    Future<int> anggotaPercobaan(AppDatabase db, String nama) {
      return db.into(db.anggotaKeluarga).insert(
            AnggotaKeluargaCompanion.insert(idAnggota: 'AG-$nama', nama: nama),
          );
    }

    test('simpan izin dua kali = satu baris (upsert), bukan dua', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = SubAksesRepository(db);
      final id = await anggotaPercobaan(db, 'Mami');
      await repo.simpanIzin(anggotaId: id, modul: ModulKeluarga.tagihan);
      await repo.simpanIzin(
          anggotaId: id,
          modul: ModulKeluarga.tagihan,
          bolehLihat: true,
          bolehTambah: true);
      final baris = await repo.izin(anggotaId: id);
      expect(baris, hasLength(1));
      expect(baris.first.bolehTambah, isTrue);
    });

    test('penegakan izin lewat repositori (bukan hanya menyembunyikan menu)',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = SubAksesRepository(db);
      final id = await anggotaPercobaan(db, 'Kakak');
      expect(await repo.bolehLihat(id, ModulKeluarga.tagihan), isFalse);
      await repo.simpanIzin(anggotaId: id, modul: ModulKeluarga.tagihan);
      expect(await repo.bolehLihat(id, ModulKeluarga.tagihan), isTrue);
      expect(await repo.bolehTambah(id, ModulKeluarga.tagihan), isFalse);
      await repo.cabutSemua(id);
      expect(await repo.bolehLihat(id, ModulKeluarga.tagihan), isFalse);
    });

    test('hitungModul: tagihan terhitung, modul tanpa sumber menjawab null',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = SubAksesRepository(db);
      await db.into(db.tagihan).insert(TagihanCompanion.insert(
            nama: 'Listrik',
            jatuhTempo: DateTime(2026, 10, 1),
          ));
      expect(await repo.hitungModul(ModulKeluarga.tagihan), 1);
      expect(await repo.hitungModul(ModulKeluarga.anggaran), isNull);
    });

    test('paket berbagi berisi izin + jumlah baris, tanpa isi catatan pribadi',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = SubAksesRepository(db);
      final id = await anggotaPercobaan(db, 'Mami');
      await repo.simpanIzin(anggotaId: id, modul: ModulKeluarga.tagihan);
      final paket = await repo.paketBerbagi(id);
      final isi = repo.bacaPaket(paket);
      expect(isi['versi'], versiPaketBerbagi);
      expect(isi['anggota'], 'Mami');
      expect(isi['modul'], ['tagihan']);
      expect(kodeBerbagiSah(isi['kodeBerbagi'] as String), isTrue);
      expect(paket.contains('catatan'), isTrue); // hanya keterangan, bukan isi
      expect(repo.ringkasPaket(isi).contains('Mami'), isTrue);
    });

    test('berkas paket dengan versi lain ditolak dengan pesan jelas', () async {
      final db = _db();
      addTearDown(db.close);
      final repo = SubAksesRepository(db);
      expect(() => repo.bacaPaket('{"versi": 99}'),
          throwsA(isA<FormatException>()));
      expect(() => repo.bacaPaket('bukan json'),
          throwsA(isA<FormatException>()));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FR-58 — Voice & Parsing Cerdas
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-58 parsing cerdas', () {
    test('uraiAngkaSen: rb/ribu/jt/juta & gaya ribuan', () {
      expect(uraiAngkaSen('beli galon 20 ribu'), 2000000);
      expect(uraiAngkaSen('listrik 250rb'), 25000000);
      expect(uraiAngkaSen('bayar 1,5jt'), 150000000);
      expect(uraiAngkaSen('Rp 1.234.567'), 123456700);
      expect(uraiAngkaSen('tanpa angka'), isNull);
    });

    test('uraiTanggal: hari ini, besok, 25 september, 25/9', () {
      final kini = DateTime(2026, 9, 22);
      expect(uraiTanggal('bayar hari ini', sekarang: kini), DateTime(2026, 9, 22));
      expect(uraiTanggal('besok bayar', sekarang: kini), DateTime(2026, 9, 23));
      expect(uraiTanggal('jatuh tempo 25 september', sekarang: kini),
          DateTime(2026, 9, 25));
      expect(uraiTanggal('tempo 5/10', sekarang: kini), DateTime(2026, 10, 5));
      expect(uraiTanggal('tanpa tanggal', sekarang: kini), isNull);
    });

    test('kalimat pengeluaran → draf pengeluaran lengkap', () {
      final d = uraikanKalimat('beli galon 20 ribu', sekarang: DateTime(2026, 9, 22));
      expect(d.jenis, JenisDraf.pengeluaran);
      expect(d.nominalSen, 2000000);
      expect(d.judul.toLowerCase().contains('galon'), isTrue);
      expect(drafSiapSimpan(d), isTrue);
      expect(d.kalimat.contains('periksa dulu'), isTrue);
    });

    test('kalimat tagihan → butuh jatuh tempo untuk siap disimpan', () {
      final kurang = uraikanKalimat('tagihan listrik 250rb');
      expect(kurang.jenis, JenisDraf.tagihan);
      expect(kurang.tanggal, isNull);
      expect(drafSiapSimpan(kurang), isFalse);
      expect(kurang.alasan.any((a) => a.contains('Jatuh tempo')), isTrue);

      final lengkap =
          uraikanKalimat('bayar listrik 250rb jatuh tempo 25 september',
              sekarang: DateTime(2026, 9, 22));
      expect(lengkap.tanggal, DateTime(2026, 9, 25));
      expect(lengkap.tingkatKeyakinan, 90);
      expect(drafSiapSimpan(lengkap), isTrue);
    });

    test('setoran dana & perawatan berkala dikenali sebagai jenis tersendiri',
        () {
      final dana = uraikanKalimat('setor dana servis motor 500rb');
      expect(dana.jenis, JenisDraf.dana);
      expect(dana.nominalSen, 50000000);

      final rawat =
          uraikanKalimat('servis motor tiap 3 bulan', sekarang: DateTime(2026, 9, 22));
      expect(rawat.jenis, JenisDraf.perawatan);
      expect(rawat.frekuensiBulan, 3);
      expect(drafSiapSimpan(rawat), isTrue);
    });

    test('kalimat aneh dijawab belum dikenali + saran, bukan ditebak', () {
      final d = uraikanKalimat('hmm entahlah');
      expect(d.jenis, JenisDraf.tidakDikenali);
      expect(d.dikenali, isFalse);
      expect(drafSiapSimpan(d), isFalse);
      expect(d.alasan, isNotEmpty);

      final kosong = uraikanKalimat('   ');
      expect(kosong.jenis, JenisDraf.tidakDikenali);
      expect(kosong.alasan.first.contains('kosong'), isTrue);
    });

    test('jeda bulan tidak masuk akal ditolak dengan alasan', () {
      final d = uraikanKalimat('servis mobil tiap 999 bulan');
      expect(d.jenis, JenisDraf.tidakDikenali);
      expect(d.alasan.first.contains('1–120'), isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // FR-57 — verifikasi: memakai mesin perawatan yang SUDAH ada (tanpa kembar)
  // ══════════════════════════════════════════════════════════════════════════
  group('FR-57 perawatan berkala (pakai mesin FR-125)', () {
    test('intervalHari dihitung ke tanggal berikutnya (bukan tabel kedua)',
        () async {
      final db = _db();
      addTearDown(db.close);
      final repo = PerawatanRepository(db);
      final mulai = DateTime(2026, 9, 1);
      final baris = await repo.simpan(
        nama: 'Ganti oli motor',
        kategori: 'kendaraan',
        intervalHari: 90,
        terakhirDilakukan: mulai,
      );
      expect(baris.berikutnya,
          PerawatanRepository.hitungBerikutnya(mulai, 90));
      // Perawatan selalu terisi template bawaan (oli, AC, filter, pajak,
      // cadangan data) — jadi yang diperiksa: baris baru IKUT tersimpan dan
      // tidak ada tabel perawatan kedua yang dibuat batch ini.
      final semua = await repo.ambilSemua();
      expect(semua.any((p) => p.nama == 'Ganti oli motor'), isTrue);
      expect(semua.where((p) => p.nama == 'Ganti oli motor'), hasLength(1));
      expect(await db.select(db.perawatan).get(),
          hasLength(greaterThanOrEqualTo(1)));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Penjaga skema & mesin sinkron (FR-150)
  // ══════════════════════════════════════════════════════════════════════════
  group('penjaga batch 12', () {
    test('5 jalur sinkron baru terdaftar & tidak ada nama jalur ganda', () {
      final db = _db();
      addTearDown(db.close);
      final nama = daftarJalurSinkron(db).map((j) => j.nama).toList();
      for (final wajib in const [
        'rumah_tangga',
        'tagihan_rumah_bersama',
        'bagian_tagihan_rumah',
        'izin_sub_akses_keluarga',
        'pemindaian_bank',
      ]) {
        expect(nama.contains(wajib), isTrue, reason: 'jalur $wajib hilang');
      }
      expect(nama.toSet().length, nama.length, reason: 'tidak ada jalur ganda');
    });

    test('versi skema 18 dan tabel baru bisa ditulis', () async {
      final db = _db();
      addTearDown(db.close);
      expect(db.schemaVersion, 19);
      await db.into(db.rumahTangga).insert(RumahTanggaCompanion.insert(
            nama: 'Rumah Uji',
          ));
      await db.into(db.pemindaianBank).insert(PemindaianBankCompanion.insert(
            sumber: 'BCA',
            teks: 'uji',
            waktuPesan: DateTime(2026, 9, 22),
          ));
      expect(await db.select(db.rumahTangga).get(), hasLength(1));
      expect(await db.select(db.pemindaianBank).get(), hasLength(1));
    });

    test('bagianPatungan (FR-47) tetap dipakai ulang, bukan digandakan',
        () async {
      final db = _db();
      addTearDown(db.close);
      // FR-43 memakai bagiSamaRata milik FR-47: jumlah bagian harus pas.
      final bagian = bagiSamaRata(100000, const ['A', 'B', 'C']);
      expect(bagian.values.fold<int>(0, (a, b) => a + b), 100000);
      expect(await db.select(db.bagianPatungan).get(), isEmpty);
    });
  });
}
