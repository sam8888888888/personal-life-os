import 'package:flutter/material.dart';

void main() {
  runApp(const PersonalLifeOsApp());
}

/// F1: kerangka aplikasi minimal. Navigasi/riverpod menyusul F2.
class PersonalLifeOsApp extends StatelessWidget {
  const PersonalLifeOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Life OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const BerandaF1(),
    );
  }
}

class BerandaF1 extends StatelessWidget {
  const BerandaF1({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Life OS')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 56, color: Color(0xFF2E7D32)),
            SizedBox(height: 12),
            Text('Fase 1 — Fondasi siap',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Skema DB, aturan tanggal & uang sudah teruji.',
                style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
