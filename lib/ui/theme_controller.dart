import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    final file = File(_themePath());
    if (!file.existsSync()) {
      return;
    }
    try {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final raw = data['theme'] as String? ?? 'dark';
      _mode = _parseMode(raw);
    } catch (_) {
      // ignore malformed
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    await _save();
  }

  ThemeMode _parseMode(String raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> _save() async {
    final dir = Directory(_configDir());
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(_themePath());
    final data = <String, dynamic>{
      'theme': _mode.name,
    };
    file.writeAsStringSync(jsonEncode(data));
  }

  String _configDir() {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.config/file_manager';
  }

  String _themePath() {
    return '${_configDir()}/theme.json';
  }
}

final ThemeController themeController = ThemeController();
