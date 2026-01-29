import 'package:flutter_test/flutter_test.dart';
import 'package:file_manager/main.dart';

void main() {
  testWidgets('App starts and shows splash', (WidgetTester tester) async {
    await tester.pumpWidget(const FileManagerApp());
    expect(find.text('File Manager'), findsAtLeastNWidgets(1));
  });
}
