import 'package:flutter_test/flutter_test.dart';
import 'package:video_compress_compare/main.dart';

void main() {
  testWidgets('shows benchmark title', (tester) async {
    await tester.pumpWidget(const BenchmarkApp());

    expect(find.text('Benchmark'), findsOneWidget);
    expect(find.text('Pick video'), findsOneWidget);
  });
}
