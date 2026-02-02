import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_manager/ui/app_theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;
  String _themeId = AppThemeRegistry.defaultId;

  ThemeMode get mode => _mode;
  String get themeId => _themeId;
  AppTheme get activeTheme => AppThemeRegistry.byId(_themeId);

  Future<void> load() async {
    final file = File(_themePath());
    if (!file.existsSync()) {
      return;
    }
    try {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final raw = data['theme'] as String? ?? 'dark';
      final rawThemeId = data['theme_id'] as String?;
      _mode = _parseMode(raw);
      if (rawThemeId != null) {
        _themeId = _parseThemeId(rawThemeId);
      }
    } catch (_) {
      // ignore malformed
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    await _save();
  }

  Future<void> setThemeId(String themeId) async {
    _themeId = _parseThemeId(themeId);
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

  String _parseThemeId(String raw) {
    for (final theme in AppThemeRegistry.themes) {
      if (theme.id == raw) {
        return raw;
      }
    }
    return AppThemeRegistry.defaultId;
  }

  Future<void> _save() async {
    final dir = Directory(_configDir());
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(_themePath());
    final data = <String, dynamic>{
      'theme': _mode.name,
      'theme_id': _themeId,
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
