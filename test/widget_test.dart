import 'package:claw_ui/src/app/claw_ui_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bootstrap renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ClawUiBootstrap());
    await tester.pump();

    expect(find.text('Connect ClawUI'), findsOneWidget);
    expect(find.text('Direct URL'), findsOneWidget);
  });
}
