import 'package:flutter_test/flutter_test.dart';
import 'package:vidsqueeze_example/main.dart';

void main() {
  testWidgets('renders plugin scaffold copy', (tester) async {
    await tester.pumpWidget(const VidsqueezeExampleApp());

    expect(find.text('vidsqueeze example'), findsOneWidget);
    expect(find.text('Flutter plugin scaffold is ready.'), findsOneWidget);
    expect(find.text('Current state stream preview:'), findsOneWidget);
  });
}
