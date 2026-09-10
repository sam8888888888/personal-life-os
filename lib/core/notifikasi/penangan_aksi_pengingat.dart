/// Pelaksana aksi notifikasi (FR-11): "✓ Sudah bayar", "Tunda 1 jam",
/// "Buka aplikasi". Dipakai baik dari isolate utama maupun pekerja latar.
library;

import 'package:drift/drift.dart' show Value;

import '../../data/database/database.dart';
import '../../data/repository/tagihan_repository.dart';
import '../utils/tanggal_utils.dart';
import '../utils/uang_utils.dart';
import 'jejak.dart';
import 'layanan_notifikasi.dart';
import 'model_pengingat.dart';
import 'perencana_pengingat.dart';
import 'penyinkron_pengingat.dart';

class HasilAksi {
  const HasilAksi({
    required this.berhasil,
    required this.pesan,
    this.tagihanId,
    this.aksi = AksiNotifikasi.buka,
  });

  final bool berhasil;
  final String pesan;
  final int? tagihanId;
  final AksiNotifikasi aksi;

  @override
  String toString() => 'HasilAksi(${aksi.id}: $pesan)';
}

/// Jalankan aksi dari payload notifikasi.
///
/// [db] boleh null: fungsi akan membuka database sendiri (kasus pekerja latar).
Future<HasilAksi> tanganiAksiPengingat(
  String? payloadTeks, {
  AppDatabase? db,
  LayananNotifikasi? layanan,
  DateTime? sekarang,
}) async {
  final p = PayloadPengingat.urai(payloadTeks);
  if (p == null) {
    final h = HasilAksi(berhasil: false, pesan: 'Payload notifikasi tidak dikenal');
    await catatJejak({'jenis': 'aksi', 'hasil': h.pesan, 'payload': payloadTeks});
    return h;
  }

  if (p.aksi == AksiNotifikasi.buka) {
    final h = HasilAksi(
        berhasil: true, pesan: 'Membuka aplikasi', tagihanId: p.tagihanId, aksi: p.aksi);
    await catatJejak({'jenis': 'aksi', 'hasil': h.pesan, 'tagihanId': p.tagihanId});
    return h;
  }

  final dbSendiri = db == null;
  final basis = db ?? AppDatabase();
  try {
    final repo = TagihanRepository(basis);
    final t = await (basis.select(basis.tagihan)
          ..where((x) => x.id.equals(p.tagihanId)))
        .getSingleOrNull();

    if (t == null) {
      final h = HasilAksi(
          berhasil: false, pesan: 'Tagihan #${p.tagihanId} tidak ditemukan', aksi: p.aksi);
      await catatJejak({'jenis': 'aksi', 'hasil': h.pesan, 'tagihanId': p.tagihanId});
      return h;
    }

    switch (p.aksi) {
      case AksiNotifikasi.sudahBayar:
        // Notifikasi lama (periode sudah dibayar / berganti) tidak boleh
        // menandai lunas periode berikutnya.
        final periodeNotif = p.periode;
        if (periodeNotif != null &&
            selisihHari(t.jatuhTempo, periodeNotif) != 0) {
          final h = HasilAksi(
            berhasil: true,
            pesan: '${t.nama} periode ${fmtTanggalAman(periodeNotif)} sudah dibayar; '
                'periode aktif sekarang ${fmtTanggalAman(t.jatuhTempo)}',
            tagihanId: t.id,
            aksi: p.aksi,
          );
          await catatJejak({
            'jenis': 'aksi',
            'hasil': h.pesan,
            'tagihanId': t.id,
            'catatan': 'notifikasi kedaluwarsa, tidak ada perubahan',
          });
          return h;
        }
        if (t.lunas) {
          // Idempoten: jangan gandakan riwayat/rollover.
          final h = HasilAksi(
            berhasil: true,
            pesan: '${t.nama} sudah bertanda lunas sebelumnya',
            tagihanId: t.id,
            aksi: p.aksi,
          );
          await catatJejak({'jenis': 'aksi', 'hasil': h.pesan, 'tagihanId': t.id});
          return h;
        }
        await repo.tandaiLunas(t.id, tanggalBayar: sekarang ?? DateTime.now());
        final sesudah = await (basis.select(basis.tagihan)
              ..where((x) => x.id.equals(t.id)))
            .getSingle();
        final h = HasilAksi(
          berhasil: true,
          pesan: sesudah.statusAktif
              ? '${t.nama} ditandai lunas · periode berikutnya ${fmtTanggalAman(sesudah.jatuhTempo)}'
              : '${t.nama} ditandai lunas (tagihan sekali)',
          tagihanId: t.id,
          aksi: p.aksi,
        );
        // Segarkan jadwal setelah pembayaran (pengingat periode baru).
        if (layanan != null) {
          await PenyinkronPengingat(repo: repo, layanan: layanan)
              .sinkron(sekarang: sekarang);
        }
        await catatJejak({'jenis': 'aksi', 'hasil': h.pesan, 'tagihanId': t.id});
        return h;

      case AksiNotifikasi.tundaSatuJam:
        final kapan = (sekarang ?? DateTime.now()).add(const Duration(hours: 1));
        final p2 = Pengingat(
          id: idNotifikasi(t.id, slotTunda),
          tagihanId: t.id,
          waktu: kapan,
          kanal: t.jatuhTempo.isBefore(DateTime.now())
              ? KanalNotifikasi.terlambat
              : KanalNotifikasi.tagihan,
          judul: 'Diingatkan lagi: ${t.nama}',
          isi: 'Jatuh tempo ${fmtTanggalAman(t.jatuhTempo)}. '
              '${(t.jumlahSen ?? 0) > 0 ? 'Jumlah ${fmtRpDariSen(t.jumlahSen!)}' : 'Tanpa nominal'}',
        );
        if (layanan != null) await layanan.jadwalkanSatu(p2);
        final h = HasilAksi(
          berhasil: true,
          pesan: '${t.nama} diingatkan lagi pukul '
              '${kapan.hour.toString().padLeft(2, '0')}:${kapan.minute.toString().padLeft(2, '0')}',
          tagihanId: t.id,
          aksi: p.aksi,
        );
        await catatJejak({'jenis': 'aksi', 'hasil': h.pesan, 'tagihanId': t.id});
        return h;

      case AksiNotifikasi.buka:
        return const HasilAksi(berhasil: true, pesan: 'Membuka aplikasi');
    }
  } catch (e) {
    final h = HasilAksi(
        berhasil: false, pesan: 'Gagal memproses aksi: $e', aksi: p.aksi);
    await catatJejak({'jenis': 'aksi', 'hasil': h.pesan, 'tagihanId': p.tagihanId});
    return h;
  } finally {
    if (dbSendiri) await basis.close();
  }
}

/// Dipakai bila nanti perlu menonaktifkan tagihan dari notifikasi.
Future<void> nonaktifkanDariNotifikasi(int id, AppDatabase basis) async {
  await (basis.update(basis.tagihan)..where((t) => t.id.equals(id)))
      .write(const TagihanCompanion(statusAktif: Value(false)));
}
