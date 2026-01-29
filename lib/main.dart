import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:file_manager/ui/niceos_theme.dart';
import 'package:file_manager/ui/splash_screen.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSizeBytes = 256 << 20;
  imageCache.maximumSize = 2000;
  runApp(const FileManagerApp());
}

class FileManagerApp extends StatelessWidget {
  const FileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Manager',
      theme: NiceOSTheme.themeData,
      home: const SplashScreen(),
    );
  }
}
