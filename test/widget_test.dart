import 'package:flutter_test/flutter_test.dart';
import 'package:reelio/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ReelioApp());
    expect(find.text('Reelio'), findsAny);
  });
}
