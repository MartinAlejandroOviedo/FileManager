import 'dart:io';

import 'package:file_manager/core/file_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('listDirectory returns directories first and names', () async {
    final tempDir = await Directory.systemTemp.createTemp('fm_test_');
    final dirA = Directory('${tempDir.path}${Platform.pathSeparator}aaa_dir');
    final fileB = File('${tempDir.path}${Platform.pathSeparator}bbb_file.txt');
    await dirA.create(recursive: true);
    await fileB.writeAsString('test');

    final service = FileService();
    final items = await service.listDirectory(tempDir.path);

    expect(items.isNotEmpty, isTrue);
    expect(items.first.isDirectory, isTrue);
    expect(items.first.name, equals('aaa_dir'));

    await tempDir.delete(recursive: true);
  });
}
