import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_manager/ui/app_branding.dart';
import 'package:file_manager/ui/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _versionLabel = '';
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _goNext();
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _versionLabel = 'v${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _goNext() async {
    _navTimer?.cancel();
    _navTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1C1D21),
              Color(0xFF23262C),
              Color(0xFF1C1D21),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Lottie.asset(
                'assets/lottie/niceos_splash.json',
                repeat: true,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppBranding.appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              AppBranding.tagline,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            Text(
              'Autores: ${AppBranding.authors.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              _versionLabel.isEmpty ? '' : _versionLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
