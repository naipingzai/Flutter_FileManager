import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_file_manager/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FlutterFileManagerApp());
    expect(find.text('Flutter File Manager'), findsOneWidget);
  });
}
