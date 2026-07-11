import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_file_manager/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AdvanceFileManagerApp());
    expect(find.text('Advance File Manager'), findsOneWidget);
  });
}
