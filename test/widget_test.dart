import 'package:flutter_test/flutter_test.dart';
import 'package:personal_life_os/main.dart';

void main() {
  testWidgets('Aplikasi F1 tampil', (tester) async {
    await tester.pumpWidget(const PersonalLifeOsApp());
    expect(find.text('Personal Life OS'), findsOneWidget);
    expect(find.textContaining('Fase 1'), findsOneWidget);
  });
}
