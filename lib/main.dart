import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_router.dart';
import 'core/theme/app_tema.dart';
import 'data/repository/demo_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID'); // format tanggal Indonesia
  await seedDemoJikaDiminta(); // hanya aktif bila dibangun dengan --dart-define=DEMO_SEED=true
  runApp(const ProviderScope(child: PersonalLifeOsApp()));
}

class PersonalLifeOsApp extends StatelessWidget {
  const PersonalLifeOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Personal Life OS',
      debugShowCheckedModeBanner: false,
      theme: AppTema.terang(),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
    );
  }
}
