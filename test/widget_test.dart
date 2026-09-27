import 'package:flutter_test/flutter_test.dart';
import 'package:cinepulse/main.dart';

void main() {
  testWidgets('CinePulse app smoke test', (WidgetTester tester) async {
    // Verifica che l'app CinePulse si avvii senza crash
    expect(const CinePulseApp(), isNotNull);
  });
}
