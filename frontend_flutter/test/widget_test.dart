import 'package:flutter_test/flutter_test.dart';

import 'package:ecosmart_frontend/main.dart';

void main() {
  testWidgets('EcoSmart app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EcoSmartApp());
    expect(
      find.text('Traçabilité moderne pour une filière déchets performante'),
      findsOneWidget,
    );
  });
}
