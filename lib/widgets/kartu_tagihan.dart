/// Widget kartu tagihan — dipakai di dasbor, daftar, dan kalender.
library;

import 'package:flutter/material.dart';

import '../core/utils/tanggal_utils.dart';
import '../core/utils/uang_utils.dart';
import '../data/database/database.dart';

class KartuTagihan extends StatelessWidget {
  const KartuTagihan({
    super.key,
    required this.tagihan,
    this.onTap,
    this.onTandaiLunas,
    this.onUndoLunas,
    this.tampilkanJarakHari = true,
  });

  final TagihanData tagihan;
  final VoidCallback? onTap;
  final VoidCallback? onTandaiLunas;
  final VoidCallback? onUndoLunas;
  final bool tampilkanJarakHari;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final hari = selisihHari(DateTime.now(), tagihan.jatuhTempo);
    final (labelWaktu, warnaBadge) = _badge(skema, hari);
    final judul = tagihan.nama;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: skema.primaryContainer,
                child: Icon(
                  tagihan.lunas ? Icons.check_circle : _ikon(frekuensi: tagihan.frekuensi),
                  color: skema.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(judul,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      fmtTanggalId(tagihan.jatuhTempo) +
                          (tagihan.lunas ? ' · sudah dibayar' : ''),
                      style: TextStyle(fontSize: 13, color: skema.onSurfaceVariant),
                    ),
                    if (tampilkanJarakHari && !tagihan.lunas) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: warnaBadge.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(labelWaktu,
                            style: TextStyle(
                                fontSize: 12,
                                color: warnaBadge,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(tagihan.jumlahSen == null ? '—' : fmtRpDariSen(tagihan.jumlahSen!),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (onTandaiLunas != null && !tagihan.lunas)
                    IconButton(
                      tooltip: 'Tandai sudah dibayar',
                      onPressed: onTandaiLunas,
                      icon: const Icon(Icons.task_alt, color: Color(0xFF2E7D32)),
                    ),
                  if (onUndoLunas != null && tagihan.lunas)
                    IconButton(
                      tooltip: 'Batalkan status lunas',
                      onPressed: onUndoLunas,
                      icon: Icon(Icons.undo, color: skema.onSurfaceVariant),
                    ),
                ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color) _badge(ColorScheme skema, int hari) {
    if (hari < 0) return ('Terlambat ${-hari} hari', const Color(0xFFC62828));
    if (hari == 0) return ('Jatuh tempo HARI INI', const Color(0xFFC62828));
    if (hari == 1) return ('Besok', const Color(0xFFEF6C00));
    if (hari <= 3) return ('$hari hari lagi', const Color(0xFFEF6C00));
    if (hari <= 7) return ('$hari hari lagi', skema.primary);
    return (fmtTanggalPendek(tagihan.jatuhTempo), skema.onSurfaceVariant);
  }

  IconData _ikon({required String frekuensi}) {
    switch (frekuensi) {
      case 'mingguan':
      case 'dua_mingguan':
        return Icons.event_repeat;
      case 'tahunan':
        return Icons.event_available;
      case 'sekali':
        return Icons.looks_one;
      default:
        return Icons.receipt_long;
    }
  }
}
