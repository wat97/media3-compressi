import 'package:flutter_test/flutter_test.dart';
import 'package:vidsqueeze_example/main.dart';

void main() {
  testWidgets('renders compression controls and preview empty state', (tester) async {
    await tester.pumpWidget(const VidsqueezeExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('vidsqueeze'), findsOneWidget);
    expect(find.text('Source Video'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Pick Video'), findsOneWidget);
    expect(find.text('Pick a video to preview it here'), findsOneWidget);
  });
}
