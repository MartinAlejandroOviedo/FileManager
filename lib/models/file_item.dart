class FileItem {
  final String path;
  final String name;
  final bool isDirectory;
  final int sizeBytes;
  final DateTime modifiedAt;

  FileItem({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.sizeBytes,
    required this.modifiedAt,
  });
}
