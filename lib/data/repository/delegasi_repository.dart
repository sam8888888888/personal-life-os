/// FR-55 — repositori catatan delegasi (siapa diminta apa, kapan).
library;

import 'dart:math' show Random;

import 'package:drift/drift.dart';

import '../../core/notifikasi/delegasi_whatsapp.dart';
import '../database/database.dart';

class DelegasiRepository {
  DelegasiRepository(this.db, {DateTime Function()? jamSekarang})
      : _jam = jamSekarang ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _jam;
  static final Random _acak = Random();

  String _uid() =>
      'dlg_${_jam().microsecondsSinceEpoch.toRadixString(36)}'
      '${_acak.nextInt(1 << 20).toRadixString(36)}';

  Future<int> catat({
    required String judul,
    required String keNama,
    String? nomor,
    required KanalDelegasi kanal,
    required String teks,
    DateTime? waktu,
  }) async {
    if (judul.trim().isEmpty) {
      throw ArgumentError('Judul pengingat tidak boleh kosong.');
    }
    if (keNama.trim().isEmpty) {
      throw ArgumentError('Nama tujuan delegasi tidak boleh kosong.');
    }
    return db.into(db.delegasiPengingat).insert(DelegasiPengingatCompanion.insert(
          uid: Value(_uid()),
          judul: judul.trim(),
          keNama: Value(keNama.trim()),
          nomor: Value(nomor == null ? '' : nomor.trim()),
          kanal: Value(kanal.kode),
          waktu: waktu ?? _jam(),
          teks: Value(teks),
          diubahPada: Value(_jam()),
        ));
  }

  Future<List<DelegasiPengingatData>> semua({int batas = 30}) {
    return (db.select(db.delegasiPengingat)
          ..orderBy([(t) => OrderingTerm.desc(t.waktu)])
          ..limit(batas))
        .get();
  }

  Future<void> hapus(int id) async {
    await (db.delete(db.delegasiPengingat)..where((t) => t.id.equals(id))).go();
  }

  /// Ringkasan siap layar.
  Future<RingkasanDelegasi> ringkasan({int batas = 30}) async {
    final baris = await semua(batas: batas);
    final daftar = baris
        .map((b) => DelegasiTercatat(
              judul: b.judul,
              keNama: b.keNama,
              nomor: b.nomor,
              kanal: KanalDelegasi.dariKode(b.kanal),
              waktu: b.waktu,
              teks: b.teks,
            ))
        .toList();
    return ringkasDelegasi(daftar, sekarang: _jam(), batas: batas);
  }
}
