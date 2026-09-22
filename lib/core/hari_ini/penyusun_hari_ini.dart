/// Aturan susun Modul 0 (FR-60 … FR-62) — fungsi murni, tanpa Flutter.
///
/// Semua keputusan "warna, 6 baris, teks alasan, angka pilar" ada di sini agar
/// bisa diuji unit tanpa membuka layar (§7.5 rancangan TODAY).
library;

import '../utils/uang_utils.dart';
import 'model_hari_ini.dart';
import 'tagihan_ringkas.dart';

/// Batas yang dipakai Modul 0 (jangan disebar sebagai angka liar di layar).
const int maksBarisAgenda = 6;
const int maksButirPerhatian = 5;
const int batasDekatHari = 3;
const int batasMingguHari = 7;
const int batasDokumenHari = 30;
const int jumlahWaktuWajib = 5;

const List<String> namaBulanSingkat = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Tanggal pendek Indonesia tanpa intl: "14 Sep".
String tanggalSingkat(DateTime t) => '${t.day} ${namaBulanSingkat[t.month - 1]}';

/// Selisih hari kalender dari tanggal sipil [sekarang] ke [target].
int sisaHariKe(DateTime sekarang, DateTime target) {
  final a = DateTime(sekarang.year, sekarang.month, sekarang.day);
  final b = DateTime(target.year, target.month, target.day);
  return b.difference(a).inDays;
}

/// Warna butir menurut sisa hari.
///
/// Rancangan hanya menyebut "kuning" untuk 4–7 hari; rentang 0–3 hari kami
/// beri `oranye` supaya bisa dibedakan dari 4–7 hari (dicatat di laporan).
TingkatPrioritas tingkatJatuhTempo(int sisa) {
  if (sisa < 0) return TingkatPrioritas.merah;
  if (sisa <= batasDekatHari) return TingkatPrioritas.oranye;
  if (sisa <= batasMingguHari) return TingkatPrioritas.kuning;
  return TingkatPrioritas.hijau;
}

/// Kalimat alasan berangka untuk satu tagihan.
String teksAlasanTagihan(TagihanRingkas t, DateTime sekarang) {
  final sisa = sisaHariKe(sekarang, t.jatuhTempo);
  final nominal = t.jumlahSen == null ? '' : ' ${fmtRpDariSen(t.jumlahSen!)}';
  final nama = '${t.dokumen ? 'Dokumen' : 'Tagihan'} ${t.nama}$nominal';
  if (sisa < 0) return '$nama terlambat ${-sisa} hari';
  if (sisa == 0) return '$nama jatuh tempo hari ini (${tanggalSingkat(t.jatuhTempo)})';
  if (sisa == 1) return '$nama jatuh tempo besok (${tanggalSingkat(t.jatuhTempo)})';
  return '$nama jatuh tempo $sisa hari lagi (${tanggalSingkat(t.jatuhTempo)})';
}

/// Butir agenda "hari ini": hal yang menuntut tindakan dalam ≤3 hari, termasuk
/// yang sudah lewat. Butir >3 hari ditampilkan di tab Kerja (7 hari ke depan).
List<ButirAgenda> agendaHariIni(List<TagihanRingkas> semua, DateTime sekarang) {
  final butir = <ButirAgenda>[];
  for (final t in semua) {
    if (!t.menuntutTindakan) continue;
    final sisa = sisaHariKe(sekarang, t.jatuhTempo);
    final batas = t.dokumen ? batasDokumenHari : batasDekatHari;
    if (sisa > batas) continue;
    butir.add(ButirAgenda(
      id: 'tagihan-${t.id}',
      jenis: t.dokumen ? JenisButir.dokumen : JenisButir.tagihan,
      judul: t.nama,
      waktu: t.jatuhTempo,
      nominalSen: t.jumlahSen,
      tingkat: tingkatJatuhTempo(sisa),
      alasan: teksAlasanTagihan(t, sekarang),
      rute: '/ubah/${t.id}',
    ));
  }
  return peringkatEnamBaris(butir, maks: 999);
}

