import 'dart:io';

String fileNameFromPath(String path) {
  if (path.isEmpty) {
    return '';
  }
  return path.split(Platform.pathSeparator).last;
}
