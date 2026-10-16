import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/main.dart';

void main() {
  testWidgets('Scanner app loads successfully smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LumoraScannerApp());
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