/// Urutkan butir lalu ambil [maks] teratas (FR-60: 6 baris).
List<ButirAgenda> peringkatEnamBaris(List<ButirAgenda> daftar, {int maks = maksBarisAgenda}) {
  final urut = [...daftar]..sort((a, b) {
      final t = a.tingkat.urutan.compareTo(b.tingkat.urutan);
      if (t != 0) return t;
      final wa = a.waktu;
      final wb = b.waktu;
      if (wa != null && wb != null) {
        final w = wa.compareTo(wb);
        if (w != 0) return w;
      } else if (wa != null) {
        return -1;
      } else if (wb != null) {
        return 1;
      }
      return a.id.compareTo(b.id);
    });
  return urut.length > maks ? urut.sublist(0, maks) : urut;
}

/// Tagihan aktif yang jatuh tempo 0–7 hari lagi (dipakai tab Kerja & briefing).
List<ButirAgenda> tagihanTujuhHari(List<TagihanRingkas> semua, DateTime sekarang) {
  final butir = <ButirAgenda>[];
  for (final t in semua) {
    if (!t.menuntutTindakan || t.dokumen) continue;
    final sisa = sisaHariKe(sekarang, t.jatuhTempo);
    if (sisa < 0 || sisa > batasMingguHari) continue;
    butir.add(ButirAgenda(
      id: 'tagihan-${t.id}',
      jenis: JenisButir.tagihan,
      judul: t.nama,
      waktu: t.jatuhTempo,
      nominalSen: t.jumlahSen,
      tingkat: tingkatJatuhTempo(sisa),
      alasan: teksAlasanTagihan(t, sekarang),
      rute: '/ubah/${t.id}',
    ));
  }
  return peringkatEnamBaris(butir, maks: 999);
}

/// Data masukan untuk menyusun satu hari.
class DataHariIni {
  const DataHariIni({
    required this.sekarang,
    this.tagihan = const [],
    this.jumlahSholatTercatat,
    this.statusIzinPengingat,
    this.namaPanggilan = 'Anda',
    this.cuaca,
    this.sumberCuaca = '',
    this.daring = true,
    this.garansiAset = const [],
    this.perawatanAset = const [],
  });

  final DateTime sekarang;
  final List<TagihanRingkas> tagihan;

  /// null = belum ada alat pencatat (FR-88 belum aktif).
  final int? jumlahSholatTercatat;

  /// 'diizinkan' berarti izin notifikasi menyala.
  final String? statusIzinPengingat;

  final String namaPanggilan;
  final String? cuaca;
  final String sumberCuaca;
  final bool daring;

  /// Garansi aset yang berakhir ≤ 30 hari (FR-126).
  final List<RingkasGaransiAset> garansiAset;

  /// Jadwal perawatan aset yang jatuh tempo ≤ 14 hari (FR-125).
  final List<RingkasPerawatanAset> perawatanAset;

  /// Salinan dengan data yang berubah (dipakai layar saat data baru datang).
  DataHariIni salinDengan({
    List<TagihanRingkas>? tagihan,
    int? jumlahSholatTercatat,
    String? statusIzinPengingat,
    bool? daring,
  }) =>
      DataHariIni(
        sekarang: sekarang,
        tagihan: tagihan ?? this.tagihan,
        jumlahSholatTercatat: jumlahSholatTercatat ?? this.jumlahSholatTercatat,
        statusIzinPengingat: statusIzinPengingat ?? this.statusIzinPengingat,
        namaPanggilan: namaPanggilan,
        cuaca: cuaca,
        sumberCuaca: sumberCuaca,
        daring: daring ?? this.daring,
        garansiAset: garansiAset,
        perawatanAset: perawatanAset,
      );
}

/// Hitungan dasar uang hari ini.
class HitunganUang {
  const HitunganUang({
    required this.jumlahLewat,
    required this.jumlahDekatTujuhHari,
    required this.jumlahDekatTigaHari,
    required this.belumDibayarSen,
    required this.jumlahAktif,
  });

  final int jumlahLewat;
  final int jumlahDekatTujuhHari;
  final int jumlahDekatTigaHari;
  final int belumDibayarSen;
  final int jumlahAktif;
}

