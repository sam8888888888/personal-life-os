/// Kartu "Hari berat" (FR-66) — daftar urutan yang disarankan + tawaran menunda.
///
/// Kartu ini hanya menampilkan temuan dan dua tindakan nyata; tidak ada
/// perubahan data yang berjalan sendiri, dan tidak ada butir yang disembunyikan.
library;

import 'package:flutter/material.dart';

import '../../core/hari_ini/hari_berat.dart';
import '../../core/hari_ini/model_hari_ini.dart';
import '../../core/utils/uang_utils.dart';
import 'warna_tingkat.dart';

class KartuHariBerat extends StatelessWidget {
  const KartuHariBerat({
    super.key,
    required this.hasil,
    this.onTunda,
    this.onBuka,
  });

  final HasilHariBerat hasil;

  /// Dipanggil saat pengguna menekan "Tunda pengingat" pada butir [ButirHariBerat].
  final void Function(ButirHariBerat)? onTunda;

  /// Dipanggil saat pengguna menekan butir (membuka modul asalnya).
  final void Function(ButirHariBerat)? onBuka;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final warna = warnaTingkat(
      hasil.jumlah > 8 ? TingkatPrioritas.merah : TingkatPrioritas.oranye,
      tema,
    );
    return Card(
      key: const Key('kartu_hari_berat'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stacked_line_chart, size: 18, color: warna),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Hari ini padat: ${hasil.jumlah} hal',
                      style: tema.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Urutan yang disarankan — yang terlambat dan yang nominalnya '
                'besar lebih dulu.'),
            const SizedBox(height: 6),
            for (final b in hasil.urutan)
              InkWell(
                key: Key('butir_hari_berat_${b.jenis}_${b.id}'),
                onTap: onBuka == null ? null : () => onBuka!(b),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text('${b.urutan}.',
                            style: tema.textTheme.bodyMedium),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${b.nama}'
                                '${b.nominalSen == null ? '' : ' · ${fmtRpDariSen(b.nominalSen!)}'}'),
                            Text(b.alasan, style: tema.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (onTunda != null && b.bisaDitunda)
                        TextButton(
                          key: Key('tunda_hari_berat_${b.id}'),
                          onPressed: () => onTunda!(b),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Tunda'),
                        ),
                    ],
                  ),
                ),
              ),
            if (hasil.adaYangBisaDitunda)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${hasil.jumlahBisaDitunda} butir bisa ditunda '
                    '(bukan mendesak). Menunda hanya menggeser waktu pengingat — '
                    'tanggal jatuh tempo dan catatannya tetap utuh.'),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Semua butir hari ini mendesak, jadi tidak '
                    'ditawarkan untuk ditunda.'),
              ),
          ],
        ),
      ),
    );
  }
}
