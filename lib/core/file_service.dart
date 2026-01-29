import 'dart:convert';
import 'dart:io';
import 'package:file_manager/models/file_item.dart';

class FileService {
  Future<bool> _commandExists(String command) async {
    final result = await Process.run('which', [command]);
    return result.exitCode == 0;
  }

  String _previewCacheDir() {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return '$home/.cache/file_manager/previews';
    }
    return '/tmp/file_manager_previews';
  }

  String _cacheKey(String path) {
    return base64Url.encode(utf8.encode(path));
  }

  Future<String> _ensurePreviewPath(String path, String suffix) async {
    final dir = Directory(_previewCacheDir());
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return '${dir.path}/${_cacheKey(path)}$suffix';
  }

  Future<String?> generatePdfPreview(String path) async {
    if (!await _commandExists('pdftoppm')) {
      return null;
    }
    final outputBase = await _ensurePreviewPath(path, '_pdf');
    final outputFile = '$outputBase-1.png';
    if (File(outputFile).existsSync()) {
      return outputFile;
    }
    final result = await Process.run(
      'pdftoppm',
      ['-f', '1', '-l', '1', '-png', path, outputBase],
    );
    return result.exitCode == 0 && File(outputFile).existsSync()
        ? outputFile
        : null;
  }

  Future<String?> generateVideoThumbnail(String path) async {
    final outputFile = await _ensurePreviewPath(path, '_video.png');
    if (File(outputFile).existsSync()) {
      return outputFile;
    }
    if (await _commandExists('ffmpegthumbnailer')) {
      final result = await Process.run(
        'ffmpegthumbnailer',
        ['-i', path, '-o', outputFile, '-s', '256', '-t', '10%'],
      );
      if (result.exitCode == 0 && File(outputFile).existsSync()) {
        return outputFile;
      }
    }
    if (await _commandExists('ffmpeg')) {
      final result = await Process.run(
        'ffmpeg',
        ['-y', '-ss', '00:00:01', '-i', path, '-vframes', '1', outputFile],
      );
      if (result.exitCode == 0 && File(outputFile).existsSync()) {
        return outputFile;
      }
    }
    return null;
  }

  Future<Map<String, String>> readAudioMetadata(String path) async {
    if (!await _commandExists('ffprobe')) {
      return {};
    }
    final result = await Process.run(
      'ffprobe',
      ['-v', 'quiet', '-print_format', 'json', '-show_format', path],
    );
    if (result.exitCode != 0) {
      return {};
    }
    final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final format = data['format'] as Map<String, dynamic>? ?? {};
    final tags = (format['tags'] as Map?)?.cast<String, dynamic>() ?? {};
    final meta = <String, String>{};
    void addIf(String key, String label) {
      final value = tags[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        meta[label] = value.toString();
      }
    }

    addIf('title', 'Título');
    addIf('artist', 'Artista');
    addIf('album', 'Álbum');
    if (format['duration'] != null) {
      meta['Duración'] = format['duration'].toString();
    }
    if (format['bit_rate'] != null) {
      meta['Bitrate'] = format['bit_rate'].toString();
    }
    return meta;
  }

  String? archiveType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) return 'tar.gz';
    if (lower.endsWith('.tar.xz') || lower.endsWith('.txz')) return 'tar.xz';
    if (lower.endsWith('.tar.bz2') || lower.endsWith('.tbz2')) return 'tar.bz2';
    if (lower.endsWith('.tar')) return 'tar';
    if (lower.endsWith('.zip')) return 'zip';
    if (lower.endsWith('.7z')) return '7z';
    if (lower.endsWith('.rar')) return 'rar';
    return null;
  }

  Future<void> extractArchive(String archivePath, String destDir) async {
    final type = archiveType(archivePath);
    if (type == null) {
      throw FileSystemException('Formato no soportado', archivePath);
    }
    final dest = Directory(destDir);
    if (!dest.existsSync()) {
      dest.createSync(recursive: true);
    }

    if (await _commandExists('7z')) {
      final result = await Process.run(
        '7z',
        ['x', '-y', '-o$destDir', archivePath],
      );
      if (result.exitCode == 0) {
        return;
      }
    }

    if (type == 'zip' && await _commandExists('unzip')) {
      final result = await Process.run(
        'unzip',
        ['-o', archivePath, '-d', destDir],
      );
      if (result.exitCode == 0) return;
    }

    if ((type == 'tar' ||
            type == 'tar.gz' ||
            type == 'tar.xz' ||
            type == 'tar.bz2') &&
        await _commandExists('tar')) {
      final args = <String>['-xf', archivePath, '-C', destDir];
      final result = await Process.run('tar', args);
      if (result.exitCode == 0) return;
    }

    if (type == 'rar' && await _commandExists('unrar')) {
      final result = await Process.run(
        'unrar',
        ['x', '-o+', archivePath, destDir],
      );
      if (result.exitCode == 0) return;
    }

    throw FileSystemException('No se pudo extraer el archivo', archivePath);
  }

  Future<void> createArchive({
    required String baseDir,
    required List<String> relativePaths,
    required String outputPath,
    required String format,
  }) async {
    if (relativePaths.isEmpty) {
      throw FileSystemException('No hay archivos para comprimir', outputPath);
    }
    if (format == 'zip' && await _commandExists('zip')) {
      final result = await Process.run(
        'zip',
        ['-r', outputPath, ...relativePaths],
        workingDirectory: baseDir,
      );
      if (result.exitCode == 0) return;
    }
    if (format == '7z' && await _commandExists('7z')) {
      final result = await Process.run(
        '7z',
        ['a', outputPath, ...relativePaths],
        workingDirectory: baseDir,
      );
      if (result.exitCode == 0) return;
    }
    if (format == 'rar' && await _commandExists('rar')) {
      final result = await Process.run(
        'rar',
        ['a', outputPath, ...relativePaths],
        workingDirectory: baseDir,
      );
      if (result.exitCode == 0) return;
    }
    if ((format == 'tar' ||
            format == 'tar.gz' ||
            format == 'tar.xz' ||
            format == 'tar.bz2') &&
        await _commandExists('tar')) {
      final flag = switch (format) {
        'tar' => '-cf',
        'tar.gz' => '-czf',
        'tar.xz' => '-cJf',
        'tar.bz2' => '-cjf',
        _ => '-cf',
      };
      final result = await Process.run(
        'tar',
        [flag, outputPath, ...relativePaths],
        workingDirectory: baseDir,
      );
      if (result.exitCode == 0) return;
    }
    throw FileSystemException('No se pudo crear el archivo', outputPath);
  }

  String _nameFromEntity(FileSystemEntity entity) {
    final segments = entity.uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      return segments.last;
    }
    final path = entity.path;
    var cleaned = path;
    while (cleaned.endsWith(Platform.pathSeparator) && cleaned.length > 1) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    final index = cleaned.lastIndexOf(Platform.pathSeparator);
    if (index == -1) {
      return cleaned.isEmpty ? path : cleaned;
    }
    final name = cleaned.substring(index + 1);
    return name.isEmpty ? cleaned : name;
  }

  Future<List<FileItem>> listDirectory(String path) async {
    final dir = Directory(path);
    final items = await dir.list().toList();
    final fileItems = await Future.wait(items.map((entity) async {
      final stat = await entity.stat();
      final isDirectory = stat.type == FileSystemEntityType.directory;
      return FileItem(
        path: entity.path,
        name: _nameFromEntity(entity),
        isDirectory: isDirectory,
        sizeBytes: isDirectory ? 0 : stat.size,
        modifiedAt: stat.modified,
      );
    }));
    fileItems.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return fileItems;
  }

  Future<void> createDirectory(String path) async {
    final dir = Directory(path);
    if (await dir.exists()) {
      throw FileSystemException('El directorio ya existe', path);
    }
    await dir.create(recursive: true);
  }

  Future<void> deleteEntity(String path) async {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('No existe', path);
    }
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    } else {
      await File(path).delete();
    }
  }

  Future<void> moveToTrash(String path) async {
    final entityType = FileSystemEntity.typeSync(path);
    if (entityType == FileSystemEntityType.notFound) {
      throw FileSystemException('No existe', path);
    }
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw FileSystemException('HOME no disponible', path);
    }
    final trashFiles = Directory('$home/.local/share/Trash/files');
    final trashInfo = Directory('$home/.local/share/Trash/info');
    if (!trashFiles.existsSync()) {
      trashFiles.createSync(recursive: true);
    }
    if (!trashInfo.existsSync()) {
      trashInfo.createSync(recursive: true);
    }

    final baseName = path.split(Platform.pathSeparator).last;
    var targetName = baseName;
    var targetPath = '${trashFiles.path}${Platform.pathSeparator}$targetName';
    var counter = 1;
    while (FileSystemEntity.typeSync(targetPath) !=
        FileSystemEntityType.notFound) {
      targetName = '$baseName.$counter';
      targetPath = '${trashFiles.path}${Platform.pathSeparator}$targetName';
      counter++;
    }

    if (entityType == FileSystemEntityType.directory) {
      await Directory(path).rename(targetPath);
    } else {
      await File(path).rename(targetPath);
    }

    final deletionDate = DateTime.now().toIso8601String();
    final infoPath = '${trashInfo.path}${Platform.pathSeparator}$targetName.trashinfo';
    final info = StringBuffer()
      ..writeln('[Trash Info]')
      ..writeln('Path=${Uri.file(path).toString()}')
      ..writeln('DeletionDate=$deletionDate');
    await File(infoPath).writeAsString(info.toString());
  }

  Future<String> renameEntity(String path, String newName) async {
    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.notFound) {
      throw FileSystemException('No existe', path);
    }
    final parent = Directory(path).parent.path;
    final newPath = parent.endsWith(Platform.pathSeparator)
        ? '$parent$newName'
        : '$parent${Platform.pathSeparator}$newName';
    if (entity == FileSystemEntityType.directory) {
      return Directory(path).rename(newPath).then((dir) => dir.path);
    }
    return File(path).rename(newPath).then((file) => file.path);
  }

  Future<void> moveEntity(String sourcePath, String destPath) async {
    try {
      final entity = FileSystemEntity.typeSync(sourcePath);
      if (entity == FileSystemEntityType.directory) {
        await Directory(sourcePath).rename(destPath);
      } else {
        await File(sourcePath).rename(destPath);
      }
    } catch (_) {
      await copyEntity(sourcePath, destPath);
      await deleteEntity(sourcePath);
    }
  }

  Future<void> copyEntity(String sourcePath, String destPath) async {
    final type = FileSystemEntity.typeSync(sourcePath);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('No existe', sourcePath);
    }
    if (type == FileSystemEntityType.directory) {
      await _copyDirectory(Directory(sourcePath), Directory(destPath));
    } else {
      await File(sourcePath).copy(destPath);
    }
  }

  Future<bool> isExecutable(String path) async {
    final stat = await FileStat.stat(path);
    // Check any execute bit.
    return (stat.mode & 0x49) != 0;
  }

  Future<void> setExecutable(String path, {required bool executable}) async {
    final stat = await FileStat.stat(path);
    var permissions = stat.mode & 0x1FF;
    if (executable) {
      permissions |= 0x49;
    } else {
      permissions &= ~0x49;
    }
    final mode = permissions.toRadixString(8).padLeft(3, '0');
    await Process.run('chmod', [mode, path]);
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }
    await for (final entity in source.list(recursive: false)) {
      final newPath =
          '${destination.path}${Platform.pathSeparator}${entity.uri.pathSegments.last}';
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      } else {
        await File(entity.path).copy(newPath);
      }
    }
  }
}