HitunganUang hitungUang(List<TagihanRingkas> semua, DateTime sekarang) {
  var lewat = 0;
  var dekat7 = 0;
  var dekat3 = 0;
  var belum = 0;
  var aktif = 0;
  for (final t in semua) {
    if (!t.menuntutTindakan || t.dokumen) continue;
    aktif++;
    final sisa = sisaHariKe(sekarang, t.jatuhTempo);
    if (sisa < 0) {
      lewat++;
      belum += t.jumlahSen ?? 0;
    } else if (sisa <= batasMingguHari) {
      dekat7++;
      if (sisa <= batasDekatHari) dekat3++;
      belum += t.jumlahSen ?? 0;
    }
  }
  return HitunganUang(
    jumlahLewat: lewat,
    jumlahDekatTujuhHari: dekat7,
    jumlahDekatTigaHari: dekat3,
    belumDibayarSen: belum,
    jumlahAktif: aktif,
  );
}

/// Angka + warna satu kartu pilar (FR-61).
NilaiPilar angkaPilar(Pilar pilar, DataHariIni data) {
  switch (pilar) {
    case Pilar.health:
      return const NilaiPilar(
        pilar: Pilar.health,
        angka: 'Belum ada data',
        keterangan: 'Modul kesehatan menyusul',
        belumAdaData: true,
      );
    case Pilar.family:
      return const NilaiPilar(
        pilar: Pilar.family,
        angka: 'Belum ada data',
        keterangan: 'Modul keluarga menyusul',
        belumAdaData: true,
      );
    case Pilar.money:
      return _pilarUang(data);
    case Pilar.productivity:
      return _pilarProduktivitas(data);
    case Pilar.ibadah:
      return _pilarIbadah(data);
  }
}

NilaiPilar _pilarUang(DataHariIni data) {
  final u = hitungUang(data.tagihan, data.sekarang);
  if (u.jumlahAktif == 0) {
    return const NilaiPilar(
      pilar: Pilar.money,
      angka: 'Belum ada tagihan',
      keterangan: 'Belum ada data tagihan aktif',
      belumAdaData: true,
      rute: '/uang',
    );
  }
  final angka = 'Jatuh tempo ≤7 hari: ${u.jumlahDekatTujuhHari}'
      ' · Belum dibayar: ${fmtRpDariSen(u.belumDibayarSen)}';
  final tingkat = u.jumlahLewat > 0
      ? TingkatPrioritas.merah
      : (u.jumlahDekatTigaHari > 0
          ? TingkatPrioritas.oranye
          : (u.jumlahDekatTujuhHari > 0 ? TingkatPrioritas.kuning : TingkatPrioritas.hijau));
  final ket = u.jumlahLewat > 0
      ? '${u.jumlahLewat} tagihan lewat jatuh tempo'
      : (u.jumlahDekatTujuhHari > 0 ? 'tidak ada yang lewat' : 'tidak ada tenggat 7 hari ke depan');
  return NilaiPilar(
    pilar: Pilar.money,
    angka: angka,
    keterangan: ket,
    tingkat: tingkat,
    rute: '/uang',
  );
}

NilaiPilar _pilarProduktivitas(DataHariIni data) {
  final agenda = agendaHariIni(data.tagihan, data.sekarang);
  if (agenda.isEmpty) {
    return const NilaiPilar(
      pilar: Pilar.productivity,
      angka: 'Belum ada data',
      keterangan: 'Belum ada butir hari ini',
      belumAdaData: true,
      rute: '/kerja',
    );
  }
  final selesai = agenda.where((b) => b.selesai).length;
  return NilaiPilar(
    pilar: Pilar.productivity,
    angka: 'Agenda hari ini: ${agenda.length} butir · $selesai selesai',
    keterangan: 'termasuk tagihan & janji',
    tingkat: selesai == agenda.length ? TingkatPrioritas.hijau : TingkatPrioritas.kuning,
    rute: '/kerja',
  );
}

NilaiPilar _pilarIbadah(DataHariIni data) {
  final n = data.jumlahSholatTercatat;
  // Ibadah TIDAK PERNAH merah (III-11): yang belum tercatat bukan pelanggaran.
  if (n == null || n == 0) {
    return const NilaiPilar(
      pilar: Pilar.ibadah,
      angka: 'Belum ada catatan hari ini',
      keterangan: 'Catatan hanya untuk Anda sendiri',
      belumAdaData: true,
      rute: '/ibadah',
    );
  }
  final jml = n > jumlahWaktuWajib ? jumlahWaktuWajib : n;
  return NilaiPilar(
    pilar: Pilar.ibadah,
    angka: '$jml dari $jumlahWaktuWajib waktu tercatat',
    keterangan: jml == jumlahWaktuWajib ? '5 dari 5 waktu tercatat hari ini' : 'Belum tercatat bukan berarti tidak dikerjakan',
    tingkat: jml == jumlahWaktuWajib ? TingkatPrioritas.hijau : TingkatPrioritas.kuning,
    rute: '/ibadah',
  );
}

