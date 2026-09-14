/// Warna & ikon untuk Modul 0.
///
/// `netral` sengaja abu-abu: data yang belum ada bukan nilai buruk (III-11).
library;

import 'package:flutter/material.dart';

import '../../core/hari_ini/model_hari_ini.dart';

Color warnaTingkat(TingkatPrioritas t, ThemeData tema) => switch (t) {
      TingkatPrioritas.merah => const Color(0xFFC62828),
      TingkatPrioritas.oranye => const Color(0xFFEF6C00),
      TingkatPrioritas.kuning => const Color(0xFFF9A825),
      TingkatPrioritas.hijau => const Color(0xFF2E7D32),
      TingkatPrioritas.netral => tema.colorScheme.outline,
    };

IconData ikonPilar(Pilar p) => switch (p) {
      Pilar.health => Icons.favorite_outline,
      Pilar.money => Icons.account_balance_wallet_outlined,
      Pilar.productivity => Icons.checklist_outlined,
      Pilar.family => Icons.people_outline,
      Pilar.ibadah => Icons.mosque_outlined,
    };

IconData ikonButir(JenisButir j) => switch (j) {
      JenisButir.tagihan => Icons.receipt_long_outlined,
      JenisButir.dokumen => Icons.description_outlined,
      JenisButir.janji => Icons.event_outlined,
      JenisButir.tugas => Icons.task_alt_outlined,
      JenisButir.sholat => Icons.mosque_outlined,
    };
