/// Pemetaan data basis data -> bentuk ringkas Modul 0.
/// Dipisah di lapisan UI supaya `lib/core/hari_ini` tetap murni.
library;

import '../../core/hari_ini/tagihan_ringkas.dart';
import '../../data/database/database.dart';

TagihanRingkas petaTagihan(TagihanData t) => TagihanRingkas(
      id: t.id,
      nama: t.nama,
      jatuhTempo: t.jatuhTempo,
      jumlahSen: t.jumlahSen,
      jenis: t.jenis,
      lunas: t.lunas,
      statusAktif: t.statusAktif,
      prioritas: t.prioritas,
    );

List<TagihanRingkas> petaDaftarTagihan(List<TagihanData> daftar) =>
    daftar.map(petaTagihan).toList(growable: false);
