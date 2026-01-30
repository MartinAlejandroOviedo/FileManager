import 'package:flutter/material.dart';
import 'package:file_manager/ui/niceos_theme.dart';
import 'package:file_manager/ui/splash_screen.dart';
import 'package:media_kit/media_kit.dart';
import 'package:file_manager/ui/theme_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSizeBytes = 256 << 20;
  imageCache.maximumSize = 2000;
  themeController.load().then((_) {
    runApp(const FileManagerApp());
  });
}

class FileManagerApp extends StatelessWidget {
  const FileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        title: 'File Manager',
        debugShowCheckedModeBanner: false,
        theme: NiceOSTheme.lightThemeData,
        darkTheme: NiceOSTheme.themeData,
        themeMode: themeController.mode,
        home: const SplashScreen(),
      ),
    );
  }
}
