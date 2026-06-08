import 'package:flutter_test/flutter_test.dart';
import 'package:vidsqueeze_example/main.dart';

void main() {
  testWidgets('renders plugin scaffold copy', (tester) async {
    await tester.pumpWidget(const VidsqueezeExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('vidsqueeze example'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Request'), findsOneWidget);
    expect(find.text('Pick video'), findsOneWidget);
  });
}