/// Butir Perhatian (FR-62): maksimal 5, urut prioritas §5.1.
List<ButirPerhatian> susunPerhatian(DataHariIni data) {
  final butir = <ButirPerhatian>[];

  for (final t in data.tagihan) {
    if (!t.menuntutTindakan || t.dokumen) continue;
    final sisa = sisaHariKe(data.sekarang, t.jatuhTempo);
    if (sisa < 0) {
      butir.add(ButirPerhatian(
        id: 'lewat-${t.id}',
        jenis: JenisPerhatian.tagihanTerlambat,
        judul: 'Tagihan terlambat',
        alasan: teksAlasanTagihan(t, data.sekarang),
        labelTombol: 'Bayar',
        rute: '/ubah/${t.id}',
        tingkat: TingkatPrioritas.merah,
      ));
    }
  }

  if (data.statusIzinPengingat != null && data.statusIzinPengingat != 'diizinkan') {
    final menunggu = data.tagihan.where((t) => t.menuntutTindakan).length;
    butir.add(ButirPerhatian(
      id: 'izin-notifikasi',
      jenis: JenisPerhatian.hambatanSistem,
      judul: 'Izin notifikasi mati',
      // Alasan wajib membawa data nyata (§5.1), bukan kalimat umum.
      alasan: menunggu > 0
          ? 'Izin belum menyala · pengingat untuk $menunggu item menunggu tidak akan berbunyi'
          : 'Izin belum menyala · belum ada item menunggu',
      labelTombol: 'Buka Pengingat & Izin',
      rute: '/pengingat',
      tingkat: TingkatPrioritas.oranye,
    ));
  }

  for (final t in data.tagihan) {
    if (!t.menuntutTindakan || t.dokumen) continue;
    final sisa = sisaHariKe(data.sekarang, t.jatuhTempo);
    if (sisa < 0 || sisa > batasDekatHari) continue;
    butir.add(ButirPerhatian(
      id: 'dekat-${t.id}',
      jenis: JenisPerhatian.tenggatDekat,
      judul: 'Tenggat dekat',
      alasan: teksAlasanTagihan(t, data.sekarang),
      labelTombol: 'Bayar',
      rute: '/ubah/${t.id}',
      tingkat: tingkatJatuhTempo(sisa),
    ));
  }

  for (final t in data.tagihan) {
    if (!t.menuntutTindakan || !t.dokumen) continue;
    final sisa = sisaHariKe(data.sekarang, t.jatuhTempo);
    if (sisa > batasDokumenHari) continue;
    butir.add(ButirPerhatian(
      id: 'dokumen-${t.id}',
      jenis: JenisPerhatian.dokumenKedaluwarsa,
      judul: 'Dokumen hampir kedaluwarsa',
      alasan: teksAlasanTagihan(t, data.sekarang),
      labelTombol: 'Buka dokumen',
      rute: '/ubah/${t.id}',
      tingkat: sisa < 0 ? TingkatPrioritas.merah : tingkatJatuhTempo(sisa),
    ));
  }

  for (final g in data.garansiAset) {
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

  butir.sort((a, b) {
    final p = a.jenis.prioritas.compareTo(b.jenis.prioritas);
    if (p != 0) return p;
    return a.id.compareTo(b.id);
  });
  return butir.length > maksButirPerhatian ? butir.sublist(0, maksButirPerhatian) : butir;
}

/// Susun seluruh isi layar Today.
RingkasanHariIni susunHariIni(DataHariIni data) {
  final agendaPenuh = agendaHariIni(data.tagihan, data.sekarang);
  return RingkasanHariIni(
    tanggal: data.sekarang,
    agenda: peringkatEnamBaris(agendaPenuh),
    jumlahAgenda: agendaPenuh.length,
    perhatian: susunPerhatian(data),
    pilar: Pilar.values.map((p) => angkaPilar(p, data)).toList(),
  );
}

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
