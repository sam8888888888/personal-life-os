/// FR-51 — Catatan kas & utang informal: logika murni.
///
/// Untuk utang-piutang yang tidak berbentuk tagihan resmi: utang ke warung,
/// kontrakan, COD, atau uang yang dipinjam tetangga. Aplikasi menyebut saldo
/// apa adanya ("kita berutang Rp X ke Y") tanpa menegur.
library;

import '../../data/database/database.dart';

/// Saldo satu pihak (mis. "Warung Bu Sri").
class SaldoPihak {
  const SaldoPihak({
    required this.pihak,
    required this.utangSen,
    required this.piutangSen,
  });

  final String pihak;

  /// Kita berutang ke pihak ini.
  final int utangSen;

  /// Pihak ini berutang ke kita.
  final int piutangSen;

  /// Selisih: positif berarti pihak ini masih berutang ke kita.
  int get selisihSen => piutangSen - utangSen;

  bool get lunas => utangSen == 0 && piutangSen == 0;
}

/// Ringkasan seluruh catatan kas.
class RingkasKas {
  const RingkasKas({
    required this.totalUtangSen,
    required this.totalPiutangSen,
    required this.totalTunaiSen,
    required this.jumlahBelumLunas,
    required this.perPihak,
    required this.jatuhTempoDekat,
  });

  final int totalUtangSen;
  final int totalPiutangSen;
  final int totalTunaiSen;
  final int jumlahBelumLunas;
  final List<SaldoPihak> perPihak;

  /// Catatan belum lunas yang jatuh temponya dalam [RingkasKas] rentang dekat.
  final List<KasInformalData> jatuhTempoDekat;

  bool get kosong =>
      totalUtangSen == 0 && totalPiutangSen == 0 && totalTunaiSen == 0;
}

/// Hitung ringkasan kas & utang informal.
///
/// [hariKeDepan] menentukan seberapa jauh jatuh tempo masih disebut "dekat".
RingkasKas ringkasKas(
  List<KasInformalData> daftar,
  DateTime sekarang, {
  int hariKeDepan = 14,
}) {
  var utang = 0;
  var piutang = 0;
  var tunai = 0;
  var belumLunas = 0;
  final petaPihak = <String, ({int utang, int piutang})>{};
  final dekat = <KasInformalData>[];

  for (final d in daftar) {
    if (d.lunas) continue;
    switch (d.jenis) {
      case 'piutang':
        piutang += d.jumlahSen;
        break;
      case 'tunai':
        tunai += d.jumlahSen;
        break;
      default:
        utang += d.jumlahSen;
    }
    if (d.jenis != 'tunai') belumLunas++;
    final lama = petaPihak[d.pihak] ?? (utang: 0, piutang: 0);
    petaPihak[d.pihak] = d.jenis == 'piutang'
        ? (utang: lama.utang, piutang: lama.piutang + d.jumlahSen)
        : d.jenis == 'tunai'
            ? lama
            : (utang: lama.utang + d.jumlahSen, piutang: lama.piutang);

    final jt = d.jatuhTempo;
    if (jt != null) {
      final sisa = jt.difference(sekarang).inDays;
      if (sisa <= hariKeDepan) dekat.add(d);
    }
  }

  final perPihak = petaPihak.entries
      .map((e) => SaldoPihak(
            pihak: e.key,
            utangSen: e.value.utang,
            piutangSen: e.value.piutang,
          ))
      .where((s) => !s.lunas)
      .toList()
    ..sort((a, b) => b.selisihSen.abs().compareTo(a.selisihSen.abs()));
  dekat.sort((a, b) => a.jatuhTempo!.compareTo(b.jatuhTempo!));

  return RingkasKas(
    totalUtangSen: utang,
    totalPiutangSen: piutang,
    totalTunaiSen: tunai,
    jumlahBelumLunas: belumLunas,
    perPihak: perPihak,
    jatuhTempoDekat: dekat,
  );
}

/// Kalimat ringkasan — fakta, tanpa menghakimi.
String kalimatKas(RingkasKas r) {
  if (r.kosong) {
    return 'Belum ada catatan kas/utang informal. Catatan di sini untuk utang '
        'yang tidak berbentuk tagihan resmi (warung, kontrakan, COD).';
  }
  final bagian = StringBuffer();
  if (r.totalUtangSen > 0) {
    bagian.write('Kita berutang ${rupiahKas(r.totalUtangSen)}');
  }
  if (r.totalPiutangSen > 0) {
    if (bagian.isNotEmpty) bagian.write(' · ');
    bagian.write('orang berutang ke kita ${rupiahKas(r.totalPiutangSen)}');
  }
  if (r.totalTunaiSen > 0) {
    if (bagian.isNotEmpty) bagian.write(' · ');
    bagian.write('catatan tunai ${rupiahKas(r.totalTunaiSen)}');
  }
  bagian.write('. ${r.jumlahBelumLunas} catatan belum lunas.');
  if (r.jatuhTempoDekat.isNotEmpty) {
    bagian.write(' ${r.jatuhTempoDekat.length} catatan jatuh tempo dekat.');
  }
  return bagian.toString();
}

/// Label jenis kas.
String labelJenisKas(String jenis) => switch (jenis) {
      'piutang' => 'Orang berutang ke kita',
      'tunai' => 'Catatan tunai',
      _ => 'Kita berutang',
    };

/// Rupiah ringkas tanpa data locale.
String rupiahKas(int sen) {
  final teks = (sen / 100).round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < teks.length; i++) {
    if (i > 0 && (teks.length - i) % 3 == 0) buf.write('.');
    buf.write(teks[i]);
  }
  return 'Rp ${buf.toString()}';
}
