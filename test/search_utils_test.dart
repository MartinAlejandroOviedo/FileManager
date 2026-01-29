import 'package:file_manager/utils/search_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseSearchQuery parses type and ext', () {
    final q = parseSearchQuery('type:image ext:png cats');
    expect(q.type, 'image');
    expect(q.ext, 'png');
    expect(q.nameTerms, contains('cats'));
  });

  test('parseSearchQuery parses size and date', () {
    final q = parseSearchQuery('size>10mb date<2025-01-01 report');
    expect(q.minBytes != null, isTrue);
    expect(q.maxDate != null, isTrue);
    expect(q.nameTerms, contains('report'));
  });
}
