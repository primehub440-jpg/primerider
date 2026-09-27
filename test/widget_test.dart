import 'package:flutter_test/flutter_test.dart';
import 'package:primerider/main.dart';

void main() {
  testWidgets('Rider App test', (WidgetTester tester) async {
    await tester.pumpWidget(PrimeRiderApp());
  });
}