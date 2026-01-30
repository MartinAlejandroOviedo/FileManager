import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_manager/core/file_service.dart';
import 'package:file_manager/models/file_item.dart';
import 'package:file_manager/ui/app_branding.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_manager/ui/app_icons.dart';
import 'package:file_manager/utils/search_utils.dart';
import 'package:lottie/lottie.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_manager/ui/theme_controller.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _PaneData {
  _PaneData({
    required this.currentPath,
  })  : items = [],
        selectedPaths = <String>{},
        lastSelectedIndex = null,
        searchQuery = '',
        searchIndex = {},
        errorMessage = null,
        isEditingPath = false,
        history = [currentPath],
        historyIndex = 0,
        pathController = TextEditingController(text: currentPath),
        searchController = TextEditingController(),
        pathFocusNode = FocusNode(),
        searchFocusNode = FocusNode();

  String currentPath;
  List<FileItem> items;
  Set<String> selectedPaths;
  int? lastSelectedIndex;
  String searchQuery;
  Map<String, List<FileItem>> searchIndex;
  String? errorMessage;
  String? gitRoot;
  bool isEditingPath;
  List<String> history;
  int historyIndex;
  final TextEditingController pathController;
  final TextEditingController searchController;
  final FocusNode pathFocusNode;
  final FocusNode searchFocusNode;

  void dispose() {
    pathController.dispose();
    searchController.dispose();
    pathFocusNode.dispose();
    searchFocusNode.dispose();
  }
}

class _MainScreenState extends State<MainScreen> {
  final FileService _fileService = FileService();
  late String _homePath;
  List<_Place> _places = [];
  List<_Place> _customPlaces = [];
  List<_CloudRemote> _cloudRemotes = [];
  _ViewMode _viewMode = _ViewMode.list;
  bool _showDetailsPanel = true;
  bool _showHidden = false;
  final bool _dualPane = true;
  bool _globalSearchEnabled = false;
  bool _globalSearchLoading = false;
  String? _globalSearchError;
  List<FileItem> _globalSearchItems = [];
  Map<String, List<FileItem>> _globalSearchIndex = {};
  List<String> _globalSearchRoots = [];
  DateTime? _globalSearchBuiltAt;
  final Map<String, String> _tagsByPath = {};
  final List<_RenamePreset> _renamePresets = [];
  final Map<String, String> _gitStatusByPath = {};
  String _dragDropDefaultAction = 'ask';
  List<String> _memoryClipboardPaths = [];
  bool _memoryClipboardAsRoot = false;
  bool _memoryClipboardIsCut = false;
  _LastAction? _lastAction;
  int _lastItemContextMenuAtMs = 0;
  double _previewSize = 220;
  _SortField _sortField = _SortField.name;
  bool _sortAscending = true;
  final List<_FileTab> _tabs = [];
  int _activeTabIndex = 0;
  int _tabCounter = 0;
  String _versionLabel = '';
  final Map<String, String> _archiveCache = {};
  final Map<String, int> _historyVisits = {};
  final Map<String, DateTime> _historyLastVisited = {};
  double _panelOpacity = 0.9;
  late final _PaneData _leftPane;
  late final _PaneData _rightPane;
  bool _isRightActive = false;
  List<String> _recentItems = [];
  List<String> _favoriteItems = [];

  _PaneData get _activePane => _isRightActive ? _rightPane : _leftPane;

  String get _currentPath => _activePane.currentPath;
  set _currentPath(String value) => _activePane.currentPath = value;

  List<FileItem> get _items => _activePane.items;
  set _items(List<FileItem> value) => _activePane.items = value;

  Set<String> get _selectedPaths => _activePane.selectedPaths;
  set _selectedPaths(Set<String> value) => _activePane.selectedPaths = value;

  int? get _lastSelectedIndex => _activePane.lastSelectedIndex;
  set _lastSelectedIndex(int? value) => _activePane.lastSelectedIndex = value;

  String get _searchQuery => _activePane.searchQuery;
  set _searchQuery(String value) => _activePane.searchQuery = value;

  Map<String, List<FileItem>> get _searchIndex => _activePane.searchIndex;
  set _searchIndex(Map<String, List<FileItem>> value) =>
      _activePane.searchIndex = value;

  bool get _isEditingPath => _activePane.isEditingPath;
  set _isEditingPath(bool value) => _activePane.isEditingPath = value;

  List<String> get _history => _activePane.history;
  set _history(List<String> value) => _activePane.history = value;

  int get _historyIndex => _activePane.historyIndex;
  set _historyIndex(int value) => _activePane.historyIndex = value;

  TextEditingController get _pathController => _activePane.pathController;
  TextEditingController get _searchController => _activePane.searchController;
  FocusNode get _pathFocusNode => _activePane.pathFocusNode;
  FocusNode get _searchFocusNode => _activePane.searchFocusNode;

  static const String _virtualRecentPath = 'recent://';
  static const String _virtualFavoritesPath = 'favorites://';

  @override
  void initState() {
    super.initState();
    _homePath = Platform.environment['HOME'] ?? '/home';
    _globalSearchRoots = [_homePath];
    _leftPane = _PaneData(currentPath: _homePath);
    _rightPane = _PaneData(currentPath: _homePath);
    _loadSettings();
    if (_tabs.isEmpty) {
      final initialTab = _createTab(_homePath);
      _tabs.add(initialTab);
      _activeTabIndex = 0;
      _applyTab(initialTab);
    }
    _customPlaces = _loadCustomPlaces();
    _places = _buildPlaces();
    _loadRcloneRemotes();
    _loadVersion();
    _loadFilesForPane(_leftPane);
    _loadFilesForPane(_rightPane);
    if (_globalSearchEnabled && _searchQuery.trim().isNotEmpty) {
      _ensureGlobalSearchIndex();
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versionLabel = '${info.version} (${info.buildNumber})';
    });
  }

  @override
  void dispose() {
    _leftPane.dispose();
    _rightPane.dispose();
    super.dispose();
  }

  _FileTab _createTab(String path) {
    final tab = _FileTab(
      id: 'tab_${_tabCounter++}',
      path: path,
      label: null,
      pinned: false,
      history: [path],
      historyIndex: 0,
      selectedPaths: <String>{},
      lastSelectedIndex: null,
      searchQuery: '',
    );
    return tab;
  }

  _FileTab _cloneTab(_FileTab source, {bool keepSelection = false}) {
    return _FileTab(
      id: 'tab_${_tabCounter++}',
      path: source.path,
      label: source.label,
      pinned: source.pinned,
      history: List<String>.from(source.history),
      historyIndex: source.historyIndex,
      selectedPaths:
          keepSelection ? Set<String>.from(source.selectedPaths) : <String>{},
      lastSelectedIndex: keepSelection ? source.lastSelectedIndex : null,
      searchQuery: source.searchQuery,
    );
  }

  void _applyTab(_FileTab tab) {
    _currentPath = tab.path;
    _history = List<String>.from(tab.history);
    _historyIndex = tab.historyIndex;
    _selectedPaths = Set<String>.from(tab.selectedPaths);
    _lastSelectedIndex = tab.lastSelectedIndex;
    _searchQuery = tab.searchQuery;
    _pathController.text = _currentPath;
    _searchController.text = _searchQuery;
    _isEditingPath = false;
  }

  void _syncActiveTab() {
    if (_tabs.isEmpty) {
      return;
    }
    final tab = _tabs[_activeTabIndex];
    tab.path = _currentPath;
    tab.history = List<String>.from(_history);
    tab.historyIndex = _historyIndex;
    tab.selectedPaths = Set<String>.from(_selectedPaths);
    tab.lastSelectedIndex = _lastSelectedIndex;
    tab.searchQuery = _searchQuery;
  }

  void _switchTab(int index) {
    if (index == _activeTabIndex || index < 0 || index >= _tabs.length) {
      return;
    }
    _syncActiveTab();
    setState(() {
      _activeTabIndex = index;
      _applyTab(_tabs[_activeTabIndex]);
    });
    _saveSettings();
    _loadFiles();
  }

  void _addTab({String? path}) {
    _syncActiveTab();
    final newTab = _createTab(path ?? _currentPath);
    setState(() {
      _tabs.add(newTab);
      _activeTabIndex = _tabs.length - 1;
      _applyTab(newTab);
    });
    _saveSettings();
    _loadFiles();
  }

  void _duplicateTab(int index, {bool keepSelection = false}) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    _syncActiveTab();
    final newTab = _cloneTab(_tabs[index], keepSelection: keepSelection);
    setState(() {
      _tabs.insert(index + 1, newTab);
      _activeTabIndex = index + 1;
      _applyTab(newTab);
    });
    _saveSettings();
    _loadFiles();
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1 || index < 0 || index >= _tabs.length) {
      return;
    }
    if (_tabs[index].pinned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Desancla la pestaña para cerrarla.')),
      );
      return;
    }
    _syncActiveTab();
    final wasActive = index == _activeTabIndex;
    setState(() {
      _tabs.removeAt(index);
      if (wasActive) {
        _activeTabIndex = index == 0 ? 0 : index - 1;
        _applyTab(_tabs[_activeTabIndex]);
      } else if (index < _activeTabIndex) {
        _activeTabIndex -= 1;
      }
    });
    _saveSettings();
    if (wasActive) {
      _loadFiles();
    }
  }

  void _togglePinTab(int index) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    setState(() {
      _tabs[index].pinned = !_tabs[index].pinned;
    });
    _saveSettings();
  }

  void _closeOtherTabs(int index) {
    if (_tabs.length <= 1 || index < 0 || index >= _tabs.length) {
      return;
    }
    _syncActiveTab();
    final keep = _tabs[index];
    setState(() {
      _tabs
        ..clear()
        ..add(keep);
      _activeTabIndex = 0;
      _applyTab(keep);
    });
    _saveSettings();
    _loadFiles();
  }

  Future<void> _addTabFromPathPrompt() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva pestaña desde ruta'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '/home/usuario/Carpeta',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) {
      return;
    }
    final path = result;
    if (!Directory(path).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La ruta no existe: $path')),
      );
      return;
    }
    _addTab(path: path);
  }

  List<String> _recentPaths() {
    final seen = <String>{};
    final recent = <String>[];
    for (var i = _history.length - 1; i >= 0; i--) {
      final path = _history[i];
      if (seen.add(path)) {
        recent.add(path);
        if (recent.length >= 6) {
          break;
        }
      }
    }
    return recent;
  }

  void _reorderTabs(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    setState(() {
      final moved = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, moved);
      if (_activeTabIndex == oldIndex) {
        _activeTabIndex = newIndex;
      } else if (oldIndex < _activeTabIndex &&
          newIndex >= _activeTabIndex) {
        _activeTabIndex -= 1;
      } else if (oldIndex > _activeTabIndex &&
          newIndex <= _activeTabIndex) {
        _activeTabIndex += 1;
      }
    });
    _saveSettings();
  }

  void _openPathInTab(int index, String path) {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    if (!Directory(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La ruta no existe: $path')),
      );
      return;
    }
    _syncActiveTab();
    setState(() {
      _activeTabIndex = index;
      _applyTab(_tabs[_activeTabIndex]);
    });
    _navigateTo(path);
    _saveSettings();
  }
  Future<void> _renameTab(int index) async {
    if (index < 0 || index >= _tabs.length) {
      return;
    }
    final tab = _tabs[index];
    final controller = TextEditingController(text: tab.label ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar pestaña'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Nombre de la pestaña',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    if (result == null) {
      return;
    }
    setState(() {
      tab.label = result.isEmpty ? null : result;
    });
    _saveSettings();
  }

  Future<void> _loadFiles() async {
    await _loadFilesForPane(_activePane);
  }

  Future<void> _loadFilesForPane(_PaneData pane) async {
    try {
      final items = _isVirtualPath(pane.currentPath)
          ? await _loadVirtualItems(pane.currentPath)
          : await _fileService.listDirectory(pane.currentPath);
      setState(() {
        pane.items = items;
        pane.searchIndex = _buildSearchIndex(items);
        pane.errorMessage = null;
        pane.selectedPaths.removeWhere(
          (path) => pane.items.every((item) => item.path != path),
        );
      });
      await _updateGitStatusForPane(pane);
      _syncActiveTab();
    } catch (error) {
      setState(() {
        pane.items = [];
        pane.errorMessage =
            'No se pudo abrir "${pane.currentPath}". Revisa permisos o la ruta.';
      });
      _syncActiveTab();
    }
  }

  Future<List<FileItem>> _loadVirtualItems(String path) async {
    final list =
        path == _virtualRecentPath ? _recentItems : _favoriteItems;
    final items = <FileItem>[];
    for (final itemPath in list) {
      final type = FileSystemEntity.typeSync(itemPath);
      if (type == FileSystemEntityType.notFound) {
        continue;
      }
      final stat = await FileStat.stat(itemPath);
      final isDir = type == FileSystemEntityType.directory;
      items.add(
        FileItem(
          path: itemPath,
          name: itemPath.split(Platform.pathSeparator).last,
          isDirectory: isDir,
          sizeBytes: isDir ? 0 : stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }
    return items;
  }

  Future<void> _updateGitStatusForPane(_PaneData pane) async {
    if (_isVirtualPath(pane.currentPath)) {
      return;
    }
    final root = await _gitRootForPath(pane.currentPath);
    if (root == null) {
      if (!mounted) return;
      setState(() {
        _gitStatusByPath.clear();
        pane.gitRoot = null;
      });
      return;
    }
    final statusMap = await _loadGitStatus(root);
    if (statusMap.isEmpty) {
      if (!mounted) return;
      setState(() {
        _gitStatusByPath.clear();
        pane.gitRoot = root;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _gitStatusByPath
        ..clear()
        ..addAll(statusMap);
      pane.gitRoot = root;
    });
  }

  Future<String?> _gitRootForPath(String path) async {
    try {
      final result =
          await Process.run('git', ['-C', path, 'rev-parse', '--show-toplevel']);
      if (result.exitCode != 0) {
        return null;
      }
      final root = (result.stdout as String).trim();
      return root.isEmpty ? null : root;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _loadGitStatus(String root) async {
    try {
      final result = await Process.run(
        'git',
        ['-C', root, 'status', '--porcelain'],
      );
      if (result.exitCode != 0) {
        return {};
      }
      final map = <String, String>{};
      final lines = (result.stdout as String).split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty || line.length < 3) continue;
        final status = line.substring(0, 2);
        var path = line.substring(3).trim();
        if (path.contains('->')) {
          path = path.split('->').last.trim();
        }
        final code = _gitStatusCode(status);
        map[_joinPath(root, path)] = code;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  String _gitStatusCode(String status) {
    if (status.contains('?')) return '?';
    if (status.contains('A')) return 'A';
    if (status.contains('M')) return 'M';
    if (status.contains('D')) return 'D';
    return status.trim();
  }

  void _pushHistory(String path) {
    final pane = _activePane;
    if (pane.historyIndex < pane.history.length - 1) {
      pane.history.removeRange(pane.historyIndex + 1, pane.history.length);
    }
    pane.history.add(path);
    pane.historyIndex = pane.history.length - 1;
    _historyVisits[path] = (_historyVisits[path] ?? 0) + 1;
    _historyLastVisited[path] = DateTime.now();
    _syncActiveTab();
  }

  void _navigateTo(String path, {bool addToHistory = true}) {
    _navigateToPane(path, _activePane, addToHistory: addToHistory);
  }

  void _navigateToPane(String path, _PaneData pane,
      {bool addToHistory = true}) {
    if (path == pane.currentPath) {
      return;
    }
    if (!_isVirtualPath(path) && !Directory(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La ruta no existe: $path')),
      );
      pane.pathController.text = pane.currentPath;
      return;
    }
    setState(() {
      pane.currentPath = path;
      pane.pathController.text = pane.currentPath;
      pane.isEditingPath = false;
    });
    if (addToHistory) {
      if (_activePane == pane) {
        _pushHistory(path);
      } else {
        if (pane.historyIndex < pane.history.length - 1) {
          pane.history.removeRange(pane.historyIndex + 1, pane.history.length);
        }
        pane.history.add(path);
        pane.historyIndex = pane.history.length - 1;
      }
    }
    _syncActiveTab();
    _loadFilesForPane(pane);
  }

  void _goBack() {
    final pane = _activePane;
    if (pane.historyIndex <= 0) {
      return;
    }
    pane.historyIndex -= 1;
    pane.currentPath = pane.history[pane.historyIndex];
    pane.pathController.text = pane.currentPath;
    _loadFilesForPane(pane);
    setState(() {});
    _syncActiveTab();
  }

  void _goForward() {
    final pane = _activePane;
    if (pane.historyIndex >= pane.history.length - 1) {
      return;
    }
    pane.historyIndex += 1;
    pane.currentPath = pane.history[pane.historyIndex];
    pane.pathController.text = pane.currentPath;
    _loadFilesForPane(pane);
    setState(() {});
    _syncActiveTab();
  }

  void _goUp() {
    final parent = Directory(_currentPath).parent.path;
    if (parent == _currentPath) {
      return;
    }
    _navigateTo(parent);
  }

  Future<void> _openItem(FileItem item) async {
    if (item.isDirectory) {
      _addRecent(item.path);
      _navigateTo(item.path);
      return;
    }
    if (_isArchiveFile(item)) {
      _addRecent(item.path);
      await _openArchive(item);
      return;
    }
    try {
      _addRecent(item.path);
      await Process.start('xdg-open', [item.path]);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir ${item.name}.'),
        ),
      );
    }
  }

  Future<void> _showProperties(FileItem item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Propiedades'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Tipo',
                value: item.isDirectory ? 'Carpeta' : 'Archivo',
              ),
              _DetailRow(
                label: 'Tamaño',
                value:
                    item.isDirectory ? '--' : _formatBytes(item.sizeBytes),
              ),
              _DetailRow(
                label: 'Modificado',
                value: _formatDate(item.modifiedAt),
              ),
              _DetailRow(
                label: 'Ruta',
                value: item.path,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  bool _isArchiveFile(FileItem item) {
    if (item.isDirectory) return false;
    return _isArchivePath(item.path);
  }

  Future<void> _toggleExecutable(FileItem item) async {
    if (item.isDirectory) {
      return;
    }
    try {
      final isExec = await _fileService.isExecutable(item.path);
      await _fileService.setExecutable(item.path, executable: !isExec);
      _loadFiles();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cambiar permisos.')),
      );
    }
  }

  bool _isVirtualPath(String path) {
    return path == _virtualRecentPath || path == _virtualFavoritesPath;
  }

  Future<void> _openArchive(FileItem item) async {
    final cached = _archiveCache[item.path];
    if (cached != null && Directory(cached).existsSync()) {
      _navigateTo(cached);
      return;
    }
    final home = Platform.environment['HOME'] ?? '/tmp';
    final safeName = base64Url.encode(utf8.encode(item.path));
    final destDir =
        '$home/.cache/file_manager/archives/$safeName';
    try {
      await _fileService.extractArchive(item.path, destDir);
      _archiveCache[item.path] = destDir;
      _navigateTo(destDir);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el archivo comprimido.')),
      );
    }
  }

  void _selectItem(
    FileItem item, {
    required int index,
    required List<FileItem> items,
  }) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final isCtrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
    final isShift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);

    setState(() {
      if (isShift && _lastSelectedIndex != null) {
        final start = _lastSelectedIndex!.clamp(0, items.length - 1);
        final end = index.clamp(0, items.length - 1);
        final rangeStart = start < end ? start : end;
        final rangeEnd = start < end ? end : start;
        _selectedPaths.clear();
        for (var i = rangeStart; i <= rangeEnd; i++) {
          _selectedPaths.add(items[i].path);
        }
      } else if (isCtrl) {
        if (_selectedPaths.contains(item.path)) {
          _selectedPaths.remove(item.path);
        } else {
          _selectedPaths.add(item.path);
        }
        _lastSelectedIndex = index;
      } else {
        _selectedPaths
          ..clear()
          ..add(item.path);
        _lastSelectedIndex = index;
      }
    });
    _precacheIfImage(item);
    _syncActiveTab();
  }

  void _selectItemForPane(
    FileItem item,
    int index,
    List<FileItem> items,
    bool isRight,
  ) {
    _activatePane(isRight);
    _selectItem(item, index: index, items: items);
  }

  void _openItemForPane(FileItem item, bool isRight) {
    _activatePane(isRight);
    _openItem(item);
  }

  void _showItemContextMenuForPane(
    FileItem item,
    Offset position,
    bool isRight,
  ) {
    _activatePane(isRight);
    _showItemContextMenu(item, position);
  }

  void _showBackgroundContextMenuForPane(
    Offset position,
    bool isRight,
  ) {
    _activatePane(isRight);
    _showBackgroundContextMenu(position);
  }

  void _selectSingle(FileItem item, int index) {
    setState(() {
      _selectedPaths
        ..clear()
        ..add(item.path);
      _lastSelectedIndex = index;
    });
    _precacheIfImage(item);
    _syncActiveTab();
  }

  void _precacheIfImage(FileItem item) {
    if (!_isImageFile(item)) {
      return;
    }
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final target = (_previewSize * pixelRatio).round();
    final provider = ResizeImage(
      FileImage(File(item.path)),
      width: target,
      height: target,
    );
    precacheImage(provider, context);
  }

  int _indexOfItem(FileItem item) {
    final index = _items.indexWhere((it) => it.path == item.path);
    return index == -1 ? 0 : index;
  }

  void _startPathEdit() {
    setState(() {
      _isEditingPath = true;
      _pathController.text = _currentPath;
      _pathController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _pathController.text.length,
      );
    });
    _pathFocusNode.requestFocus();
  }

  void _startPathEditForPane(_PaneData pane) {
    setState(() {
      pane.isEditingPath = true;
      pane.pathController.text = pane.currentPath;
      pane.pathController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: pane.pathController.text.length,
      );
    });
    pane.pathFocusNode.requestFocus();
  }

  void _finishPathEditForPane(
    _PaneData pane, {
    required bool navigate,
  }) {
    final target = pane.pathController.text.trim();
    setState(() {
      pane.isEditingPath = false;
    });
    if (navigate && target.isNotEmpty) {
      _navigateToPane(target, pane);
    } else {
      pane.pathController.text = pane.currentPath;
    }
  }

  void _activatePane(bool isRight) {
    if (_isRightActive == isRight) {
      return;
    }
    setState(() {
      _isRightActive = isRight;
    });
  }

  Future<void> _loadRcloneRemotes() async {
    try {
      final result = await Process.run('rclone', ['listremotes']);
      if (!mounted) return;
      if (result.exitCode != 0) {
        final err = (result.stderr as String?)?.trim();
        if (err != null && err.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('rclone: $err')),
          );
        }
        setState(() {
          _cloudRemotes = [];
        });
        return;
      }
      final lines = (result.stdout as String)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      setState(() {
        _cloudRemotes = lines
            .map((remote) => _CloudRemote(
                  name: remote,
                  mountPoint: _rcloneMountPoint(remote),
                ))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer remotos de rclone.')),
      );
      setState(() {
        _cloudRemotes = [];
      });
    }
  }

  String _rcloneMountPoint(String remote) {
    final name = remote.endsWith(':') ? remote.substring(0, remote.length - 1) : remote;
    return _joinPath(_homePath, _joinPath('Cloud', name));
  }

  bool _isMounted(String mountPoint) {
    final file = File('/proc/mounts');
    if (!file.existsSync()) {
      return false;
    }
    return file
        .readAsLinesSync()
        .any((line) => line.split(' ').length > 1 && line.split(' ')[1] == mountPoint);
  }

  Future<void> _mountRemote(_CloudRemote remote) async {
    final mountPoint = remote.mountPoint;
    try {
      Directory(mountPoint).createSync(recursive: true);
      final result = await Process.run('rclone', [
        'mount',
        remote.name,
        mountPoint,
        '--daemon',
        '--vfs-cache-mode',
        'writes',
      ]);
      if (!mounted) return;
      if (result.exitCode != 0) {
        final err = (result.stderr as String?)?.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err == null || err.isEmpty
                  ? 'No se pudo montar ${remote.name}.'
                  : 'rclone: $err',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Montado ${remote.name}.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo montar ${remote.name}.')),
      );
    }
    _loadRcloneRemotes();
  }

  Future<void> _unmountRemote(_CloudRemote remote) async {
    final mountPoint = remote.mountPoint;
    try {
      final fusermount3 = File('/usr/bin/fusermount3').existsSync();
      final cmd = fusermount3 ? 'fusermount3' : 'fusermount';
      final result = await Process.run(cmd, ['-u', mountPoint]);
      if (!mounted) return;
      if (result.exitCode != 0) {
        final err = (result.stderr as String?)?.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err == null || err.isEmpty
                  ? 'No se pudo desmontar ${remote.name}.'
                  : err,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Desmontado ${remote.name}.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo desmontar ${remote.name}.')),
      );
    }
    _loadRcloneRemotes();
  }

  Future<void> _addCustomPlace() async {
    final name = await _promptText(
      title: 'Nuevo atajo',
      hint: 'Nombre del atajo',
      confirmLabel: 'Guardar',
    );
    if (name == null) return;
    final path = await _promptText(
      title: 'Ruta del atajo',
      hint: 'Ej: /home/usuario/Proyectos',
      confirmLabel: 'Guardar',
    );
    if (path == null) return;
    if (!mounted) return;
    if (!Directory(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La ruta no existe: $path')),
      );
      return;
    }
    setState(() {
      _customPlaces.add(_Place(name, path, AppIcons.bookmark, isCustom: true));
      _saveCustomPlaces(_customPlaces);
      _places = _buildPlaces();
    });
  }

  void _addCustomPlaceFromPath(String path, {String? label}) {
    if (!Directory(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La ruta no existe: $path')),
      );
      return;
    }
    if (_customPlaces.any((p) => p.path == path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El atajo ya existe.')),
      );
      return;
    }
    final name = label ?? path.split(Platform.pathSeparator).last;
    setState(() {
      _customPlaces.add(_Place(name, path, AppIcons.bookmark, isCustom: true));
      _saveCustomPlaces(_customPlaces);
      _places = _buildPlaces();
    });
  }

  void _removeCustomPlace(_Place place) {
    setState(() {
      _customPlaces.removeWhere((p) => p.path == place.path);
      _saveCustomPlaces(_customPlaces);
      _places = _buildPlaces();
    });
  }

  Future<void> _editCustomPlace(_Place place) async {
    final name = await _promptText(
      title: 'Editar atajo',
      hint: 'Nombre del atajo',
      initialValue: place.label,
      confirmLabel: 'Guardar',
    );
    if (name == null) return;
    final path = await _promptText(
      title: 'Editar ruta',
      hint: 'Ruta del atajo',
      initialValue: place.path,
      confirmLabel: 'Guardar',
    );
    if (path == null) return;
    if (!mounted) return;
    if (!Directory(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La ruta no existe: $path')),
      );
      return;
    }
    setState(() {
      _customPlaces = _customPlaces
          .map((p) => p.path == place.path
              ? _Place(name, path, AppIcons.bookmark, isCustom: true)
              : p)
          .toList();
      _saveCustomPlaces(_customPlaces);
      _places = _buildPlaces();
    });
  }

  List<_Place> _buildPlaces() {
    final places = <_Place>[
      const _Place.header('Carpetas'),
      _Place('Home', _homePath, AppIcons.home),
      _Place('Favoritos', _virtualFavoritesPath, AppIcons.bookmark),
      _Place('Recientes', _virtualRecentPath, AppIcons.clock),
    ];

    final xdg = _loadXdgUserDirs(_homePath);
    final orderedKeys = <String>[
      'DESKTOP',
      'DOCUMENTS',
      'DOWNLOAD',
      'PICTURES',
      'MUSIC',
      'VIDEOS',
    ];
    final labels = <String, String>{
      'DESKTOP': 'Escritorio',
      'DOCUMENTS': 'Documentos',
      'DOWNLOAD': 'Descargas',
      'PICTURES': 'Imágenes',
      'MUSIC': 'Música',
      'VIDEOS': 'Videos',
    };
    final icons = <String, IconData>{
      'DESKTOP': AppIcons.desktop,
      'DOCUMENTS': AppIcons.documents,
      'DOWNLOAD': AppIcons.downloads,
      'PICTURES': AppIcons.pictures,
      'MUSIC': AppIcons.music,
      'VIDEOS': AppIcons.videos,
    };

    for (final key in orderedKeys) {
      final path = xdg[key] ?? _joinPath(_homePath, labels[key] ?? key);
      if (Directory(path).existsSync()) {
        places.add(_Place(labels[key] ?? key, path, icons[key]!));
      }
    }

    places.add(const _Place.header('Sistema'));
    places.add(const _Place('Root', '/', AppIcons.root));
    final trashPath = _joinPath(_homePath, '.local/share/Trash/files');
    if (Directory(trashPath).existsSync()) {
      places.add(_Place('Papelera', trashPath, AppIcons.delete));
    }
    for (final custom in _customPlaces) {
      if (Directory(custom.path).existsSync()) {
        places.add(custom);
      }
    }

    final mountGroups = _loadMounts();
    if (mountGroups.removable.isNotEmpty) {
      places.add(const _Place.header('Dispositivos extraíbles'));
      places.addAll(mountGroups.removable);
    }
    if (mountGroups.other.isNotEmpty) {
      places.add(const _Place.header('Dispositivos'));
      places.addAll(mountGroups.other);
    }
    return places;
  }

  Map<String, String> _loadXdgUserDirs(String homePath) {
    final result = <String, String>{};
    final file = File(_joinPath(homePath, '.config/user-dirs.dirs'));
    if (!file.existsSync()) {
      return result;
    }
    final lines = file.readAsLinesSync();
    final regex = RegExp(r'^XDG_(\\w+)_DIR=\"(.+)\"');
    for (final line in lines) {
      final match = regex.firstMatch(line.trim());
      if (match == null) continue;
      final key = match.group(1) ?? '';
      var value = match.group(2) ?? '';
      value = value.replaceAll(r'\$HOME', homePath);
      if (!value.startsWith(Platform.pathSeparator)) {
        value = _joinPath(homePath, value);
      }
      if (key.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }

  _MountGroups _loadMounts() {
    final removable = <_Place>[];
    final other = <_Place>[];
    final user = Platform.environment['USER'] ?? '';
    final removablePrefixes = <String>[
      _joinPath('/run/media', user),
      '/media',
    ];
    final otherPrefixes = <String>['/mnt'];
    final excludedPrefixes = <String>[
      '/proc',
      '/sys',
      '/dev',
      '/run',
      '/snap',
      '/var/lib',
    ];

    final file = File('/proc/mounts');
    if (!file.existsSync()) {
      return _MountGroups(removable: removable, other: other);
    }

    for (final line in file.readAsLinesSync()) {
      final parts = line.split(' ');
      if (parts.length < 2) continue;
      final mountPoint = parts[1];
      if (excludedPrefixes.any((p) => mountPoint.startsWith(p))) {
        continue;
      }
      final usage = _mountUsage(mountPoint);
      if (removablePrefixes.any((p) => p.isNotEmpty && mountPoint.startsWith(p))) {
        final label = mountPoint.split(Platform.pathSeparator).last;
        removable.add(
          _Place(
            label,
            mountPoint,
            AppIcons.usb,
            subtitle: usage?.label,
            usagePercent: usage?.percent,
          ),
        );
        continue;
      }
      if (otherPrefixes.any((p) => mountPoint.startsWith(p))) {
        final label = mountPoint.split(Platform.pathSeparator).last;
        other.add(
          _Place(
            label,
            mountPoint,
            AppIcons.drive,
            subtitle: usage?.label,
            usagePercent: usage?.percent,
          ),
        );
      }
    }

    return _MountGroups(removable: removable, other: other);
  }

  _MountUsage? _mountUsage(String mountPoint) {
    try {
      final result = Process.runSync('df', ['-P', mountPoint]);
      if (result.exitCode != 0) {
        return null;
      }
      final lines = (result.stdout as String).trim().split('\n');
      if (lines.length < 2) return null;
      final parts = lines[1].split(RegExp(r'\s+'));
      if (parts.length < 6) return null;
      final total = int.tryParse(parts[1]) ?? 0;
      final available = int.tryParse(parts[3]) ?? 0;
      final percentRaw = parts[4].replaceAll('%', '');
      final percent = int.tryParse(percentRaw);
      if (total <= 0) return null;
      final label =
          '${_formatBytes(available * 1024)} libres · ${_formatBytes(total * 1024)}';
      return _MountUsage(label: label, percent: percent ?? 0);
    } catch (_) {
      return null;
    }
  }

  List<_Place> _loadCustomPlaces() {
    final file = File(_placesConfigPath());
    if (!file.existsSync()) {
      return [];
    }
    try {
      final data = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map((entry) => _Place(
                entry['label'] as String? ?? 'Atajo',
                entry['path'] as String? ?? '',
                AppIcons.bookmark,
                isCustom: true,
              ))
          .where((place) => place.path.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _saveCustomPlaces(List<_Place> places) {
    final dir = Directory(_placesConfigDir());
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(_placesConfigPath());
    final data = places
        .map((place) => {
              'label': place.label,
              'path': place.path,
            })
        .toList();
    file.writeAsStringSync(jsonEncode(data));
  }

  String _placesConfigDir() {
    return _joinPath(_homePath, '.config/file_manager');
  }

  String _placesConfigPath() {
    return _joinPath(_placesConfigDir(), 'places.json');
  }

  void _changePreviewSize(double delta) {
    setState(() {
      _previewSize = (_previewSize + delta).clamp(120, 360);
    });
    _saveSettings();
  }

  void _copyToMemorySelection({required bool asRoot}) {
    if (_selectedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un elemento.')),
      );
      return;
    }
    setState(() {
      _memoryClipboardPaths = _selectedPaths.toList();
      _memoryClipboardAsRoot = asRoot;
      _memoryClipboardIsCut = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          asRoot ? 'Copiado (root) en memoria.' : 'Copiado en memoria.',
        ),
      ),
    );
  }

  void _cutToMemorySelection({required bool asRoot}) {
    if (_selectedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un elemento.')),
      );
      return;
    }
    setState(() {
      _memoryClipboardPaths = _selectedPaths.toList();
      _memoryClipboardAsRoot = asRoot;
      _memoryClipboardIsCut = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          asRoot ? 'Cortado (root) en memoria.' : 'Cortado en memoria.',
        ),
      ),
    );
  }

  Future<void> _pasteFromMemory({required bool asRoot}) async {
    if (_memoryClipboardPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay nada en memoria.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Procesando ${_memoryClipboardPaths.length} elemento(s)...'),
      ),
    );
    final movedPairs = <_MovePair>[];
    for (final sourcePath in _memoryClipboardPaths) {
      final name = sourcePath.split(Platform.pathSeparator).last;
      final destPath = _joinPath(_currentPath, name);
      try {
        if (_memoryClipboardIsCut) {
          if (asRoot) {
            await _moveAsRoot(sourcePath, destPath);
          } else {
            await _fileService.moveEntity(sourcePath, destPath);
          }
          movedPairs.add(_MovePair(from: sourcePath, to: destPath));
        } else {
          if (asRoot) {
            await _copyAsRoot(sourcePath, destPath);
          } else {
            await _fileService.copyEntity(sourcePath, destPath);
          }
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo pegar.')),
        );
        return;
      }
    }
    if (_memoryClipboardIsCut) {
      setState(() {
        _memoryClipboardPaths = [];
        _memoryClipboardIsCut = false;
      });
      _lastAction = _LastAction.move(movedPairs);
    }
    _loadFiles();
  }

  Future<void> _copyAsRoot(String sourcePath, String destPath) async {
    final type = FileSystemEntity.typeSync(sourcePath);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('No existe', sourcePath);
    }
    final args = <String>['cp'];
    if (type == FileSystemEntityType.directory) {
      args.add('-r');
    }
    args.addAll([sourcePath, destPath]);
    final process = await Process.start('pkexec', args);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw FileSystemException('Copiado root falló', sourcePath);
    }
  }

  Future<void> _moveAsRoot(String sourcePath, String destPath) async {
    final process = await Process.start('pkexec', [
      'mv',
      sourcePath,
      destPath,
    ]);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw FileSystemException('Mover root falló', sourcePath);
    }
  }

  Future<void> _openTerminalHere() async {
    final candidates = <List<String>>[
      ['konsole', '--workdir', _currentPath],
      ['gnome-terminal', '--working-directory', _currentPath],
      ['xfce4-terminal', '--working-directory', _currentPath],
      ['x-terminal-emulator', '--working-directory', _currentPath],
      ['xterm', '-e', 'cd', _currentPath, '&&', 'bash'],
    ];
    for (final cmd in candidates) {
      try {
        await Process.start(cmd.first, cmd.sublist(1));
        return;
      } catch (_) {
        continue;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir una terminal.')),
    );
  }

  Future<void> _emptyTrash() async {
    final ok = await _confirm(
      title: 'Vaciar papelera',
      message: 'Eliminar permanentemente todos los elementos de la papelera?',
      confirmLabel: 'Vaciar',
    );
    if (!ok) return;
    try {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) {
        throw const FileSystemException('HOME no disponible');
      }
      final trashFiles = Directory('$home/.local/share/Trash/files');
      if (trashFiles.existsSync()) {
        await trashFiles.delete(recursive: true);
        trashFiles.createSync(recursive: true);
      }
      final trashInfo = Directory('$home/.local/share/Trash/info');
      if (trashInfo.existsSync()) {
        await trashInfo.delete(recursive: true);
        trashInfo.createSync(recursive: true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Papelera vaciada.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo vaciar la papelera.')),
      );
    }
  }

  Future<void> _deleteSelectedPermanently() async {
    if (_selectedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un elemento.')),
      );
      return;
    }
    final ok = await _confirm(
      title: 'Eliminar definitivamente',
      message: _selectedPaths.length == 1
          ? 'Eliminar "${_selectedItem?.name}" de forma permanente?'
          : 'Eliminar ${_selectedPaths.length} elementos de forma permanente?',
      confirmLabel: 'Eliminar',
    );
    if (!ok) return;
    final confirmText = await _promptText(
      title: 'Confirmar eliminación',
      hint: 'Escribe ELIMINAR para confirmar',
      confirmLabel: 'Confirmar',
    );
    if (confirmText != 'ELIMINAR') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirmación cancelada.')),
      );
      return;
    }
    try {
      for (final path in _selectedPaths.toList()) {
        await _fileService.deleteEntity(path);
      }
      setState(() => _selectedPaths.clear());
      _loadFiles();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar.')),
      );
    }
  }

  Future<void> _openWithSelected() async {
    final selected = _selectedItem;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un archivo primero.')),
      );
      return;
    }
    try {
      await Process.start('xdg-open', [selected.path]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir con la app.')),
      );
    }
  }

  Future<void> _extractArchiveHere(FileItem item) async {
    if (!_isArchiveFile(item)) {
      return;
    }
    try {
      await _fileService.extractArchive(item.path, _currentPath);
      _loadFiles();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descomprimir.')),
      );
    }
  }

  Future<void> _compressSelected() async {
    if (_selectedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un elemento.')),
      );
      return;
    }
    final invalid = _selectedPaths.any(
      (path) => !path.startsWith('$_currentPath${Platform.pathSeparator}'),
    );
    if (invalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se pueden comprimir elementos de la carpeta actual.'),
        ),
      );
      return;
    }
    final format = await _promptArchiveFormat();
    if (format == null) return;
    final name = await _promptText(
      title: 'Nombre del archivo comprimido',
      hint: 'archivo',
      confirmLabel: 'Crear',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final ext = _formatExtension(format);
    final outputName = name.toLowerCase().endsWith(ext)
        ? name
        : '$name$ext';
    final outputPath = _joinPath(_currentPath, outputName);
    try {
      final relative = _selectedPaths.map((path) {
        if (path.startsWith('$_currentPath${Platform.pathSeparator}')) {
          return path.substring(_currentPath.length + 1);
        }
        return path.split(Platform.pathSeparator).last;
      }).toList();
      await _fileService.createArchive(
        baseDir: _currentPath,
        relativePaths: relative,
        outputPath: outputPath,
        format: format,
      );
      _loadFiles();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo comprimir.')),
      );
    }
  }

  void _addRecent(String path) {
    _recentItems.remove(path);
    _recentItems.insert(0, path);
    if (_recentItems.length > 50) {
      _recentItems = _recentItems.sublist(0, 50);
    }
    _saveSettings();
  }

  void _toggleFavorite(String path) {
    if (_favoriteItems.contains(path)) {
      _favoriteItems.remove(path);
    } else {
      _favoriteItems.insert(0, path);
    }
    _saveSettings();
    setState(() {});
  }

  String _formatExtension(String format) {
    switch (format) {
      case 'zip':
        return '.zip';
      case 'tar':
        return '.tar';
      case 'tar.gz':
        return '.tar.gz';
      case 'tar.xz':
        return '.tar.xz';
      case 'tar.bz2':
        return '.tar.bz2';
      case '7z':
        return '.7z';
      case 'rar':
        return '.rar';
      default:
        return '.zip';
    }
  }

  Future<String?> _promptArchiveFormat() async {
    String selected = 'zip';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Formato de compresión'),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButton<String>(
            value: selected,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'zip', child: Text('ZIP (.zip)')),
              DropdownMenuItem(value: 'tar', child: Text('TAR (.tar)')),
              DropdownMenuItem(value: 'tar.gz', child: Text('TAR.GZ (.tar.gz)')),
              DropdownMenuItem(value: 'tar.xz', child: Text('TAR.XZ (.tar.xz)')),
              DropdownMenuItem(value: 'tar.bz2', child: Text('TAR.BZ2 (.tar.bz2)')),
              DropdownMenuItem(value: '7z', child: Text('7Z (.7z)')),
              DropdownMenuItem(value: 'rar', child: Text('RAR (.rar)')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => selected = value);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    return result;
  }

  FileItem? get _selectedItem {
    if (_selectedPaths.length != 1) {
      return null;
    }
    final path = _selectedPaths.first;
    for (final item in _items) {
      if (item.path == path) {
        return item;
      }
    }
    return null;
  }

  int get _selectedCount => _selectedPaths.length;

  String _joinPath(String base, String name) {
    if (base.endsWith(Platform.pathSeparator)) {
      return '$base$name';
    }
    return '$base${Platform.pathSeparator}$name';
  }

  Future<String?> _promptText({
    required String title,
    required String hint,
    String? initialValue,
    String confirmLabel = 'Aceptar',
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result?.isEmpty ?? true ? null : result;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _createFolder() async {
    final name = await _promptText(
      title: 'Nueva carpeta',
      hint: 'Nombre de la carpeta',
      confirmLabel: 'Crear',
    );
    if (name == null) {
      return;
    }
    try {
      final newPath = _joinPath(_currentPath, name);
      await _fileService.createDirectory(newPath);
      _addRecent(newPath);
      _loadFiles();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la carpeta.')),
      );
    }
  }

  Future<void> _renameSelected() async {
    final selected = _selectedItem;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona solo un elemento para renombrar.'),
        ),
      );
      return;
    }
    final newName = await _promptText(
      title: 'Renombrar',
      hint: 'Nuevo nombre',
      initialValue: selected.name,
      confirmLabel: 'Renombrar',
    );
    if (newName == null || newName == selected.name) {
      return;
    }
    try {
      final newPath = await _fileService.renameEntity(selected.path, newName);
      setState(() {
        _selectedPaths
          ..clear()
          ..add(newPath);
      });
      _migrateTagPath(selected.path, newPath);
      _loadFiles();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo renombrar.')),
      );
    }
  }

  Future<void> _bulkRenameSelected() async {
    if (_selectedPaths.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos dos elementos para renombrar.'),
        ),
      );
      return;
    }
    final config = await _promptBulkRenameConfig();
    if (config == null) {
      return;
    }
    final selectedItems = _selectedPaths
        .map((path) => _items.firstWhere((item) => item.path == path))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final padding = selectedItems.length.toString().length;
    var counter = 1;
    RegExp? renameRegex;
    if (config.useRegex && config.find.isNotEmpty) {
      try {
        renameRegex = RegExp(config.find);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Regex inválido.')),
        );
        return;
      }
    }
    for (final item in selectedItems) {
      final dir = item.path.substring(
        0,
        item.path.lastIndexOf(Platform.pathSeparator),
      );
      final dotIndex = item.name.lastIndexOf('.');
      final hasExt = dotIndex > 0 && !item.isDirectory;
      final baseName =
          hasExt ? item.name.substring(0, dotIndex) : item.name;
      final ext = hasExt ? item.name.substring(dotIndex) : '';
      var newName = config.format
          .replaceAll('{name}', baseName)
          .replaceAll('{ext}', ext)
          .replaceAll('{n}', counter.toString().padLeft(padding, '0'));
      if (!config.format.contains('{ext}') && hasExt) {
        newName = '$newName$ext';
      }
      if (renameRegex != null) {
        newName = newName.replaceAll(renameRegex, config.replace);
      }
      newName = _uniqueNameInDir(dir, newName);
      try {
        final newPath = await _fileService.renameEntity(item.path, newName);
        _migrateTagPath(item.path, newPath);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo renombrar ${item.name}.')),
        );
      }
      counter++;
    }
    _loadFiles();
  }

  Future<void> _duplicateSelected() async {
    if (_selectedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un elemento.')),
      );
      return;
    }
    final selectedItems = _selectedPaths
        .map((path) => _items.firstWhere((item) => item.path == path))
        .toList();
    for (final item in selectedItems) {
      final dir = item.path.substring(
        0,
        item.path.lastIndexOf(Platform.pathSeparator),
      );
      final dotIndex = item.name.lastIndexOf('.');
      final hasExt = dotIndex > 0 && !item.isDirectory;
      final baseName =
          hasExt ? item.name.substring(0, dotIndex) : item.name;
      final ext = hasExt ? item.name.substring(dotIndex) : '';
      final candidate = '$baseName (copia)$ext';
      final newName = _uniqueNameInDir(dir, candidate);
      final destPath = _joinPath(dir, newName);
      try {
        await _fileService.copyEntity(item.path, destPath);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo duplicar ${item.name}.')),
        );
      }
    }
    _loadFiles();
  }

  String _uniqueNameInDir(String dir, String name) {
    var candidate = name;
    var counter = 2;
    while (FileSystemEntity.typeSync(_joinPath(dir, candidate)) !=
        FileSystemEntityType.notFound) {
      final dotIndex = candidate.lastIndexOf('.');
      final hasExt = dotIndex > 0;
      final base = hasExt ? candidate.substring(0, dotIndex) : candidate;
      final ext = hasExt ? candidate.substring(dotIndex) : '';
      candidate = '$base $counter$ext';
      counter++;
    }
    return candidate;
  }

  String? _gitStatusForPath(String path) => _gitStatusByPath[path];

  Future<_BulkRenameConfig?> _promptBulkRenameConfig() async {
    final formatController = TextEditingController(text: '{name}{ext}');
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    final presetNameController = TextEditingController();
    String? selectedPreset;
    bool useRegex = false;
    _BulkRenameConfig? result;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Renombrar en masa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_renamePresets.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedPreset,
                    decoration: const InputDecoration(
                      labelText: 'Preset',
                    ),
                    items: _renamePresets
                        .map(
                          (preset) => DropdownMenuItem(
                            value: preset.name,
                            child: Text(preset.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final preset = _renamePresets
                          .firstWhere((p) => p.name == value);
                      setState(() {
                        selectedPreset = value;
                        formatController.text = preset.format;
                        findController.text = preset.find;
                        replaceController.text = preset.replace;
                        useRegex = preset.useRegex;
                      });
                    },
                  ),
                TextField(
                  controller: formatController,
                  decoration: const InputDecoration(
                    labelText: 'Formato',
                    hintText: '{name}_{n}{ext}',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: useRegex,
                      onChanged: (value) {
                        setState(() => useRegex = value ?? false);
                      },
                    ),
                    const Text('Regex buscar/reemplazar'),
                  ],
                ),
                TextField(
                  controller: findController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar (regex)',
                  ),
                ),
                TextField(
                  controller: replaceController,
                  decoration: const InputDecoration(
                    labelText: 'Reemplazar',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: presetNameController,
                  decoration: const InputDecoration(
                    labelText: 'Guardar preset como',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final name = presetNameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                final preset = _RenamePreset(
                  name: name,
                  format: formatController.text.trim().isEmpty
                      ? '{name}{ext}'
                      : formatController.text.trim(),
                  find: findController.text.trim(),
                  replace: replaceController.text,
                  useRegex: useRegex,
                );
                setState(() {
                  _renamePresets.removeWhere((p) => p.name == name);
                  _renamePresets.add(preset);
                  selectedPreset = name;
                });
                _saveSettings();
              },
              child: const Text('Guardar preset'),
            ),
            FilledButton(
              onPressed: () {
                final format = formatController.text.trim();
                if (format.isEmpty) {
                  return;
                }
                result = _BulkRenameConfig(
                  format: format,
                  find: findController.text.trim(),
                  replace: replaceController.text,
                  useRegex: useRegex,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _deleteSelected() async {
    if (_selectedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un elemento.')),
      );
      return;
    }
    final ok = await _confirm(
      title: 'Mover a papelera',
      message: _selectedPaths.length == 1
          ? 'Mover "${_selectedItem?.name}" a la papelera?'
          : 'Mover ${_selectedPaths.length} elementos a la papelera?',
      confirmLabel: 'Mover',
    );
    if (!ok) {
      return;
    }
    try {
      for (final path in _selectedPaths.toList()) {
        await _fileService.moveToTrash(path);
      }
      _removeTagsForPaths(_selectedPaths);
      setState(() {
        _selectedPaths.clear();
      });
      _loadFiles();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo mover a la papelera.')),
      );
    }
  }

  Future<void> _copySelected() async {
    if (_selectedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un elemento.')),
      );
      return;
    }
    final destDir = await _promptText(
      title: 'Copiar a',
      hint: 'Ruta de destino',
      initialValue: _currentPath,
      confirmLabel: 'Copiar',
    );
    if (destDir == null) {
      return;
    }
    try {
      for (final path in _selectedPaths) {
        final name = path.split(Platform.pathSeparator).last;
        final destPath = _joinPath(destDir, name);
        await _fileService.copyEntity(path, destPath);
      }
      _loadFiles();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo copiar.')),
      );
    }
  }

  Future<void> _moveSelected() async {
    if (_selectedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un elemento.')),
      );
      return;
    }
    final destDir = await _promptText(
      title: 'Mover a',
      hint: 'Ruta de destino',
      initialValue: _currentPath,
      confirmLabel: 'Mover',
    );
    if (destDir == null) {
      return;
    }
    try {
      final movedPairs = <_MovePair>[];
      for (final path in _selectedPaths) {
        final name = path.split(Platform.pathSeparator).last;
        final destPath = _joinPath(destDir, name);
        await _fileService.moveEntity(path, destPath);
        movedPairs.add(_MovePair(from: path, to: destPath));
        _migrateTagPath(path, destPath);
      }
      setState(() {
        _selectedPaths.clear();
      });
      _lastAction = _LastAction.move(movedPairs);
      _loadFiles();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo mover.')),
      );
    }
  }

  Future<void> _undoLastAction() async {
    final action = _lastAction;
    if (action == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay acciones para deshacer.')),
      );
      return;
    }
    switch (action.type) {
      case _LastActionType.move:
        try {
          for (final pair in action.moves) {
            if (FileSystemEntity.typeSync(pair.to) ==
                FileSystemEntityType.notFound) {
              continue;
            }
            await _fileService.moveEntity(pair.to, pair.from);
          }
          _lastAction = null;
          _loadFiles();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deshacer completado.')),
          );
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo deshacer.')),
          );
        }
        break;
    }
  }

  Future<void> _moveItemToFolder(
    FileItem source,
    FileItem destination, {
    bool? copy,
  }) async {
    if (!destination.isDirectory) {
      return;
    }
    final destPath = _joinPath(destination.path, source.name);
    if (destPath == source.path) {
      return;
    }
    if (source.isDirectory &&
        destination.path.startsWith('${source.path}${Platform.pathSeparator}')) {
      return;
    }
    final resolvedCopy = copy ?? _resolveDragDropAction();
    final doCopy = resolvedCopy ?? await _promptMoveOrCopy();
    if (doCopy == null) {
      return;
    }
    try {
      if (doCopy) {
        await _fileService.copyEntity(source.path, destPath);
        final tag = _tagForPath(source.path);
        if (tag != null) {
          _tagsByPath[destPath] = tag;
          _saveSettings();
        }
      } else {
        await _fileService.moveEntity(source.path, destPath);
        _migrateTagPath(source.path, destPath);
      }
      setState(() {
        _selectedPaths.clear();
      });
      _refreshAfterMove(source.path, destination.path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo mover el elemento.')),
      );
    }
  }

  Future<void> _moveItemToPath(
    FileItem source,
    String destDir, {
    bool? copy,
  }) async {
    final destPath = _joinPath(destDir, source.name);
    if (destPath == source.path) {
      return;
    }
    if (source.isDirectory &&
        destDir.startsWith('${source.path}${Platform.pathSeparator}')) {
      return;
    }
    final resolvedCopy = copy ?? _resolveDragDropAction();
    final doCopy = resolvedCopy ?? await _promptMoveOrCopy();
    if (doCopy == null) {
      return;
    }
    try {
      if (doCopy) {
        await _fileService.copyEntity(source.path, destPath);
        final tag = _tagForPath(source.path);
        if (tag != null) {
          _tagsByPath[destPath] = tag;
          _saveSettings();
        }
      } else {
        await _fileService.moveEntity(source.path, destPath);
        _migrateTagPath(source.path, destPath);
      }
      setState(() {
        _selectedPaths.clear();
      });
      _refreshAfterMove(source.path, destDir);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo mover el elemento.')),
      );
    }
  }

  void _refreshAfterMove(String sourcePath, String destDir) {
    _loadFilesForPane(_leftPane);
    _loadFilesForPane(_rightPane);
    if (_activePane.currentPath == destDir ||
        _activePane.currentPath == sourcePath) {
      _loadFiles();
    }
  }

  bool? _resolveDragDropAction() {
    switch (_dragDropDefaultAction) {
      case 'copy':
        return true;
      case 'move':
        return false;
      default:
        return null;
    }
  }

  Future<bool?> _promptMoveOrCopy() async {
    bool rememberChoice = false;
    String? selection;
    return showDialog<bool?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Acción de arrastre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Qué querés hacer con el archivo?'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: rememberChoice,
                onChanged: (value) {
                  setState(() => rememberChoice = value ?? false);
                },
                title: const Text('Recordar mi elección'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                selection = 'copy';
                Navigator.of(context).pop(true);
              },
              child: const Text('Copiar'),
            ),
            FilledButton(
              onPressed: () {
                selection = 'move';
                Navigator.of(context).pop(false);
              },
              child: const Text('Mover'),
            ),
          ],
        ),
      ),
    ).then((value) {
      if (rememberChoice && selection != null) {
        _dragDropDefaultAction = selection!;
        _saveSettings();
      }
      return value;
    });
  }

  Future<void> _showItemContextMenu(
    FileItem item,
    Offset position,
  ) async {
    _lastItemContextMenuAtMs = DateTime.now().millisecondsSinceEpoch;
    final action = await showMenu<_ItemAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem(
          value: _ItemAction.open,
          child: ListTile(
            leading: Icon(AppIcons.open),
            title: Text('Abrir'),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.openWith,
          child: ListTile(
            leading: Icon(AppIcons.open),
            title: Text('Abrir con...'),
          ),
        ),
        if (item.isDirectory)
          const PopupMenuItem(
            value: _ItemAction.openNewTab,
            child: ListTile(
              leading: Icon(AppIcons.folderOpen),
              title: Text('Abrir en nueva pestaña'),
            ),
          ),
        if (_isArchiveFile(item))
          const PopupMenuItem(
            value: _ItemAction.extractHere,
            child: ListTile(
              leading: Icon(AppIcons.folderOpen),
              title: Text('Descomprimir aquí'),
            ),
          ),
        PopupMenuItem(
          value: _ItemAction.toggleFavorite,
          child: ListTile(
            leading: const Icon(AppIcons.bookmark),
            title: Text(
              _favoriteItems.contains(item.path)
                  ? 'Quitar de favoritos'
                  : 'Agregar a favoritos',
            ),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.properties,
          child: ListTile(
            leading: Icon(AppIcons.info),
            title: Text('Propiedades'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          enabled: false,
          child: Text('Etiquetas'),
        ),
        ..._tagOptions.map(
          (tag) => PopupMenuItem(
            value: tag.action,
            child: ListTile(
              leading: _TagDot(color: tag.color),
              title: Text(tag.label),
            ),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.clearTag,
          child: ListTile(
            leading: Icon(AppIcons.close),
            title: Text('Quitar etiqueta'),
          ),
        ),
        if (!item.isDirectory)
          const PopupMenuItem(
            value: _ItemAction.toggleExecutable,
            child: ListTile(
              leading: Icon(AppIcons.terminal),
              title: Text('Cambiar permiso de ejecución'),
            ),
          ),
        const PopupMenuItem(
          value: _ItemAction.copyMemory,
          child: ListTile(
            leading: Icon(AppIcons.copy),
            title: Text('Copiar en memoria'),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.cutMemory,
          child: ListTile(
            leading: Icon(AppIcons.move),
            title: Text('Cortar en memoria'),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.copyRoot,
          child: ListTile(
            leading: Icon(AppIcons.shield),
            title: Text('Copiar como root'),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.rename,
          child: ListTile(
            leading: Icon(AppIcons.edit),
            title: Text('Renombrar'),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.bulkRename,
          child: ListTile(
            leading: Icon(AppIcons.edit),
            title: Text('Renombrar en masa...'),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.copy,
          child: ListTile(
            leading: Icon(AppIcons.copy),
            title: Text('Copiar'),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.duplicate,
          child: ListTile(
            leading: Icon(AppIcons.copy),
            title: Text('Duplicar'),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.move,
          child: ListTile(
            leading: Icon(AppIcons.move),
            title: Text('Mover'),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.delete,
          child: ListTile(
            leading: Icon(AppIcons.delete),
            title: Text('Eliminar'),
          ),
        ),
        const PopupMenuItem(
          value: _ItemAction.compress,
          child: ListTile(
            leading: Icon(AppIcons.archive),
            title: Text('Comprimir...'),
          ),
        ),
      ],
    );
    if (action == null) {
      return;
    }
    _selectSingle(item, _indexOfItem(item));
    switch (action) {
      case _ItemAction.open:
        _openItem(item);
        break;
      case _ItemAction.openWith:
        _openWithSelected();
        break;
      case _ItemAction.openNewTab:
        _addTab(path: item.path);
        break;
      case _ItemAction.properties:
        _showProperties(item);
        break;
      case _ItemAction.extractHere:
        _extractArchiveHere(item);
        break;
      case _ItemAction.toggleFavorite:
        _toggleFavorite(item.path);
        break;
      case _ItemAction.toggleExecutable:
        _toggleExecutable(item);
        break;
      case _ItemAction.copyMemory:
        _copyToMemorySelection(asRoot: false);
        break;
      case _ItemAction.cutMemory:
        _cutToMemorySelection(asRoot: false);
        break;
      case _ItemAction.copyRoot:
        _copyToMemorySelection(asRoot: true);
        break;
      case _ItemAction.rename:
        _renameSelected();
        break;
      case _ItemAction.bulkRename:
        _bulkRenameSelected();
        break;
      case _ItemAction.copy:
        _copySelected();
        break;
      case _ItemAction.duplicate:
        _duplicateSelected();
        break;
      case _ItemAction.move:
        _moveSelected();
        break;
      case _ItemAction.delete:
        _deleteSelected();
        break;
      case _ItemAction.compress:
        _compressSelected();
        break;
      case _ItemAction.tagRed:
        _applyTagToSelection('red');
        break;
      case _ItemAction.tagOrange:
        _applyTagToSelection('orange');
        break;
      case _ItemAction.tagYellow:
        _applyTagToSelection('yellow');
        break;
      case _ItemAction.tagGreen:
        _applyTagToSelection('green');
        break;
      case _ItemAction.tagBlue:
        _applyTagToSelection('blue');
        break;
      case _ItemAction.tagPurple:
        _applyTagToSelection('purple');
        break;
      case _ItemAction.tagPink:
        _applyTagToSelection('pink');
        break;
      case _ItemAction.tagGray:
        _applyTagToSelection('gray');
        break;
      case _ItemAction.clearTag:
        _applyTagToSelection(null);
        break;
    }
  }

  Future<void> _showBackgroundContextMenu(Offset position) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastItemContextMenuAtMs < 250) {
      return;
    }
    final hasMemory = _memoryClipboardPaths.isNotEmpty;
    final action = await showMenu<_BackgroundAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: _BackgroundAction.addShortcut,
          child: ListTile(
            leading: Icon(AppIcons.add),
            title: Text('Agregar atajo'),
          ),
        ),
        PopupMenuItem(
          value: _BackgroundAction.newFolder,
          child: ListTile(
            leading: Icon(AppIcons.folderPlus),
            title: Text('Nueva carpeta'),
          ),
        ),
        if (hasMemory)
          PopupMenuItem(
            value: _BackgroundAction.pasteMemory,
            child: ListTile(
              leading: Icon(AppIcons.paste),
              title: Text('Pegar desde memoria'),
            ),
          ),
        if (hasMemory)
          PopupMenuItem(
            value: _BackgroundAction.pasteRoot,
            child: ListTile(
              leading: Icon(AppIcons.shield),
              title: Text('Pegar como root'),
            ),
          ),
        PopupMenuItem(
          value: _BackgroundAction.refresh,
          child: ListTile(
            leading: Icon(AppIcons.refresh),
            title: Text('Actualizar'),
          ),
        ),
        PopupMenuItem(
          value: _BackgroundAction.openTerminal,
          child: ListTile(
            leading: Icon(AppIcons.terminal),
            title: Text('Abrir terminal aquí'),
          ),
        ),
        PopupMenuItem(
          value: _BackgroundAction.editPath,
          child: ListTile(
            leading: Icon(AppIcons.edit),
            title: Text('Editar ruta'),
          ),
        ),
        PopupMenuItem(
          value: _BackgroundAction.copyPath,
          child: ListTile(
            leading: Icon(AppIcons.copy),
            title: Text('Copiar ruta'),
          ),
        ),
        const PopupMenuDivider(),
        if (_currentPath != _homePath)
          PopupMenuItem(
            value: _BackgroundAction.goHome,
            child: ListTile(
              leading: Icon(AppIcons.home),
              title: Text('Ir a Home'),
            ),
          ),
        if (_currentPath != '/')
          PopupMenuItem(
            value: _BackgroundAction.goRoot,
            child: ListTile(
              leading: Icon(AppIcons.root),
              title: Text('Ir a /'),
            ),
          ),
        if (_currentPath != '/root')
          PopupMenuItem(
            value: _BackgroundAction.goRootUser,
            child: ListTile(
              leading: Icon(AppIcons.shield),
              title: Text('Ir a /root'),
            ),
          ),
      ],
    );
    if (action == null) {
      return;
    }
    switch (action) {
      case _BackgroundAction.newFolder:
        _createFolder();
        break;
      case _BackgroundAction.addShortcut:
        _addCustomPlace();
        break;
      case _BackgroundAction.refresh:
        _loadFiles();
        break;
      case _BackgroundAction.openTerminal:
        _openTerminalHere();
        break;
      case _BackgroundAction.pasteMemory:
        _pasteFromMemory(asRoot: _memoryClipboardAsRoot);
        break;
      case _BackgroundAction.pasteRoot:
        _pasteFromMemory(asRoot: true);
        break;
      case _BackgroundAction.editPath:
        _startPathEdit();
        break;
      case _BackgroundAction.copyPath:
        await Clipboard.setData(ClipboardData(text: _currentPath));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ruta copiada.')),
        );
        break;
      case _BackgroundAction.goHome:
        _navigateTo(_homePath);
        break;
      case _BackgroundAction.goRoot:
        _navigateTo('/');
        break;
      case _BackgroundAction.goRootUser:
        _navigateTo('/root');
        break;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  List<FileItem> get _visibleItems => _visibleItemsForPane(_activePane);

  List<FileItem> _visibleItemsForPane(_PaneData pane) {
    final query = pane.searchQuery;
    if (_isGlobalSearchActive(query)) {
      if (_globalSearchLoading || _globalSearchError != null) {
        return [];
      }
      final results = _filterByQuery(
        query,
        allItems: _globalSearchItems,
        searchIndex: _globalSearchIndex,
        gitStatusForPath: _gitStatusForPath,
      );
      return _sortItems(results);
    }
    final filtered = _showHidden
        ? pane.items
        : pane.items.where((item) => !item.name.startsWith('.')).toList();
    final base = pane.searchQuery.trim().isEmpty
        ? filtered
        : _filterByQuery(
            pane.searchQuery,
            baseItems: filtered,
            searchIndex: pane.searchIndex,
            allItems: pane.items,
            gitStatusForPath: _gitStatusForPath,
          );
    return _sortItems(base);
  }

  bool _isGlobalSearchActive(String query) {
    return _globalSearchEnabled && query.trim().isNotEmpty;
  }

  Future<void> _ensureGlobalSearchIndex({bool force = false}) async {
    if (_globalSearchLoading) {
      return;
    }
    if (!force && _globalSearchItems.isNotEmpty) {
      return;
    }
    setState(() {
      _globalSearchLoading = true;
      _globalSearchError = null;
    });
    try {
      if (!force) {
        final cached = _loadGlobalSearchCache();
        if (cached != null) {
          setState(() {
            _globalSearchItems = cached;
            _globalSearchIndex = _buildSearchIndex(cached);
            _globalSearchLoading = false;
          });
          return;
        }
      }
      final items = await _scanGlobalItems(_globalSearchRoots);
      _globalSearchBuiltAt = DateTime.now();
      _saveGlobalSearchCache(items);
      setState(() {
        _globalSearchItems = items;
        _globalSearchIndex = _buildSearchIndex(items);
        _globalSearchLoading = false;
      });
    } catch (error) {
      setState(() {
        _globalSearchLoading = false;
        _globalSearchError = 'No se pudo indexar las rutas globales.';
      });
    }
  }

  Future<List<FileItem>> _scanGlobalItems(List<String> roots) async {
    final items = <FileItem>[];
    for (final root in roots) {
      final rootDir = Directory(root);
      if (!rootDir.existsSync()) {
        continue;
      }
      await for (final entity
          in rootDir.list(recursive: true, followLinks: false)) {
        final path = entity.path;
        final name = path.split(Platform.pathSeparator).last;
        if (!_showHidden) {
          if (name.startsWith('.')) {
            continue;
          }
          final segments = path.split(Platform.pathSeparator);
          if (segments.any((segment) => segment.startsWith('.'))) {
            continue;
          }
        }
        try {
          final stat = await FileStat.stat(path);
          final isDir = entity is Directory;
          items.add(
            FileItem(
              path: path,
              name: name,
              isDirectory: isDir,
              sizeBytes: isDir ? 0 : stat.size,
              modifiedAt: stat.modified,
            ),
          );
        } catch (_) {
          continue;
        }
      }
    }
    return items;
  }

  void _toggleGlobalSearch() {
    setState(() {
      _globalSearchEnabled = !_globalSearchEnabled;
    });
    _saveSettings();
    if (_globalSearchEnabled && _searchQuery.trim().isNotEmpty) {
      _ensureGlobalSearchIndex();
    }
  }

  void _reindexGlobalSearch() {
    _ensureGlobalSearchIndex(force: true);
  }

  void _toggleThemeMode() {
    final current = themeController.mode;
    final next =
        current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    themeController.setMode(next);
  }

  void _cycleDragDropAction() {
    setState(() {
      if (_dragDropDefaultAction == 'ask') {
        _dragDropDefaultAction = 'copy';
      } else if (_dragDropDefaultAction == 'copy') {
        _dragDropDefaultAction = 'move';
      } else {
        _dragDropDefaultAction = 'ask';
      }
    });
    _saveSettings();
  }

  void _toggleGlobalRoot(String root, bool enabled) {
    final roots = List<String>.from(_globalSearchRoots);
    if (enabled) {
      if (!roots.contains(root)) {
        roots.add(root);
      }
    } else {
      roots.remove(root);
    }
    if (roots.isEmpty) {
      roots.add(_homePath);
    }
    setState(() {
      _globalSearchRoots = roots;
    });
    _saveSettings();
    if (_globalSearchEnabled) {
      _reindexGlobalSearch();
    }
  }

  Future<void> _promptAddGlobalRoot() async {
    final controller = TextEditingController();
    String? result;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar ruta global'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '/home/usuario/Proyectos',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              result = controller.text.trim();
              Navigator.pop(context);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (result == null || result!.isEmpty) {
      return;
    }
    final path = result!;
    final dir = Directory(path);
    if (!dir.existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La ruta no existe: $path')),
      );
      return;
    }
    _toggleGlobalRoot(path, true);
  }

  void _toggleHidden() {
    setState(() {
      _showHidden = !_showHidden;
    });
    _saveSettings();
    if (_globalSearchEnabled) {
      _reindexGlobalSearch();
    }
  }

  void _clearHistoryPanel() {
    setState(() {
      _historyVisits.clear();
      _historyLastVisited.clear();
      _history
        ..clear()
        ..add(_currentPath);
      _historyIndex = 0;
    });
    _saveSettings();
  }

  String? _tagForPath(String path) => _tagsByPath[path];

  Color? _tagColorForPath(String path) {
    final id = _tagForPath(path);
    if (id == null) return null;
    return _tagOptions.firstWhere((tag) => tag.id == id,
            orElse: () => _tagOptions.first)
        .color;
  }

  String? _tagLabelForPath(String path) {
    final id = _tagForPath(path);
    if (id == null) return null;
    return _tagOptions.firstWhere((tag) => tag.id == id,
            orElse: () => _tagOptions.first)
        .label;
  }

  void _applyTagToSelection(String? tagId) {
    if (_selectedPaths.isEmpty) {
      return;
    }
    setState(() {
      if (tagId == null) {
        for (final path in _selectedPaths) {
          _tagsByPath.remove(path);
        }
      } else {
        for (final path in _selectedPaths) {
          _tagsByPath[path] = tagId;
        }
      }
    });
    _saveSettings();
  }

  void _migrateTagPath(String from, String to) {
    final tag = _tagsByPath.remove(from);
    if (tag != null) {
      _tagsByPath[to] = tag;
      _saveSettings();
    }
  }

  void _removeTagsForPaths(Iterable<String> paths) {
    var changed = false;
    for (final path in paths) {
      if (_tagsByPath.remove(path) != null) {
        changed = true;
      }
    }
    if (changed) {
      _saveSettings();
    }
  }

  String _globalSearchCachePath() {
    return _joinPath(_placesConfigDir(), 'global_search.json');
  }

  List<FileItem>? _loadGlobalSearchCache() {
    final file = File(_globalSearchCachePath());
    if (!file.existsSync()) {
      return null;
    }
    try {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final roots = (data['roots'] as List?)?.whereType<String>().toList() ?? [];
      final hidden = data['showHidden'] as bool? ?? false;
      if (hidden != _showHidden) {
        return null;
      }
      if (!_sameRoots(roots, _globalSearchRoots)) {
        return null;
      }
      final builtAtRaw = data['builtAt'] as String?;
      _globalSearchBuiltAt =
          builtAtRaw != null ? DateTime.tryParse(builtAtRaw) : null;
      final items = <FileItem>[];
      final rawItems = data['items'];
      if (rawItems is! List) {
        return null;
      }
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final path = map['path'] as String?;
        final name = map['name'] as String?;
        final isDir = map['isDirectory'] as bool? ?? false;
        final size = map['sizeBytes'] as int? ?? 0;
        final modifiedRaw = map['modifiedAt'] as String?;
        if (path == null || name == null || modifiedRaw == null) {
          continue;
        }
        final modified = DateTime.tryParse(modifiedRaw);
        if (modified == null) continue;
        items.add(
          FileItem(
            path: path,
            name: name,
            isDirectory: isDir,
            sizeBytes: size,
            modifiedAt: modified,
          ),
        );
      }
      return items;
    } catch (_) {
      return null;
    }
  }

  void _saveGlobalSearchCache(List<FileItem> items) {
    final dir = Directory(_placesConfigDir());
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(_globalSearchCachePath());
    final data = <String, dynamic>{
      'roots': _globalSearchRoots,
      'showHidden': _showHidden,
      'builtAt': _globalSearchBuiltAt?.toIso8601String(),
      'items': items
          .map(
            (item) => {
              'path': item.path,
              'name': item.name,
              'isDirectory': item.isDirectory,
              'sizeBytes': item.sizeBytes,
              'modifiedAt': item.modifiedAt.toIso8601String(),
            },
          )
          .toList(),
    };
    file.writeAsStringSync(jsonEncode(data));
  }

  bool _sameRoots(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final aSorted = List<String>.from(a)..sort();
    final bSorted = List<String>.from(b)..sort();
    for (var i = 0; i < aSorted.length; i++) {
      if (aSorted[i] != bSorted[i]) return false;
    }
    return true;
  }

  Map<String, List<FileItem>> _buildSearchIndex(List<FileItem> items) {
    final index = <String, List<FileItem>>{};
    for (final item in items) {
      final name = item.name.toLowerCase();
      if (name.isEmpty) {
        continue;
      }
      final key = name.characters.first;
      index.putIfAbsent(key, () => []).add(item);
    }
    return index;
  }

  List<FileItem> _filterByQuery(
    String query, {
    List<FileItem>? baseItems,
    Map<String, List<FileItem>>? searchIndex,
    List<FileItem>? allItems,
    String? Function(String path)? gitStatusForPath,
  }) {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) {
      return baseItems ?? allItems ?? _items;
    }
    final parsed = parseSearchQuery(normalized);
    final key = parsed.nameTerms.isNotEmpty
        ? parsed.nameTerms.first.characters.first
        : normalized.characters.first;
    final index = searchIndex ?? _searchIndex;
    final candidates = baseItems ?? (index[key] ?? (allItems ?? _items));
    return candidates.where((item) {
      if (parsed.gitStatus != null) {
        final status = gitStatusForPath?.call(item.path);
        if (status == null || status != parsed.gitStatus) {
          return false;
        }
      }
      if (parsed.type != null) {
        final t = parsed.type!;
        if (t == 'dir' || t == 'carpeta') {
          if (!item.isDirectory) return false;
        } else if (t == 'file' || t == 'archivo') {
          if (item.isDirectory) return false;
        } else if (t == 'image' || t == 'imagen') {
          if (!_isImageFile(item)) return false;
        }
      }
      if (parsed.ext != null && !item.isDirectory) {
        if (!item.name.toLowerCase().endsWith('.${parsed.ext}')) {
          return false;
        }
      }
      if (parsed.minBytes != null && !item.isDirectory) {
        if (item.sizeBytes < parsed.minBytes!) return false;
      }
      if (parsed.maxBytes != null && !item.isDirectory) {
        if (item.sizeBytes > parsed.maxBytes!) return false;
      }
      if (parsed.minDate != null) {
        if (item.modifiedAt.isBefore(parsed.minDate!)) return false;
      }
      if (parsed.maxDate != null) {
        if (item.modifiedAt.isAfter(parsed.maxDate!)) return false;
      }
      for (final term in parsed.nameTerms) {
        if (!item.name.toLowerCase().contains(term)) return false;
      }
      return true;
    }).toList();
  }

  List<FileItem> _sortItems(List<FileItem> input) {
    final items = List<FileItem>.from(input);
    items.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      int result;
      switch (_sortField) {
        case _SortField.name:
          result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case _SortField.size:
          result = a.sizeBytes.compareTo(b.sizeBytes);
          break;
        case _SortField.modified:
          result = a.modifiedAt.compareTo(b.modifiedAt);
          break;
      }
      return _sortAscending ? result : -result;
    });
    return items;
  }

  void _toggleSort(_SortField field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
    });
    _saveSettings();
  }

  void _setViewMode(_ViewMode mode) {
    setState(() {
      _viewMode = mode;
    });
    _saveSettings();
  }


  void _loadSettings() {
    final file = File(_settingsPath());
    if (!file.existsSync()) {
      return;
    }
    try {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final view = data['viewMode'] as String?;
      _viewMode = _ViewMode.values.firstWhere(
        (v) => v.name == view,
        orElse: () => _ViewMode.list,
      );
      _showDetailsPanel = data['showDetails'] as bool? ?? true;
      _showHidden = data['showHidden'] as bool? ?? false;
      _globalSearchEnabled = data['globalSearchEnabled'] as bool? ?? false;
      final roots = (data['globalSearchRoots'] as List?)
              ?.whereType<String>()
              .toList() ??
          [_homePath];
      _globalSearchRoots = roots.isEmpty ? [_homePath] : roots;
      _previewSize = (data['previewSize'] as num?)?.toDouble() ?? _previewSize;
      _panelOpacity =
          (data['panelOpacity'] as num?)?.toDouble() ?? _panelOpacity;
      final sort = data['sortField'] as String?;
      _sortField = _SortField.values.firstWhere(
        (v) => v.name == sort,
        orElse: () => _SortField.name,
      );
      _sortAscending = data['sortAscending'] as bool? ?? true;
      _recentItems =
          (data['recentItems'] as List?)?.whereType<String>().toList() ?? [];
      _favoriteItems =
          (data['favoriteItems'] as List?)?.whereType<String>().toList() ?? [];
      final tagMap = data['tags'];
      if (tagMap is Map) {
        _tagsByPath
          ..clear()
          ..addAll(
            Map<String, dynamic>.from(tagMap).map(
              (key, value) => MapEntry(key, value.toString()),
            ),
          );
      }
      _dragDropDefaultAction =
          data['dragDropDefaultAction'] as String? ?? 'ask';
      final presets = data['renamePresets'];
      if (presets is List) {
        _renamePresets
          ..clear()
          ..addAll(
            presets
                .whereType<Map>()
                .map((entry) => _RenamePreset.fromMap(
                      Map<String, dynamic>.from(entry),
                    )),
          );
      }
      final historyMap = data['historyStats'];
      if (historyMap is Map) {
        _historyVisits.clear();
        _historyLastVisited.clear();
        for (final entry in historyMap.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is Map) {
            final map = Map<String, dynamic>.from(value);
            final count = map['count'] as int? ?? 0;
            final lastRaw = map['lastVisited'] as String?;
            final last = lastRaw != null ? DateTime.tryParse(lastRaw) : null;
            if (count > 0) {
              _historyVisits[key] = count;
            }
            if (last != null) {
              _historyLastVisited[key] = last;
            }
          }
        }
      }
      final tabsData = data['tabs'];
      if (tabsData is List) {
        _tabs.clear();
        for (final entry in tabsData) {
          if (entry is! Map) {
            continue;
          }
          final map = Map<String, dynamic>.from(entry);
          final path = map['path'] as String? ?? _homePath;
          final history = (map['history'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              [path];
          final historyIndex = map['historyIndex'] as int? ?? 0;
          final tab = _FileTab(
            id: 'tab_${_tabCounter++}',
            path: path,
            label: map['label'] as String?,
            pinned: map['pinned'] as bool? ?? false,
            history: history.isEmpty ? [path] : history,
            historyIndex: historyIndex.clamp(0, history.length - 1),
            selectedPaths: <String>{},
            lastSelectedIndex: null,
            searchQuery: map['searchQuery'] as String? ?? '',
          );
          _tabs.add(tab);
        }
        final active = data['activeTabIndex'] as int? ?? 0;
        _activeTabIndex =
            _tabs.isEmpty ? 0 : active.clamp(0, _tabs.length - 1);
        if (_tabs.isNotEmpty) {
          _applyTab(_tabs[_activeTabIndex]);
        }
      }
    } catch (_) {
      // ignore malformed settings
    }
  }

  void _saveSettings() {
    _syncActiveTab();
    final dir = Directory(_placesConfigDir());
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File(_settingsPath());
    final tabsData = _tabs
        .map(
          (tab) => {
            'path': tab.path,
            'label': tab.label,
            'pinned': tab.pinned,
            'history': tab.history,
            'historyIndex': tab.historyIndex,
            'searchQuery': tab.searchQuery,
          },
        )
        .toList();
    final data = <String, dynamic>{
      'viewMode': _viewMode.name,
      'showDetails': _showDetailsPanel,
      'showHidden': _showHidden,
      'globalSearchEnabled': _globalSearchEnabled,
      'globalSearchRoots': _globalSearchRoots,
      'previewSize': _previewSize,
      'sortField': _sortField.name,
      'sortAscending': _sortAscending,
      'recentItems': _recentItems,
      'favoriteItems': _favoriteItems,
      'tags': _tagsByPath,
      'renamePresets': _renamePresets.map((p) => p.toMap()).toList(),
      'historyStats': _historyVisits.map(
        (key, value) => MapEntry(
          key,
          {
            'count': value,
            'lastVisited': _historyLastVisited[key]?.toIso8601String(),
          },
        ),
      ),
      'dragDropDefaultAction': _dragDropDefaultAction,
      'panelOpacity': _panelOpacity,
      'tabs': tabsData,
      'activeTabIndex': _activeTabIndex,
    };
    file.writeAsStringSync(jsonEncode(data));
  }

  String _settingsPath() {
    return _joinPath(_placesConfigDir(), 'settings.json');
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppBranding.appName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppBranding.tagline} · ${AppBranding.niceOsName}'),
            const SizedBox(height: 12),
            Text('Autores: ${AppBranding.authors.join(', ')}'),
            const SizedBox(height: 12),
            Text('Versión: $_versionLabel'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showPanelOpacityDialog() {
    var temp = _panelOpacity;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Transparencia de paneles'),
          content: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(temp * 100).round()}%'),
                Slider(
                  value: temp,
                  min: 0.6,
                  max: 1.0,
                  divisions: 8,
                  onChanged: (value) {
                    setState(() => temp = value);
                    if (!mounted) return;
                    this.setState(() {
                      _panelOpacity = value;
                    });
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPane(_PaneData pane, bool isRight) {
    final visibleItems = _visibleItemsForPane(pane);
    final isActive = _activePane == pane;
    final isGlobalSearch = _isGlobalSearchActive(pane.searchQuery);
    final panelColor = Theme.of(context)
        .colorScheme
        .surface
        .withValues(alpha: _panelOpacity);
    return GestureDetector(
      onTapDown: (_) => _activatePane(isRight),
      onSecondaryTapDown: (details) =>
          _showBackgroundContextMenuForPane(details.globalPosition, isRight),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: panelColor,
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            _PathBar(
              path: pane.currentPath,
              onNavigate: (path) => _navigateToPane(path, pane),
              pathController: pane.pathController,
              pathFocusNode: pane.pathFocusNode,
              isEditing: pane.isEditingPath,
              onStartEdit: () => _startPathEditForPane(pane),
              onFinishEdit: ({required bool navigate}) =>
                  _finishPathEditForPane(pane, navigate: navigate),
              panelOpacity: _panelOpacity,
            ),
            Expanded(
              child: DragTarget<FileItem>(
                onWillAcceptWithDetails: (details) =>
                    details.data.path != pane.currentPath,
                onAcceptWithDetails: (details) => _moveItemToPath(
                  details.data,
                  pane.currentPath,
                ),
                builder: (context, candidateData, rejectedData) => isGlobalSearch
                    ? _buildGlobalSearchPane(visibleItems, pane, isRight)
                    : pane.errorMessage != null
                        ? _EmptyState(
                            message: 'No se pudo abrir la carpeta',
                            subtitle: pane.errorMessage,
                            icon: AppIcons.info,
                          )
                        : visibleItems.isEmpty
                            ? const _EmptyState(
                                message: 'Carpeta vacía',
                                subtitle: 'No hay elementos en esta carpeta.',
                                icon: AppIcons.folderX,
                              )
                            : _buildItemsView(visibleItems, pane, isRight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalSearchPane(
    List<FileItem> visibleItems,
    _PaneData pane,
    bool isRight,
  ) {
    if (_globalSearchLoading) {
      return const _EmptyState(
        message: 'Indexando /home',
        subtitle: 'Esto puede tardar unos minutos.',
        icon: AppIcons.search,
        isLoading: true,
      );
    }
    if (_globalSearchError != null) {
      return _EmptyState(
        message: 'Error de búsqueda',
        subtitle: _globalSearchError,
        icon: AppIcons.info,
      );
    }
    if (visibleItems.isEmpty) {
      return const _EmptyState(
        message: 'Sin resultados',
        subtitle: 'Prueba con otro término o ruta.',
        icon: AppIcons.search,
      );
    }
    return _buildItemsView(visibleItems, pane, isRight);
  }

  Widget _buildItemsView(
    List<FileItem> visibleItems,
    _PaneData pane,
    bool isRight,
  ) {
    if (_viewMode == _ViewMode.grid) {
      return _GridView(
        items: visibleItems,
        selectedPaths: pane.selectedPaths,
        onSelect: (item, index, items) =>
            _selectItemForPane(item, index, items, isRight),
        onOpen: (item) => _openItemForPane(item, isRight),
        onContextMenu: (item, pos) =>
            _showItemContextMenuForPane(item, pos, isRight),
        onDropOnFolder: (source, target) => _moveItemToFolder(
          source,
          target,
        ),
        isCut: (path) =>
            _memoryClipboardIsCut && _memoryClipboardPaths.contains(path),
        tagColorForPath: _tagColorForPath,
        gitStatusForPath: _gitStatusForPath,
      );
    }
    return _ListView(
      items: visibleItems,
      selectedPaths: pane.selectedPaths,
      onSelect: (item, index, items) =>
          _selectItemForPane(item, index, items, isRight),
      onOpen: (item) => _openItemForPane(item, isRight),
      onContextMenu: (item, pos) =>
          _showItemContextMenuForPane(item, pos, isRight),
      onDropOnFolder: (source, target) => _moveItemToFolder(
        source,
        target,
      ),
      formatBytes: _formatBytes,
      formatDate: _formatDate,
      sortField: _sortField,
      sortAscending: _sortAscending,
      onSort: _toggleSort,
      panelOpacity: _panelOpacity,
      isCut: (path) =>
          _memoryClipboardIsCut && _memoryClipboardPaths.contains(path),
      tagColorForPath: _tagColorForPath,
      gitStatusForPath: _gitStatusForPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _historyIndex > 0;
    final canGoForward =
        _historyIndex >= 0 && _historyIndex < _history.length - 1;
    final visibleItems = _visibleItems;
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.f5): const _RefreshIntent(),
        LogicalKeySet(LogicalKeyboardKey.delete): const _DeleteIntent(),
        LogicalKeySet(LogicalKeyboardKey.f2): const _RenameIntent(),
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowLeft):
            const _BackIntent(),
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowRight):
            const _ForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowUp):
            const _UpIntent(),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyN,
        ): const _NewFolderIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
            const _SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyH):
            const _ToggleHiddenIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
            const _UndoIntent(),
      },
      child: Actions(
        actions: {
          _RefreshIntent: CallbackAction(onInvoke: (_) => _loadFiles()),
          _DeleteIntent: CallbackAction(onInvoke: (_) => _deleteSelected()),
          _RenameIntent: CallbackAction(onInvoke: (_) => _renameSelected()),
          _BackIntent: CallbackAction(onInvoke: (_) => _goBack()),
          _ForwardIntent: CallbackAction(onInvoke: (_) => _goForward()),
          _UpIntent: CallbackAction(onInvoke: (_) => _goUp()),
          _NewFolderIntent: CallbackAction(onInvoke: (_) => _createFolder()),
          _SearchIntent: CallbackAction(onInvoke: (_) {
            FocusScope.of(context).requestFocus(_searchFocusNode);
            return null;
          }),
          _ToggleHiddenIntent: CallbackAction(onInvoke: (_) {
            _toggleHidden();
            return null;
          }),
          _UndoIntent: CallbackAction(onInvoke: (_) => _undoLastAction()),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.background,
                          Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          Theme.of(context).colorScheme.background,
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
            _Sidebar(
              currentPath: _currentPath,
              places: _places,
            onAddPlace: _addCustomPlace,
            onRemovePlace: _removeCustomPlace,
            onEditPlace: _editCustomPlace,
            onAddPlaceFromPath: _addCustomPlaceFromPath,
            remotes: _cloudRemotes,
            isMounted: _isMounted,
            onMountRemote: _mountRemote,
            onUnmountRemote: _unmountRemote,
            onRefreshRemotes: _loadRcloneRemotes,
            onNavigate: _navigateTo,
            panelOpacity: _panelOpacity,
          ),
                Expanded(
                  child: Column(
                    children: [
                      _AppMenuBar(
                        isGrid: _viewMode == _ViewMode.grid,
                        showDetails: _showDetailsPanel,
                        showHidden: _showHidden,
                        globalSearchEnabled: _globalSearchEnabled,
                        globalSearchLoading: _globalSearchLoading,
                        homePath: _homePath,
                        globalSearchRoots: _globalSearchRoots,
                        themeMode: themeController.mode,
                        dragDropDefaultAction: _dragDropDefaultAction,
                        onDragDropActionChanged: (value) {
                          setState(() => _dragDropDefaultAction = value);
                          _saveSettings();
                        },
                        panelOpacity: _panelOpacity,
                        onOpenPanelOpacity: _showPanelOpacityDialog,
                        onNewFolder: _createFolder,
                        onUndo: _undoLastAction,
                        onRename: _renameSelected,
                        onCopy: _copySelected,
                        onMove: _moveSelected,
                        onDelete: _deleteSelected,
                        onToggleGrid: () {
                          _setViewMode(
                            _viewMode == _ViewMode.grid
                                ? _ViewMode.list
                                : _ViewMode.grid,
                          );
                        },
                        onToggleDetails: () => setState(
                          () => _showDetailsPanel = !_showDetailsPanel,
                        ),
                        onToggleHidden: _toggleHidden,
                        onSetViewList: () => _setViewMode(_ViewMode.list),
                        onSetViewGrid: () => _setViewMode(_ViewMode.grid),
                        onSortByName: () => _toggleSort(_SortField.name),
                        onSortBySize: () => _toggleSort(_SortField.size),
                        onSortByModified: () => _toggleSort(_SortField.modified),
                        onIncreaseThumbs: () => _changePreviewSize(20),
                        onDecreaseThumbs: () => _changePreviewSize(-20),
                        onToggleGlobalSearch: _toggleGlobalSearch,
                        onReindexGlobalSearch: _reindexGlobalSearch,
                        onToggleGlobalRoot: _toggleGlobalRoot,
                        onAddGlobalRoot: _promptAddGlobalRoot,
                        onToggleTheme: _toggleThemeMode,
                        onRefreshRemotes: _loadRcloneRemotes,
                        onMountAll: () {
                          for (final remote in _cloudRemotes) {
                            if (!_isMounted(remote.mountPoint)) {
                              _mountRemote(remote);
                            }
                          }
                        },
                        onUnmountAll: () {
                          for (final remote in _cloudRemotes) {
                            if (_isMounted(remote.mountPoint)) {
                              _unmountRemote(remote);
                            }
                          }
                        },
                        onAbout: _showAbout,
                        onOpenTerminal: _openTerminalHere,
                        onEmptyTrash: _emptyTrash,
                        onDeletePermanent: _deleteSelectedPermanently,
                      ),
                      _TabsBar(
                        tabs: _tabs,
                        activeIndex: _activeTabIndex,
                        recentPaths: _recentPaths(),
                        onSelect: _switchTab,
                        onClose: _closeTab,
                        onNewTab: () => _addTab(),
                        onNewTabFromPath: _addTabFromPathPrompt,
                        onNewTabWithPath: (path) => _addTab(path: path),
                        onRename: _renameTab,
                        onDuplicate: _duplicateTab,
                        onDuplicateWithSelection: (index) =>
                            _duplicateTab(index, keepSelection: true),
                        onCloseOthers: _closeOtherTabs,
                        onReorder: _reorderTabs,
                        onPinToggle: _togglePinTab,
                        onOpenPathInTab: _openPathInTab,
                      ),
                      _Toolbar(
                        canGoBack: canGoBack,
                        canGoForward: canGoForward,
                        isGrid: _viewMode == _ViewMode.grid,
                        onBack: _goBack,
                        onForward: _goForward,
                        onUp: _goUp,
                        onRefresh: _loadFiles,
        onToggleView: () {
                          _setViewMode(
                            _viewMode == _ViewMode.list
                                ? _ViewMode.grid
                                : _ViewMode.list,
                          );
                        },
                        onNewFolder: _createFolder,
                        onRename: _renameSelected,
                        onDelete: _deleteSelected,
                        onCopy: _copySelected,
                        onMove: _moveSelected,
                        onSearchChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          _syncActiveTab();
                          if (_isGlobalSearchActive(value)) {
                            _ensureGlobalSearchIndex();
                          }
                        },
                        searchController: _searchController,
                        searchFocusNode: _searchFocusNode,
                        globalSearchEnabled: _globalSearchEnabled,
                        globalSearchLoading: _globalSearchLoading,
                        onToggleGlobalSearch: _toggleGlobalSearch,
                        onReindexGlobalSearch: _reindexGlobalSearch,
                        dragDropDefaultAction: _dragDropDefaultAction,
                        onCycleDragDropAction: _cycleDragDropAction,
                        panelOpacity: _panelOpacity,
                      ),
                      Expanded(
                        child: _dualPane
                            ? Row(
                                children: [
                                  Expanded(
                                    child: _buildPane(_leftPane, false),
                                  ),
                                  VerticalDivider(
                                    width: 1,
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  Expanded(
                                    child: _buildPane(_rightPane, true),
                                  ),
                                ],
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin: const Offset(0, 0.02),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slide,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildPane(_activePane, _isRightActive),
                              ),
                      ),
                      _StatusBar(
                        itemCount: visibleItems.length,
                        totalCount: _items.length,
                        currentPath: _currentPath,
                        selectedCount: _selectedCount,
                        globalSearchEnabled: _globalSearchEnabled,
                        globalSearchBuiltAt: _globalSearchBuiltAt,
                        gitRoot: _activePane.gitRoot,
                        dragDropDefaultAction: _dragDropDefaultAction,
                      ),
                    ],
                  ),
                ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axis: Axis.horizontal,
                child: child,
              ),
            ),
            child: _showDetailsPanel
                ? _DetailsPanel(
                    key: const ValueKey('details'),
                    selectedItem: _selectedItem,
                    formatBytes: _formatBytes,
                    formatDate: _formatDate,
                    isImageFile: _isImageFile,
                    fileService: _fileService,
                    previewSize: _previewSize,
                    onZoomIn: () => _changePreviewSize(20),
                    onZoomOut: () => _changePreviewSize(-20),
                    selectedCount: _selectedCount,
                    tagLabelForPath: _tagLabelForPath,
                    tagColorForPath: _tagColorForPath,
                    history: _history,
                    historyVisits: _historyVisits,
                    historyLastVisited: _historyLastVisited,
                    onNavigate: _navigateTo,
                    onClearHistory: _clearHistoryPanel,
                    panelOpacity: _panelOpacity,
                  )
                : const SizedBox.shrink(
                    key: ValueKey('details-hidden'),
                  ),
          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FileTab {
  _FileTab({
    required this.id,
    required this.path,
    required this.label,
    required this.pinned,
    required this.history,
    required this.historyIndex,
    required this.selectedPaths,
    required this.lastSelectedIndex,
    required this.searchQuery,
  });

  final String id;
  String path;
  String? label;
  bool pinned;
  List<String> history;
  int historyIndex;
  Set<String> selectedPaths;
  int? lastSelectedIndex;
  String searchQuery;
}

class _TabsBar extends StatelessWidget {
  final List<_FileTab> tabs;
  final int activeIndex;
  final List<String> recentPaths;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;
  final VoidCallback onNewTab;
  final VoidCallback onNewTabFromPath;
  final ValueChanged<String> onNewTabWithPath;
  final ValueChanged<int> onRename;
  final ValueChanged<int> onDuplicate;
  final ValueChanged<int> onDuplicateWithSelection;
  final ValueChanged<int> onCloseOthers;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onPinToggle;
  final void Function(int index, String path) onOpenPathInTab;

  const _TabsBar({
    required this.tabs,
    required this.activeIndex,
    required this.recentPaths,
    required this.onSelect,
    required this.onClose,
    required this.onNewTab,
    required this.onNewTabFromPath,
    required this.onNewTabWithPath,
    required this.onRename,
    required this.onDuplicate,
    required this.onDuplicateWithSelection,
    required this.onCloseOthers,
    required this.onReorder,
    required this.onPinToggle,
    required this.onOpenPathInTab,
  });

  String _titleForTab(_FileTab tab) {
    if (tab.label != null && tab.label!.trim().isNotEmpty) {
      return tab.label!.trim();
    }
    final path = tab.path;
    if (path == '/') {
      return 'Root';
    }
    final parts = path.split('/');
    final name = parts.isNotEmpty ? parts.last : path;
    return name.isEmpty ? 'Root' : name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: DragTarget<FileItem>(
        onWillAcceptWithDetails: (details) => details.data.isDirectory,
        onAcceptWithDetails: (details) => onNewTabWithPath(details.data.path),
        builder: (context, candidateData, rejectedData) => Row(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                buildDefaultDragHandles: false,
                onReorder: onReorder,
                itemBuilder: (context, index) {
                  final tab = tabs[index];
                  final isActive = index == activeIndex;
                  return ReorderableDragStartListener(
                    index: index,
                    key: ValueKey(tab.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: DragTarget<FileItem>(
                        onWillAcceptWithDetails: (details) =>
                            details.data.isDirectory,
                        onAcceptWithDetails: (details) =>
                            onOpenPathInTab(index, details.data.path),
                        builder: (context, candidateData, rejectedData) =>
                            Tooltip(
                          message: tab.path,
                          child: _TabChip(
                            title: _titleForTab(tab),
                            isActive: isActive,
                            isPinned: tab.pinned,
                            onTap: () => onSelect(index),
                            onClose: () => onClose(index),
                            onContextMenu: (details) {
                              showMenu<_TabAction>(
                                context: context,
                                position: RelativeRect.fromLTRB(
                                  details.globalPosition.dx,
                                  details.globalPosition.dy,
                                  details.globalPosition.dx + 1,
                                  details.globalPosition.dy + 1,
                                ),
                                items: [
                                  const PopupMenuItem(
                                    value: _TabAction.rename,
                                    child: ListTile(
                                      leading: Icon(AppIcons.edit),
                                      title: Text('Renombrar pestaña'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _TabAction.pinToggle,
                                    child: ListTile(
                                      leading: Icon(
                                        tab.pinned
                                            ? AppIcons.bookmark
                                            : AppIcons.bookmark,
                                      ),
                                      title: Text(
                                        tab.pinned
                                            ? 'Desanclar pestaña'
                                            : 'Anclar pestaña',
                                      ),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: _TabAction.duplicate,
                                    child: ListTile(
                                      leading: Icon(AppIcons.copy),
                                      title: Text('Duplicar pestaña'),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: _TabAction.duplicateWithSelection,
                                    child: ListTile(
                                      leading: Icon(AppIcons.copy),
                                      title: Text('Duplicar con selección'),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: _TabAction.close,
                                    child: ListTile(
                                      leading: Icon(AppIcons.close),
                                      title: Text('Cerrar pestaña'),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: _TabAction.closeOthers,
                                    child: ListTile(
                                      leading: Icon(AppIcons.folderX),
                                      title: Text('Cerrar otras'),
                                    ),
                                  ),
                                ],
                              ).then((action) {
                                if (action == null) return;
                                switch (action) {
                                  case _TabAction.rename:
                                    onRename(index);
                                    break;
                                  case _TabAction.pinToggle:
                                    onPinToggle(index);
                                    break;
                                  case _TabAction.duplicate:
                                    onDuplicate(index);
                                    break;
                                  case _TabAction.duplicateWithSelection:
                                    onDuplicateWithSelection(index);
                                    break;
                                  case _TabAction.close:
                                    onClose(index);
                                    break;
                                  case _TabAction.closeOthers:
                                    onCloseOthers(index);
                                    break;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Nueva pestaña',
              icon: const Icon(AppIcons.plus),
              onSelected: (value) {
                if (value == 'new') {
                  onNewTab();
                } else if (value == 'fromPath') {
                  onNewTabFromPath();
                } else if (value.startsWith('path:')) {
                  onNewTabWithPath(value.substring(5));
                }
              },
              itemBuilder: (context) {
                final entries = <PopupMenuEntry<String>>[
                  const PopupMenuItem(
                    value: 'new',
                    child: ListTile(
                      leading: Icon(AppIcons.plus),
                      title: Text('Nueva pestaña'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'fromPath',
                    child: ListTile(
                      leading: Icon(AppIcons.open),
                      title: Text('Nueva pestaña desde ruta...'),
                    ),
                  ),
                ];
                if (recentPaths.isNotEmpty) {
                  entries.add(const PopupMenuDivider());
                  for (final path in recentPaths) {
                    entries.add(
                      PopupMenuItem(
                        value: 'path:$path',
                        child: ListTile(
                          leading: const Icon(AppIcons.folder),
                          title: Text(path),
                        ),
                      ),
                    );
                  }
                }
                return entries;
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _TabAction {
  rename,
  pinToggle,
  duplicate,
  duplicateWithSelection,
  close,
  closeOthers,
}

class _TabChip extends StatefulWidget {
  final String title;
  final bool isActive;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final ValueChanged<TapDownDetails> onContextMenu;

  const _TabChip({
    required this.title,
    required this.isActive,
    required this.isPinned,
    required this.onTap,
    required this.onClose,
    required this.onContextMenu,
  });

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    final hover = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.7);
    final active = Theme.of(context)
        .colorScheme
        .primary
        .withValues(alpha: 0.12);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTapDown: widget.onContextMenu,
        child: AnimatedScale(
          scale: _hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isActive ? active : (_hovered ? hover : base),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isActive
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            child: InkWell(
              onTap: widget.onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.folder,
                    size: 16,
                    color: widget.isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).iconTheme.color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontWeight:
                          widget.isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (widget.isPinned) ...[
                    const SizedBox(width: 6),
                    Icon(
                      AppIcons.bookmark,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onClose,
                    child: const Icon(
                      AppIcons.close,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreadcrumbChip extends StatefulWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  const _BreadcrumbChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_BreadcrumbChip> createState() => _BreadcrumbChipState();
}

class _BreadcrumbChipState extends State<_BreadcrumbChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final base = Colors.transparent;
    final hover = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.7);
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: _hovered ? hover : base,
          borderRadius: BorderRadius.circular(6),
        ),
        child: InkWell(
          onTap: widget.onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.icon,
              const SizedBox(width: 2),
              Text(
                widget.label,
                style: textStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverAnimatedContainer extends StatefulWidget {
  final bool selected;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Widget child;

  const _HoverAnimatedContainer({
    required this.selected,
    required this.padding,
    this.borderRadius,
    required this.child,
  });

  @override
  State<_HoverAnimatedContainer> createState() =>
      _HoverAnimatedContainerState();
}

class _HoverAnimatedContainerState extends State<_HoverAnimatedContainer> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    final hover = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.6);
    final selected = Theme.of(context)
        .colorScheme
        .primary
        .withValues(alpha: 0.18);
    final shadowColor = Theme.of(context).shadowColor.withValues(alpha: 0.15);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.selected ? selected : (_hovered ? hover : base),
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: widget.selected
                ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.35)
                : Colors.transparent,
          ),
          boxShadow: _hovered || widget.selected
              ? [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String currentPath;
  final List<_Place> places;
  final VoidCallback onAddPlace;
  final void Function(_Place place) onRemovePlace;
  final void Function(_Place place) onEditPlace;
  final void Function(String path, {String? label}) onAddPlaceFromPath;
  final List<_CloudRemote> remotes;
  final bool Function(String mountPoint) isMounted;
  final void Function(_CloudRemote remote) onMountRemote;
  final void Function(_CloudRemote remote) onUnmountRemote;
  final VoidCallback onRefreshRemotes;
  final void Function(String path) onNavigate;
  final double panelOpacity;

  const _Sidebar({
    required this.currentPath,
    required this.places,
    required this.onAddPlace,
    required this.onRemovePlace,
    required this.onEditPlace,
    required this.onAddPlaceFromPath,
    required this.remotes,
    required this.isMounted,
    required this.onMountRemote,
    required this.onUnmountRemote,
    required this.onRefreshRemotes,
    required this.onNavigate,
    required this.panelOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        );
    final sectionStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodySmall?.color,
        );
    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface
            .withValues(alpha: panelOpacity),
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Lugares',
                    style: headerStyle,
                  ),
                ),
                IconButton(
                  tooltip: 'Agregar atajo',
                  onPressed: onAddPlace,
                  icon: const Icon(AppIcons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<FileItem>(
              onWillAcceptWithDetails: (details) => details.data.isDirectory,
              onAcceptWithDetails: (details) => onAddPlaceFromPath(
                details.data.path,
                label: details.data.name,
              ),
              builder: (context, candidateData, rejectedData) =>
                  _PlacesContextMenu(
                remotes: remotes,
                isMounted: isMounted,
                onMountRemote: onMountRemote,
                onUnmountRemote: onUnmountRemote,
                onRefreshRemotes: onRefreshRemotes,
                onAddPlace: onAddPlace,
                child: ListView(
                  padding: const EdgeInsets.only(left: 8, right: 8, bottom: 10),
                  children: [
                    ...places.map((place) {
                    final isSelected = currentPath == place.path;
                    if (place.isHeader) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 10, 6),
                        child: Text(
                          place.label,
                          style: sectionStyle,
                        ),
                      );
                    }
                    return GestureDetector(
                      onSecondaryTapDown: place.isCustom
                          ? (details) {
                              showMenu<_PlaceAction>(
                                context: context,
                                position: RelativeRect.fromLTRB(
                                  details.globalPosition.dx,
                                  details.globalPosition.dy,
                                  details.globalPosition.dx + 1,
                                  details.globalPosition.dy + 1,
                                ),
                                items: const [
                                  PopupMenuItem(
                                    value: _PlaceAction.edit,
                                    child: ListTile(
                                      leading: Icon(AppIcons.edit),
                                      title: Text('Editar atajo'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _PlaceAction.remove,
                                    child: ListTile(
                                      leading: Icon(AppIcons.delete),
                                      title: Text('Eliminar atajo'),
                                    ),
                                  ),
                                ],
                              ).then((action) {
                                if (action == null) return;
                                if (action == _PlaceAction.edit) {
                                  onEditPlace(place);
                                } else {
                                  onRemovePlace(place);
                                }
                              });
                            }
                          : null,
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        minLeadingWidth: 22,
                        horizontalTitleGap: 10,
                        leading: Icon(place.icon),
                        title: Text(place.label),
                        subtitle: place.subtitle != null
                            ? Text(
                                place.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: place.usagePercent != null
                            ? Text(
                                '${place.usagePercent}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: _usageColor(
                                        context,
                                        place.usagePercent!,
                                      ),
                                    ),
                              )
                            : null,
                        selected: isSelected,
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () => onNavigate(place.path),
                        onLongPress:
                            place.isCustom ? () => onRemovePlace(place) : null,
                      ),
                    );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _usageColor(BuildContext context, int percent) {
    if (percent >= 90) {
      return Theme.of(context).colorScheme.error;
    }
    if (percent >= 75) {
      return Colors.orangeAccent;
    }
    return Theme.of(context).colorScheme.primary;
  }
}

enum _PlaceAction {
  edit,
  remove,
}

class _AppMenuBar extends StatelessWidget {
  final bool isGrid;
  final bool showDetails;
  final bool showHidden;
  final bool globalSearchEnabled;
  final bool globalSearchLoading;
  final String homePath;
  final List<String> globalSearchRoots;
  final ThemeMode themeMode;
  final VoidCallback onNewFolder;
  final VoidCallback onUndo;
  final VoidCallback onRename;
  final VoidCallback onCopy;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final VoidCallback onToggleGrid;
  final VoidCallback onToggleDetails;
  final VoidCallback onToggleHidden;
  final VoidCallback onSetViewList;
  final VoidCallback onSetViewGrid;
  final VoidCallback onSortByName;
  final VoidCallback onSortBySize;
  final VoidCallback onSortByModified;
  final VoidCallback onIncreaseThumbs;
  final VoidCallback onDecreaseThumbs;
  final VoidCallback onToggleGlobalSearch;
  final VoidCallback onReindexGlobalSearch;
  final void Function(String root, bool enabled) onToggleGlobalRoot;
  final VoidCallback onAddGlobalRoot;
  final VoidCallback onToggleTheme;
  final String dragDropDefaultAction;
  final ValueChanged<String> onDragDropActionChanged;
  final double panelOpacity;
  final VoidCallback onOpenPanelOpacity;
  final VoidCallback onRefreshRemotes;
  final VoidCallback onMountAll;
  final VoidCallback onUnmountAll;
  final VoidCallback onAbout;
  final VoidCallback onOpenTerminal;
  final VoidCallback onEmptyTrash;
  final VoidCallback onDeletePermanent;

  const _AppMenuBar({
    required this.isGrid,
    required this.showDetails,
    required this.showHidden,
    required this.globalSearchEnabled,
    required this.globalSearchLoading,
    required this.homePath,
    required this.globalSearchRoots,
    required this.themeMode,
    required this.onNewFolder,
    required this.onUndo,
    required this.onRename,
    required this.onCopy,
    required this.onMove,
    required this.onDelete,
    required this.onToggleGrid,
    required this.onToggleDetails,
    required this.onToggleHidden,
    required this.onSetViewList,
    required this.onSetViewGrid,
    required this.onSortByName,
    required this.onSortBySize,
    required this.onSortByModified,
    required this.onIncreaseThumbs,
    required this.onDecreaseThumbs,
    required this.onToggleGlobalSearch,
    required this.onReindexGlobalSearch,
    required this.onToggleGlobalRoot,
    required this.onAddGlobalRoot,
    required this.onToggleTheme,
    required this.dragDropDefaultAction,
    required this.onDragDropActionChanged,
    required this.panelOpacity,
    required this.onOpenPanelOpacity,
    required this.onRefreshRemotes,
    required this.onMountAll,
    required this.onUnmountAll,
    required this.onAbout,
    required this.onOpenTerminal,
    required this.onEmptyTrash,
    required this.onDeletePermanent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: MenuBar(
              style: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surface,
                ),
                elevation: const WidgetStatePropertyAll(0),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 6),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
              ),
              children: [
                SubmenuButton(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: onNewFolder,
                      child: const Text('Nueva carpeta'),
                    ),
                    MenuItemButton(
                      onPressed: onUndo,
                      child: const Text('Deshacer'),
                    ),
                    MenuItemButton(
                      onPressed: onRename,
                      child: const Text('Renombrar'),
                    ),
                    MenuItemButton(
                      onPressed: onCopy,
                      child: const Text('Copiar'),
                    ),
                    MenuItemButton(
                      onPressed: onMove,
                      child: const Text('Mover'),
                    ),
                    MenuItemButton(
                      onPressed: onDelete,
                      child: const Text('Eliminar'),
                    ),
                  ],
                  child: const Text('Archivo'),
                ),
                SubmenuButton(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: onSetViewList,
                      child: const Text('Vista lista'),
                    ),
                    MenuItemButton(
                      onPressed: onSetViewGrid,
                      child: const Text('Vista cuadrícula'),
                    ),
                    // toggle rápido (toolbar) permanece, aquí dejamos opciones directas
                    CheckboxMenuButton(
                      value: showDetails,
                      onChanged: (_) => onToggleDetails(),
                      child: const Text('Mostrar detalles'),
                    ),
                    CheckboxMenuButton(
                      value: showHidden,
                      onChanged: (_) => onToggleHidden(),
                      child: const Text('Mostrar ocultos'),
                    ),
                    CheckboxMenuButton(
                      value: themeMode == ThemeMode.light,
                      onChanged: (_) => onToggleTheme(),
                      child: const Text('Tema claro'),
                    ),
                    CheckboxMenuButton(
                      value: globalSearchEnabled,
                      onChanged: (_) => onToggleGlobalSearch(),
                      child: const Text('Búsqueda global en /home'),
                    ),
                    MenuItemButton(
                      onPressed: onOpenPanelOpacity,
                      child: Text(
                        'Transparencia paneles · ${(panelOpacity * 100).round()}%',
                      ),
                    ),
                    SubmenuButton(
                      menuChildren: [
                        RadioMenuButton<String>(
                          value: 'ask',
                          groupValue: dragDropDefaultAction,
                          onChanged: (value) {
                            if (value != null) {
                              onDragDropActionChanged(value);
                            }
                          },
                          child: const Text('Preguntar'),
                        ),
                        RadioMenuButton<String>(
                          value: 'copy',
                          groupValue: dragDropDefaultAction,
                          onChanged: (value) {
                            if (value != null) {
                              onDragDropActionChanged(value);
                            }
                          },
                          child: const Text('Copiar'),
                        ),
                        RadioMenuButton<String>(
                          value: 'move',
                          groupValue: dragDropDefaultAction,
                          onChanged: (value) {
                            if (value != null) {
                              onDragDropActionChanged(value);
                            }
                          },
                          child: const Text('Mover'),
                        ),
                      ],
                      child: const Text('Arrastrar y soltar'),
                    ),
                    MenuItemButton(
                      onPressed:
                          globalSearchLoading ? null : onReindexGlobalSearch,
                      child: const Text('Reindexar búsqueda global'),
                    ),
                    MenuItemButton(
                      onPressed: onAddGlobalRoot,
                      child: const Text('Agregar ruta global...'),
                    ),
                    const Divider(height: 12),
                    CheckboxMenuButton(
                      value: globalSearchRoots.contains(homePath),
                      onChanged: (value) =>
                          onToggleGlobalRoot(homePath, value ?? false),
                      child: const Text('Incluir Home'),
                    ),
                    CheckboxMenuButton(
                      value: globalSearchRoots.contains('/mnt'),
                      onChanged: (value) =>
                          onToggleGlobalRoot('/mnt', value ?? false),
                      child: const Text('Incluir /mnt'),
                    ),
                    CheckboxMenuButton(
                      value: globalSearchRoots.contains('/media'),
                      onChanged: (value) =>
                          onToggleGlobalRoot('/media', value ?? false),
                      child: const Text('Incluir /media'),
                    ),
                    CheckboxMenuButton(
                      value: globalSearchRoots.contains('/run/media'),
                      onChanged: (value) =>
                          onToggleGlobalRoot('/run/media', value ?? false),
                      child: const Text('Incluir /run/media'),
                    ),
                    const MenuItemButton(
                      onPressed: null,
                      child: Divider(height: 12),
                    ),
                    MenuItemButton(
                      onPressed: onSortByName,
                      child: const Text('Ordenar por nombre'),
                    ),
                    MenuItemButton(
                      onPressed: onSortBySize,
                      child: const Text('Ordenar por tamaño'),
                    ),
                    MenuItemButton(
                      onPressed: onSortByModified,
                      child: const Text('Ordenar por fecha'),
                    ),
                    MenuItemButton(
                      onPressed: onIncreaseThumbs,
                      child: const Text('Aumentar miniaturas'),
                    ),
                    MenuItemButton(
                      onPressed: onDecreaseThumbs,
                      child: const Text('Reducir miniaturas'),
                    ),
                  ],
                  child: const Text('Ver'),
                ),
                SubmenuButton(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: onEmptyTrash,
                      child: const Text('Vaciar papelera'),
                    ),
                    MenuItemButton(
                      onPressed: onDeletePermanent,
                      child: const Text('Eliminar definitivamente'),
                    ),
                    MenuItemButton(
                      onPressed: onOpenTerminal,
                      child: const Text('Abrir terminal aquí'),
                    ),
                    MenuItemButton(
                      onPressed: onRefreshRemotes,
                      child: const Text('Refrescar remotos'),
                    ),
                    MenuItemButton(
                      onPressed: onMountAll,
                      child: const Text('Montar todos'),
                    ),
                    MenuItemButton(
                      onPressed: onUnmountAll,
                      child: const Text('Desmontar todos'),
                    ),
                  ],
                  child: const Text('Nube'),
                ),
                SubmenuButton(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: onAbout,
                      child: const Text('Acerca de'),
                    ),
                  ],
                  child: const Text('Ayuda'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _SortField {
  name,
  size,
  modified,
}

enum _ViewMode {
  list,
  grid,
}

class _MountGroups {
  final List<_Place> removable;
  final List<_Place> other;

  const _MountGroups({
    required this.removable,
    required this.other,
  });
}

class _MountUsage {
  final String label;
  final int percent;

  const _MountUsage({
    required this.label,
    required this.percent,
  });
}

class _CloudRemote {
  final String name;
  final String mountPoint;

  const _CloudRemote({
    required this.name,
    required this.mountPoint,
  });

  String get label => name.endsWith(':') ? name.substring(0, name.length - 1) : name;
}

class _PlacesContextMenu extends StatelessWidget {
  final List<_CloudRemote> remotes;
  final bool Function(String mountPoint) isMounted;
  final void Function(_CloudRemote remote) onMountRemote;
  final void Function(_CloudRemote remote) onUnmountRemote;
  final VoidCallback onRefreshRemotes;
  final VoidCallback onAddPlace;
  final Widget child;

  const _PlacesContextMenu({
    required this.remotes,
    required this.isMounted,
    required this.onMountRemote,
    required this.onUnmountRemote,
    required this.onRefreshRemotes,
    required this.onAddPlace,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) async {
        final action = await showMenu<_PlacesMenuAction>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx + 1,
            details.globalPosition.dy + 1,
          ),
          items: [
            PopupMenuItem(
              value: _PlacesMenuAction.addShortcut,
              child: ListTile(
                leading: Icon(AppIcons.add),
                title: Text('Agregar atajo'),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: _PlacesMenuAction.refreshRemotes,
              child: ListTile(
                leading: Icon(AppIcons.refresh),
                title: Text('Refrescar remotos'),
              ),
            ),
            PopupMenuItem(
              value: _PlacesMenuAction.configRclone,
              child: ListTile(
                leading: Icon(AppIcons.edit),
                title: Text('Configurar rclone'),
              ),
            ),
            const PopupMenuDivider(),
            if (remotes.isNotEmpty) ...[
              PopupMenuItem(
                value: _PlacesMenuAction.mountAll,
                child: ListTile(
                  leading: Icon(AppIcons.cloud),
                  title: Text('Montar todos'),
                ),
              ),
              PopupMenuItem(
                value: _PlacesMenuAction.unmountAll,
                child: ListTile(
                  leading: Icon(AppIcons.remove),
                  title: Text('Desmontar todos'),
                ),
              ),
              const PopupMenuDivider(),
              ...remotes.map((remote) {
                final mounted = isMounted(remote.mountPoint);
                return PopupMenuItem(
                  value: _PlacesMenuAction.remote(remote),
                  child: ListTile(
                    leading: Icon(
                      mounted ? AppIcons.drive : AppIcons.cloud,
                      color: mounted
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(remote.label),
                    subtitle: Text(
                      mounted ? 'Montado' : 'Desmontado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(mounted ? AppIcons.remove : AppIcons.add),
                  ),
                );
              }),
            ] else ...[
              PopupMenuItem(
                enabled: false,
                child: ListTile(
                  leading: Icon(AppIcons.cloud),
                  title: Text('Sin remotos configurados'),
                ),
              ),
            ],
          ],
        );
        if (action == null) return;
        switch (action) {
          case _PlacesMenuAction.addShortcut:
            onAddPlace();
            break;
          case _PlacesMenuAction.mountAll:
            for (final remote in remotes) {
              if (!isMounted(remote.mountPoint)) {
                onMountRemote(remote);
              }
            }
            break;
          case _PlacesMenuAction.unmountAll:
            for (final remote in remotes) {
              if (isMounted(remote.mountPoint)) {
                onUnmountRemote(remote);
              }
            }
            break;
          case _PlacesMenuAction.refreshRemotes:
            onRefreshRemotes();
            break;
          case _PlacesMenuAction.configRclone:
            if (!context.mounted) return;
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Configurar rclone'),
                content: const Text(
                  'Ejecuta en una terminal:\\n\\n  rclone config\\n\\nLuego refresca los remotos aquí.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
            break;
          default:
            if (action.remote != null) {
              final remote = action.remote!;
              if (isMounted(remote.mountPoint)) {
                onUnmountRemote(remote);
              } else {
                onMountRemote(remote);
              }
            }
        }
      },
      child: child,
    );
  }
}

class _PlacesMenuAction {
  final _PlacesMenuType type;
  final _CloudRemote? remote;

  const _PlacesMenuAction._(this.type, [this.remote]);

  static const addShortcut = _PlacesMenuAction._(_PlacesMenuType.addShortcut);
  static const mountAll = _PlacesMenuAction._(_PlacesMenuType.mountAll);
  static const unmountAll = _PlacesMenuAction._(_PlacesMenuType.unmountAll);
  static const refreshRemotes = _PlacesMenuAction._(_PlacesMenuType.refreshRemotes);
  static const configRclone = _PlacesMenuAction._(_PlacesMenuType.configRclone);

  factory _PlacesMenuAction.remote(_CloudRemote remote) =>
      _PlacesMenuAction._(_PlacesMenuType.remote, remote);
}

enum _PlacesMenuType {
  addShortcut,
  mountAll,
  unmountAll,
  refreshRemotes,
  configRclone,
  remote,
}

class _MovePair {
  final String from;
  final String to;

  const _MovePair({required this.from, required this.to});
}

class _LastAction {
  final _LastActionType type;
  final List<_MovePair> moves;

  const _LastAction._(this.type, this.moves);

  factory _LastAction.move(List<_MovePair> moves) =>
      _LastAction._(_LastActionType.move, moves);
}

enum _LastActionType {
  move,
}

class _Toolbar extends StatelessWidget {
  final bool canGoBack;
  final bool canGoForward;
  final bool isGrid;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onUp;
  final VoidCallback onRefresh;
  final VoidCallback onToggleView;
  final VoidCallback onNewFolder;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback onMove;
  final ValueChanged<String> onSearchChanged;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool globalSearchEnabled;
  final bool globalSearchLoading;
  final VoidCallback onToggleGlobalSearch;
  final VoidCallback onReindexGlobalSearch;
  final String dragDropDefaultAction;
  final VoidCallback onCycleDragDropAction;
  final double panelOpacity;

  const _Toolbar({
    required this.canGoBack,
    required this.canGoForward,
    required this.isGrid,
    required this.onBack,
    required this.onForward,
    required this.onUp,
    required this.onRefresh,
    required this.onToggleView,
    required this.onNewFolder,
    required this.onRename,
    required this.onDelete,
    required this.onCopy,
    required this.onMove,
    required this.onSearchChanged,
    required this.searchController,
    required this.searchFocusNode,
    required this.globalSearchEnabled,
    required this.globalSearchLoading,
    required this.onToggleGlobalSearch,
    required this.onReindexGlobalSearch,
    required this.dragDropDefaultAction,
    required this.onCycleDragDropAction,
    required this.panelOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final activeBackground = activeColor.withValues(alpha: 0.18);
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface
            .withValues(alpha: panelOpacity),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
          IconButton(
            tooltip: 'Atrás',
            onPressed: canGoBack ? onBack : null,
            icon: const Icon(AppIcons.arrowLeft),
          ),
          IconButton(
            tooltip: 'Adelante',
            onPressed: canGoForward ? onForward : null,
            icon: const Icon(AppIcons.arrowRight),
          ),
          IconButton(
            tooltip: 'Subir',
            onPressed: onUp,
            icon: const Icon(AppIcons.arrowUp),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            icon: const Icon(AppIcons.refresh),
          ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: onSearchChanged,
              focusNode: searchFocusNode,
              controller: searchController,
              decoration: InputDecoration(
                hintText:
                    globalSearchEnabled ? 'Buscar en /home' : 'Buscar en esta carpeta',
                prefixIcon: const Icon(AppIcons.search),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: globalSearchEnabled
                      ? 'Búsqueda global activada'
                      : 'Buscar en /home',
                  onPressed: onToggleGlobalSearch,
                  icon: Icon(
                    AppIcons.globe,
                    color: globalSearchEnabled
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Reindexar búsqueda global',
                  onPressed: globalSearchLoading ? null : onReindexGlobalSearch,
                  icon: globalSearchLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.refresh),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: IconButton(
                    tooltip: 'Arrastrar: ${_dragDropLabel(dragDropDefaultAction)}',
                    onPressed: onCycleDragDropAction,
                    icon: Icon(
                      dragDropDefaultAction == 'copy'
                          ? AppIcons.copy
                          : dragDropDefaultAction == 'move'
                              ? AppIcons.move
                              : AppIcons.help,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isGrid ? activeBackground : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isGrid
                            ? activeColor.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    child: IconButton(
                      tooltip: isGrid ? 'Vista lista' : 'Vista cuadrícula',
                      onPressed: onToggleView,
                      icon: Icon(
                        isGrid ? AppIcons.list : AppIcons.grid,
                        color: isGrid ? activeColor : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<_Action>(
                  tooltip: 'Acciones',
                  onSelected: (action) {
                    switch (action) {
                      case _Action.newFolder:
                        onNewFolder();
                        break;
                      case _Action.rename:
                        onRename();
                        break;
                      case _Action.delete:
                        onDelete();
                        break;
                      case _Action.copy:
                        onCopy();
                        break;
                      case _Action.move:
                        onMove();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _Action.newFolder,
                      child: ListTile(
                        leading: Icon(AppIcons.folderPlus),
                        title: Text('Nueva carpeta'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _Action.rename,
                      child: ListTile(
                        leading: Icon(AppIcons.edit),
                        title: Text('Renombrar'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _Action.copy,
                      child: ListTile(
                        leading: Icon(AppIcons.copy),
                        title: Text('Copiar'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _Action.move,
                      child: ListTile(
                        leading: Icon(AppIcons.move),
                        title: Text('Mover'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _Action.delete,
                      child: ListTile(
                        leading: Icon(AppIcons.delete),
                        title: Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Action {
  newFolder,
  rename,
  delete,
  copy,
  move,
}

enum _ItemAction {
  open,
  openWith,
  openNewTab,
  extractHere,
  toggleFavorite,
  toggleExecutable,
  properties,
  copyMemory,
  cutMemory,
  copyRoot,
  rename,
  bulkRename,
  delete,
  copy,
  duplicate,
  move,
  compress,
  tagRed,
  tagOrange,
  tagYellow,
  tagGreen,
  tagBlue,
  tagPurple,
  tagPink,
  tagGray,
  clearTag,
}

enum _BackgroundAction {
  addShortcut,
  newFolder,
  pasteMemory,
  pasteRoot,
  refresh,
  openTerminal,
  editPath,
  copyPath,
  goHome,
  goRoot,
  goRootUser,
}

class _TagOption {
  final String id;
  final String label;
  final Color color;
  final _ItemAction action;

  const _TagOption({
    required this.id,
    required this.label,
    required this.color,
    required this.action,
  });
}

const List<_TagOption> _tagOptions = [
  _TagOption(
    id: 'red',
    label: 'Rojo',
    color: Color(0xFFE25D5D),
    action: _ItemAction.tagRed,
  ),
  _TagOption(
    id: 'orange',
    label: 'Naranja',
    color: Color(0xFFF29F4B),
    action: _ItemAction.tagOrange,
  ),
  _TagOption(
    id: 'yellow',
    label: 'Amarillo',
    color: Color(0xFFF2D04B),
    action: _ItemAction.tagYellow,
  ),
  _TagOption(
    id: 'green',
    label: 'Verde',
    color: Color(0xFF4CC47F),
    action: _ItemAction.tagGreen,
  ),
  _TagOption(
    id: 'blue',
    label: 'Azul',
    color: Color(0xFF4BA3F2),
    action: _ItemAction.tagBlue,
  ),
  _TagOption(
    id: 'purple',
    label: 'Violeta',
    color: Color(0xFF8C6FF2),
    action: _ItemAction.tagPurple,
  ),
  _TagOption(
    id: 'pink',
    label: 'Rosa',
    color: Color(0xFFE26BAE),
    action: _ItemAction.tagPink,
  ),
  _TagOption(
    id: 'gray',
    label: 'Gris',
    color: Color(0xFF9AA3AF),
    action: _ItemAction.tagGray,
  ),
];

class _PathBar extends StatelessWidget {
  final String path;
  final void Function(String path) onNavigate;
  final TextEditingController pathController;
  final FocusNode pathFocusNode;
  final bool isEditing;
  final VoidCallback onStartEdit;
  final void Function({required bool navigate}) onFinishEdit;
  final double panelOpacity;

  const _PathBar({
    required this.path,
    required this.onNavigate,
    required this.pathController,
    required this.pathFocusNode,
    required this.isEditing,
    required this.onStartEdit,
    required this.onFinishEdit,
    required this.panelOpacity,
  });

  @override
  Widget build(BuildContext context) {
    if (path == _MainScreenState._virtualRecentPath ||
        path == _MainScreenState._virtualFavoritesPath) {
      final label = path == _MainScreenState._virtualRecentPath
          ? 'Recientes'
          : 'Favoritos';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surface
              .withValues(alpha: panelOpacity),
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Icon(
                label == 'Recientes' ? AppIcons.clock : AppIcons.bookmark,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      );
    }

    final parts = <String>[];
    if (path.startsWith('/')) {
      parts.add('/');
    }
    parts.addAll(path.split('/').where((segment) => segment.isNotEmpty));
    String current = '';

    return Container(
      width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface
            .withValues(alpha: panelOpacity),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: isEditing
            ? Row(
                key: const ValueKey('path-edit'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: const Icon(AppIcons.folderOpen, size: 18),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: pathController,
                      focusNode: pathFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Escribe una ruta y presiona Enter',
                        isDense: true,
                      ),
                      onSubmitted: (_) => onFinishEdit(navigate: true),
                      onEditingComplete: () => onFinishEdit(navigate: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Cancelar',
                    onPressed: () => onFinishEdit(navigate: false),
                    icon: const Icon(AppIcons.close),
                  ),
                  IconButton(
                    tooltip: 'Ir',
                    onPressed: () => onFinishEdit(navigate: true),
                    icon: const Icon(AppIcons.arrowRight),
                  ),
                ],
              )
            : Row(
                key: const ValueKey('path-breadcrumbs'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: const Icon(AppIcons.folder, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: parts.map((part) {
                        if (part == '/') {
                          current = '/';
                        } else {
                          current =
                              current == '/' ? '/$part' : '$current/$part';
                        }
                        final targetPath = current;
                        return _BreadcrumbChip(
                          label: part == '/' ? 'Root' : part,
                          icon: part == '/'
                              ? const Icon(AppIcons.folder, size: 14)
                              : const Icon(AppIcons.chevronRight, size: 14),
                          onTap: () => onNavigate(targetPath),
                        );
                      }).toList(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar ruta',
                    onPressed: onStartEdit,
                    icon: const Icon(AppIcons.edit, size: 18),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  final List<FileItem> items;
  final Set<String> selectedPaths;
  final void Function(FileItem item, int index, List<FileItem> items) onSelect;
  final void Function(FileItem item) onOpen;
  final void Function(FileItem item, Offset position) onContextMenu;
  final void Function(FileItem source, FileItem targetFolder) onDropOnFolder;
  final String Function(int bytes) formatBytes;
  final String Function(DateTime date) formatDate;
  final _SortField sortField;
  final bool sortAscending;
  final void Function(_SortField field) onSort;
  final double panelOpacity;
  final bool Function(String path) isCut;
  final Color? Function(String path) tagColorForPath;
  final String? Function(String path) gitStatusForPath;

  const _ListView({
    required this.items,
    required this.selectedPaths,
    required this.onSelect,
    required this.onOpen,
    required this.onContextMenu,
    required this.onDropOnFolder,
    required this.formatBytes,
    required this.formatDate,
    required this.sortField,
    required this.sortAscending,
    required this.onSort,
    required this.panelOpacity,
    required this.isCut,
    required this.tagColorForPath,
    required this.gitStatusForPath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: (panelOpacity - 0.05).clamp(0.6, 1.0)),
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                flex: 3,
                child: _SortHeader(
                  label: 'Nombre',
                  isActive: sortField == _SortField.name,
                  ascending: sortAscending,
                  onTap: () => onSort(_SortField.name),
                ),
              ),
              Expanded(
                flex: 2,
                child: _SortHeader(
                  label: 'Tamaño',
                  isActive: sortField == _SortField.size,
                  ascending: sortAscending,
                  onTap: () => onSort(_SortField.size),
                ),
              ),
              Expanded(
                flex: 2,
                child: _SortHeader(
                  label: 'Modificado',
                  isActive: sortField == _SortField.modified,
                  ascending: sortAscending,
                  onTap: () => onSort(_SortField.modified),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            cacheExtent: 600,
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = selectedPaths.contains(item.path);
              final tagColor = tagColorForPath(item.path);
              final gitStatus = gitStatusForPath(item.path);
              final row = Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(item, index, items),
                  onDoubleTap: () => onOpen(item),
                  onSecondaryTapDown: (details) =>
                      onContextMenu(item, details.globalPosition),
                  child: _HoverAnimatedContainer(
                    selected: isSelected,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _buildItemIcon(context, item),
                        const SizedBox(width: 12),
                        if (tagColor != null) ...[
                          _TagDot(color: tagColor),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (gitStatus != null)
                                _GitBadge(status: gitStatus),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.isDirectory
                                ? '--'
                                : formatBytes(item.sizeBytes),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(formatDate(item.modifiedAt)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              return DragTarget<FileItem>(
                onWillAcceptWithDetails: (details) =>
                    item.isDirectory && details.data.path != item.path,
                onAcceptWithDetails: (details) =>
                    onDropOnFolder(details.data, item),
                builder: (context, candidateData, rejectedData) => Draggable<
                    FileItem>(
                  data: item,
                  feedback: _DragFeedback(
                    name: item.name,
                    isDirectory: item.isDirectory,
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.4,
                    child: row,
                  ),
                  child: Opacity(
                    opacity: isCut(item.path) ? 0.45 : 1,
                    child: RepaintBoundary(child: row),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GridView extends StatelessWidget {
  final List<FileItem> items;
  final Set<String> selectedPaths;
  final void Function(FileItem item, int index, List<FileItem> items) onSelect;
  final void Function(FileItem item) onOpen;
  final void Function(FileItem item, Offset position) onContextMenu;
  final void Function(FileItem source, FileItem targetFolder) onDropOnFolder;
  final bool Function(String path) isCut;
  final Color? Function(String path) tagColorForPath;
  final String? Function(String path) gitStatusForPath;

  const _GridView({
    required this.items,
    required this.selectedPaths,
    required this.onSelect,
    required this.onOpen,
    required this.onContextMenu,
    required this.onDropOnFolder,
    required this.isCut,
    required this.tagColorForPath,
    required this.gitStatusForPath,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      cacheExtent: 800,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: 132,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedPaths.contains(item.path);
        final tagColor = tagColorForPath(item.path);
        final gitStatus = gitStatusForPath(item.path);
        final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.1,
            );
        final tile = InkWell(
          onTap: () => onSelect(item, index, items),
          onDoubleTap: () => onOpen(item),
          onSecondaryTapDown: (details) =>
              onContextMenu(item, details.globalPosition),
          borderRadius: BorderRadius.circular(12),
          child: _HoverAnimatedContainer(
            selected: isSelected,
            padding: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: _isImageFile(item)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(item.path),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    AppIcons.image,
                                    size: 40,
                                    color: Theme.of(context).iconTheme.color,
                                  ),
                                ),
                              )
                            : Icon(
                                item.isDirectory
                                    ? AppIcons.folder
                                    : AppIcons.file,
                                size: item.isDirectory ? 44 : 40,
                                color: item.isDirectory
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).iconTheme.color,
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: Text(
                        item.name,
                        style: labelStyle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (tagColor != null)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: _TagDot(color: tagColor),
                  ),
                if (gitStatus != null)
                  Positioned(
                    left: 4,
                    top: 4,
                    child: _GitBadge(status: gitStatus),
                  ),
              ],
            ),
          ),
        );
        return DragTarget<FileItem>(
          onWillAcceptWithDetails: (details) =>
              item.isDirectory && details.data.path != item.path,
          onAcceptWithDetails: (details) =>
              onDropOnFolder(details.data, item),
          builder: (context, candidateData, rejectedData) => Draggable<FileItem>(
            data: item,
            feedback: _DragFeedback(
              name: item.name,
              isDirectory: item.isDirectory,
            ),
            childWhenDragging: Opacity(
              opacity: 0.4,
              child: tile,
            ),
            child: Opacity(
              opacity: isCut(item.path) ? 0.45 : 1,
              child: RepaintBoundary(child: tile),
            ),
          ),
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  final int itemCount;
  final int totalCount;
  final int selectedCount;
  final String currentPath;
  final bool globalSearchEnabled;
  final DateTime? globalSearchBuiltAt;
  final String? gitRoot;
  final String dragDropDefaultAction;

  const _StatusBar({
    required this.itemCount,
    required this.totalCount,
    required this.selectedCount,
    required this.currentPath,
    required this.globalSearchEnabled,
    required this.globalSearchBuiltAt,
    required this.gitRoot,
    required this.dragDropDefaultAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall;
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selectedCount > 0
                  ? '$selectedCount seleccionado(s) · $itemCount de $totalCount elementos'
                  : '$itemCount de $totalCount elementos',
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (globalSearchEnabled && globalSearchBuiltAt != null) ...[
                  Text(
                    'Índice: ${_formatDate(globalSearchBuiltAt!)}',
                    style: labelStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 10),
                ],
                if (gitRoot != null) ...[
                  Text(
                    'Git: ${_basename(gitRoot!)}',
                    style: labelStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  'Arrastrar: ${_dragDropLabel(dragDropDefaultAction)}',
                  style: labelStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              currentPath,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _basename(String path) {
    if (path == '/') return '/';
    final parts = path.split(Platform.pathSeparator);
    return parts.isEmpty ? path : parts.last;
  }
}

String _dragDropLabel(String value) {
  switch (value) {
    case 'copy':
      return 'Copiar';
    case 'move':
      return 'Mover';
    default:
      return 'Preguntar';
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData? icon;
  final bool isLoading;

  const _EmptyState({
    required this.message,
    this.subtitle,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = theme.colorScheme.primary.withValues(alpha: 0.12);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tone,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? AppIcons.folderX,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (isLoading) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortHeader extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool ascending;
  final VoidCallback onTap;

  const _SortHeader({
    required this.label,
    required this.isActive,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
        );
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Text(label, style: labelStyle),
          const SizedBox(width: 6),
          if (isActive)
            Icon(
              ascending ? AppIcons.arrowUp : AppIcons.arrowDown,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

class _Place {
  final String label;
  final String path;
  final IconData icon;
  final bool isCustom;
  final bool isHeader;
  final String? subtitle;
  final int? usagePercent;

  const _Place(
    this.label,
    this.path,
    this.icon, {
    this.isCustom = false,
    this.subtitle,
    this.usagePercent,
  }) : isHeader = false;

  const _Place.header(this.label)
      : path = '',
        icon = AppIcons.folder,
        isCustom = false,
        subtitle = null,
        usagePercent = null,
        isHeader = true;
}

class _DetailsPanel extends StatelessWidget {
  final FileItem? selectedItem;
  final String Function(int bytes) formatBytes;
  final String Function(DateTime date) formatDate;
  final bool Function(FileItem item) isImageFile;
  final FileService fileService;
  final double previewSize;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final int selectedCount;
  final String? Function(String path) tagLabelForPath;
  final Color? Function(String path) tagColorForPath;
  final List<String> history;
  final Map<String, int> historyVisits;
  final Map<String, DateTime> historyLastVisited;
  final ValueChanged<String> onNavigate;
  final VoidCallback onClearHistory;
  final double panelOpacity;

  const _DetailsPanel({
    super.key,
    required this.selectedItem,
    required this.formatBytes,
    required this.formatDate,
    required this.isImageFile,
    required this.fileService,
    required this.previewSize,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.selectedCount,
    required this.tagLabelForPath,
    required this.tagColorForPath,
    required this.history,
    required this.historyVisits,
    required this.historyLastVisited,
    required this.onNavigate,
    required this.onClearHistory,
    required this.panelOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: panelOpacity),
        border: Border(
          left: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: selectedItem == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalles',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedCount > 1
                        ? 'Seleccionados: $selectedCount elementos.'
                        : 'Selecciona un elemento para ver sus propiedades.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Center(
                      child: Lottie.asset(
                        'assets/lottie/right_panel/work.json',
                        width: 180,
                        height: 180,
                        repeat: true,
                      ),
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detalles', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _DetailsSection(
                      title: 'Previsualización',
                      child: isImageFile(selectedItem!)
                          ? Center(
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => _showImagePreviewDialog(
                                      context,
                                      selectedItem!.path,
                                    ),
                                    child: _ImagePreview(
                                      path: selectedItem!.path,
                                      size: previewSize,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        tooltip: 'Zoom -',
                                        onPressed: onZoomOut,
                                        icon: const Icon(AppIcons.remove),
                                      ),
                                      Text(
                                        '${previewSize.toInt()} px',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                      IconButton(
                                        tooltip: 'Zoom +',
                                        onPressed: onZoomIn,
                                        icon: const Icon(AppIcons.add),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : _FilePreview(
                              item: selectedItem!,
                              fileService: fileService,
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      selectedItem!.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    _DetailsSection(
                      title: 'Propiedades',
                      child: Column(
                        children: [
                          _TagDetailRow(
                            label: 'Etiqueta',
                            tagLabel: tagLabelForPath(selectedItem!.path),
                            tagColor: tagColorForPath(selectedItem!.path),
                          ),
                          _DetailRow(
                            label: 'Tipo',
                            value:
                                selectedItem!.isDirectory ? 'Carpeta' : 'Archivo',
                          ),
                          _DetailRow(
                            label: 'Tamaño',
                            value: selectedItem!.isDirectory
                                ? '--'
                                : formatBytes(selectedItem!.sizeBytes),
                          ),
                          _DetailRow(
                            label: 'Modificado',
                            value: formatDate(selectedItem!.modifiedAt),
                          ),
                          _DetailRow(
                            label: 'Ruta',
                            value: selectedItem!.path,
                            selectable: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailsSection(
                      child: _HistoryPanel(
                        history: history,
                        historyVisits: historyVisits,
                        historyLastVisited: historyLastVisited,
                        onNavigate: onNavigate,
                        onClear: onClearHistory,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _FilePreview extends StatelessWidget {
  final FileItem item;
  final FileService fileService;

  const _FilePreview({
    required this.item,
    required this.fileService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const previewSize = 180.0;

    if (item.isDirectory) {
      return _PreviewFrame(
        size: previewSize,
        child: Icon(
          AppIcons.folder,
          size: 64,
          color: theme.colorScheme.primary,
        ),
      );
    }

    if (_isPdfFile(item)) {
      return FutureBuilder<String?>(
        future: fileService.generatePdfPreview(item.path),
        builder: (context, snapshot) {
          final path = snapshot.data;
          return _PreviewFrame(
            size: previewSize,
            label: 'PDF',
            child: path == null
                ? Icon(
                    AppIcons.file,
                    size: 64,
                    color: theme.colorScheme.primary,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _ImagePreview(
                      path: path,
                      size: previewSize,
                      fit: BoxFit.cover,
                    ),
                  ),
          );
        },
      );
    }

    if (_isVideoFile(item)) {
      return _MediaPreview(
        item: item,
        isVideo: true,
        fileService: fileService,
      );
    }

    if (_isAudioFile(item)) {
      return _MediaPreview(
        item: item,
        isVideo: false,
        fileService: fileService,
      );
    }

    if (_isMarkdownFile(item)) {
      return FutureBuilder<String>(
        future: _readMarkdownPreview(item.path),
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null || data.trim().isEmpty) {
            return _PreviewFrame(
              size: previewSize,
              label: 'Markdown',
              child: Icon(
                AppIcons.file,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Markdown(
                      data: data,
                      padding: const EdgeInsets.all(12),
                      styleSheet: MarkdownStyleSheet.fromTheme(theme),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Markdown',
                style: theme.textTheme.labelMedium,
              ),
            ],
          );
        },
      );
    }

    return _PreviewFrame(
      size: previewSize,
      child: Icon(
        AppIcons.file,
        size: 64,
        color: theme.colorScheme.primary,
      ),
    );
  }

}

class _PreviewFrame extends StatelessWidget {
  final Widget child;
  final double size;
  final String? label;

  const _PreviewFrame({
    required this.child,
    required this.size,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frame = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      alignment: Alignment.center,
      child: child,
    );
    if (label == null) {
      return Center(child: frame);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        frame,
        const SizedBox(height: 6),
        Text(label!, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _MediaPreview extends StatefulWidget {
  final FileItem item;
  final bool isVideo;
  final FileService fileService;

  const _MediaPreview({
    required this.item,
    required this.isVideo,
    required this.fileService,
  });

  @override
  State<_MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<_MediaPreview> {
  late final Player _player;
  VideoController? _videoController;

  @override
  void initState() {
    super.initState();
    _player = Player();
    if (widget.isVideo) {
      _videoController = VideoController(_player);
    }
    _openMedia();
  }

  @override
  void didUpdateWidget(covariant _MediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _openMedia();
    }
  }

  Future<void> _openMedia() async {
    await _player.open(Media(widget.item.path), play: false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = widget.isVideo
        ? _buildVideoPreview(theme)
        : _buildAudioPreview(theme);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        preview,
        const SizedBox(height: 10),
        _MediaControls(player: _player),
        if (!widget.isVideo) ...[
          const SizedBox(height: 8),
          _AudioMetadata(
            path: widget.item.path,
            fileService: widget.fileService,
          ),
        ],
      ],
    );
  }

  Widget _buildVideoPreview(ThemeData theme) {
    final controller = _videoController;
    if (controller == null) {
      return _PreviewFrame(
        size: 190,
        label: 'Video',
        child: Icon(
          AppIcons.videos,
          size: 64,
          color: theme.colorScheme.primary,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 220,
            height: 140,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Video(
              controller: controller,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text('Video', style: theme.textTheme.labelMedium),
      ],
    );
  }

  Widget _buildAudioPreview(ThemeData theme) {
    return _PreviewFrame(
      size: 190,
      label: 'Audio',
      child: Icon(
        AppIcons.music,
        size: 64,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _MediaControls extends StatelessWidget {
  final Player player;

  const _MediaControls({required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<bool>(
      stream: player.stream.playing,
      initialData: false,
      builder: (context, playingSnap) {
        final isPlaying = playingSnap.data ?? false;
        return Column(
          children: [
            StreamBuilder<Duration>(
              stream: player.stream.position,
              initialData: Duration.zero,
              builder: (context, positionSnap) {
                return StreamBuilder<Duration>(
                  stream: player.stream.duration,
                  initialData: Duration.zero,
                  builder: (context, durationSnap) {
                    final position = positionSnap.data ?? Duration.zero;
                    final duration = durationSnap.data ?? Duration.zero;
                    final max = duration.inMilliseconds > 0
                        ? duration.inMilliseconds.toDouble()
                        : 1.0;
                    final value = position.inMilliseconds
                        .clamp(0, max.toInt())
                        .toDouble();
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                          ),
                          child: Slider(
                            value: value,
                            max: max,
                            onChanged: (newValue) {
                              player.seek(
                                Duration(milliseconds: newValue.round()),
                              );
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDurationValue(position),
                              style: theme.textTheme.labelSmall,
                            ),
                            Text(
                              _formatDurationValue(duration),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                  onPressed: () {
                    if (isPlaying) {
                      player.pause();
                    } else {
                      player.play();
                    }
                  },
                  icon: Icon(isPlaying ? AppIcons.pause : AppIcons.play),
                ),
                IconButton(
                  tooltip: 'Detener',
                  onPressed: () => player.stop(),
                  icon: const Icon(AppIcons.stop),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AudioMetadata extends StatelessWidget {
  final String path;
  final FileService fileService;

  const _AudioMetadata({
    required this.path,
    required this.fileService,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: fileService.readAudioMetadata(path),
      builder: (context, snapshot) {
        final meta = snapshot.data ?? {};
        if (meta.isEmpty) {
          return const SizedBox.shrink();
        }
        final rows = <Widget>[];
        final duration = _formatDuration(meta['Duración']);
        final bitrate = _formatBitrate(meta['Bitrate']);
        if (meta['Título'] != null) {
          rows.add(_buildMetaRow('Título', meta['Título']!));
        }
        if (meta['Artista'] != null) {
          rows.add(_buildMetaRow('Artista', meta['Artista']!));
        }
        if (meta['Álbum'] != null) {
          rows.add(_buildMetaRow('Álbum', meta['Álbum']!));
        }
        if (duration != null) {
          rows.add(_buildMetaRow('Duración', duration));
        }
        if (bitrate != null) {
          rows.add(_buildMetaRow('Bitrate', bitrate));
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: rows,
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool selectable;

  const _DetailRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final valueStyle = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 3),
          selectable
              ? SelectableText(
                  value,
                  maxLines: 3,
                  style: valueStyle,
                )
              : Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
        ],
      ),
    );
  }
}

class _TagDetailRow extends StatelessWidget {
  final String label;
  final String? tagLabel;
  final Color? tagColor;

  const _TagDetailRow({
    required this.label,
    required this.tagLabel,
    required this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    final value = tagLabel ?? 'Sin etiqueta';
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final valueStyle = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 3),
          Row(
            children: [
              if (tagColor != null) ...[
                _TagDot(color: tagColor!, size: 10),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final String? title;
  final Widget child;

  const _DetailsSection({
    this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

class _TagDot extends StatelessWidget {
  final Color color;
  final double size;

  const _TagDot({
    required this.color,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _GitBadge extends StatelessWidget {
  final String status;

  const _GitBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    switch (status) {
      case 'M':
        color = Colors.orangeAccent;
        break;
      case 'A':
        color = Colors.greenAccent;
        break;
      case 'D':
        color = Colors.redAccent;
        break;
      case '?':
        color = theme.colorScheme.primary;
        break;
      default:
        color = theme.colorScheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _BulkRenameConfig {
  final String format;
  final String find;
  final String replace;
  final bool useRegex;

  const _BulkRenameConfig({
    required this.format,
    required this.find,
    required this.replace,
    required this.useRegex,
  });
}

class _RenamePreset {
  final String name;
  final String format;
  final String find;
  final String replace;
  final bool useRegex;

  const _RenamePreset({
    required this.name,
    required this.format,
    required this.find,
    required this.replace,
    required this.useRegex,
  });

  factory _RenamePreset.fromMap(Map<String, dynamic> map) {
    return _RenamePreset(
      name: map['name'] as String? ?? 'Preset',
      format: map['format'] as String? ?? '{name}{ext}',
      find: map['find'] as String? ?? '',
      replace: map['replace'] as String? ?? '',
      useRegex: map['useRegex'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'format': format,
        'find': find,
        'replace': replace,
        'useRegex': useRegex,
      };
}

class _HistoryPanel extends StatelessWidget {
  final List<String> history;
  final Map<String, int> historyVisits;
  final Map<String, DateTime> historyLastVisited;
  final ValueChanged<String> onNavigate;
  final VoidCallback onClear;

  const _HistoryPanel({
    required this.history,
    required this.historyVisits,
    required this.historyLastVisited,
    required this.onNavigate,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final items = history.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Historial',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            TextButton(
              onPressed: onClear,
              child: const Text('Limpiar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'Sin historial aún.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Theme.of(context).dividerColor,
              ),
              itemBuilder: (context, index) {
                final path = items[index];
                final label = path == '/' ? 'Root' : path.split('/').last;
                final visits = historyVisits[path] ?? 0;
                final lastVisited = historyLastVisited[path];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(
                    AppIcons.folder,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Visitas: $visits'
                        '${lastVisited != null ? ' · Último: ${_formatHistoryDate(lastVisited)}' : ''}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  onTap: () => onNavigate(path),
                );
              },
            ),
          ),
      ],
    );
  }

  String _formatHistoryDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

class _DragFeedback extends StatelessWidget {
  final String name;
  final bool isDirectory;

  const _DragFeedback({
    required this.name,
    required this.isDirectory,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDirectory ? AppIcons.folder : AppIcons.file,
              color: isDirectory
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 8),
            Text(name, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class _DeleteIntent extends Intent {
  const _DeleteIntent();
}

class _RenameIntent extends Intent {
  const _RenameIntent();
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class _ForwardIntent extends Intent {
  const _ForwardIntent();
}

class _UpIntent extends Intent {
  const _UpIntent();
}

class _NewFolderIntent extends Intent {
  const _NewFolderIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _ToggleHiddenIntent extends Intent {
  const _ToggleHiddenIntent();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _ImagePreview extends StatelessWidget {
  final String path;
  final double size;
  final BoxFit fit;

  const _ImagePreview({
    required this.path,
    required this.size,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (size * pixelRatio).round();
    if (path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.file(
        File(path),
        width: size,
        height: size,
        fit: fit,
        placeholderBuilder: (_) => Icon(
          AppIcons.image,
          size: size,
          color: Theme.of(context).iconTheme.color,
        ),
      );
    }
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: fit,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Icon(
        AppIcons.image,
        size: size,
        color: Theme.of(context).iconTheme.color,
      ),
    );
  }
}

Future<void> _showImagePreviewDialog(BuildContext context, String path) async {
  final size = MediaQuery.of(context).size;
  final maxSize = (size.shortestSide * 0.8).clamp(240, 720);
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: _ImagePreview(
          path: path,
          size: maxSize.toDouble(),
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}

bool _isImageFile(FileItem item) {
  if (item.isDirectory) {
    return false;
  }
  final name = item.name.toLowerCase();
  return name.endsWith('.png') ||
      name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.gif') ||
      name.endsWith('.webp') ||
      name.endsWith('.bmp') ||
      name.endsWith('.svg') ||
      name.endsWith('.tiff') ||
      name.endsWith('.tif') ||
      name.endsWith('.heic') ||
      name.endsWith('.heif');
}

bool _isPdfFile(FileItem item) {
  if (item.isDirectory) {
    return false;
  }
  return item.name.toLowerCase().endsWith('.pdf');
}

bool _isVideoFile(FileItem item) {
  if (item.isDirectory) {
    return false;
  }
  final name = item.name.toLowerCase();
  return name.endsWith('.mp4') ||
      name.endsWith('.mkv') ||
      name.endsWith('.mov') ||
      name.endsWith('.avi') ||
      name.endsWith('.webm') ||
      name.endsWith('.flv') ||
      name.endsWith('.wmv') ||
      name.endsWith('.m4v') ||
      name.endsWith('.mpeg') ||
      name.endsWith('.mpg');
}

bool _isAudioFile(FileItem item) {
  if (item.isDirectory) {
    return false;
  }
  final name = item.name.toLowerCase();
  return name.endsWith('.mp3') ||
      name.endsWith('.flac') ||
      name.endsWith('.wav') ||
      name.endsWith('.ogg') ||
      name.endsWith('.m4a') ||
      name.endsWith('.aac') ||
      name.endsWith('.opus') ||
      name.endsWith('.wma');
}

bool _isMarkdownFile(FileItem item) {
  if (item.isDirectory) {
    return false;
  }
  final name = item.name.toLowerCase();
  return name.endsWith('.md') ||
      name.endsWith('.markdown') ||
      name.endsWith('.mdown') ||
      name.endsWith('.mkd');
}

Widget _buildMetaRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Future<String> _readMarkdownPreview(String path) async {
  const maxBytes = 12000;
  try {
    final chunks = <int>[];
    await for (final chunk in File(path).openRead(0, maxBytes)) {
      chunks.addAll(chunk);
      if (chunks.length >= maxBytes) {
        break;
      }
    }
    return utf8.decode(chunks, allowMalformed: true);
  } catch (_) {
    return '';
  }
}

String? _formatDuration(String? rawSeconds) {
  if (rawSeconds == null) {
    return null;
  }
  final seconds = double.tryParse(rawSeconds);
  if (seconds == null) {
    return rawSeconds;
  }
  final total = seconds.round();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')}';
}

String _formatDurationValue(Duration value) {
  final total = value.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${secs.toString().padLeft(2, '0')}';
}

String? _formatBitrate(String? rawBitrate) {
  if (rawBitrate == null) {
    return null;
  }
  final bitrate = double.tryParse(rawBitrate);
  if (bitrate == null) {
    return rawBitrate;
  }
  final kbps = bitrate / 1000;
  if (kbps >= 1000) {
    final mbps = kbps / 1000;
    return '${mbps.toStringAsFixed(1)} Mbps';
  }
  return '${kbps.toStringAsFixed(0)} kbps';
}

bool _isArchivePath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.zip') ||
      lower.endsWith('.rar') ||
      lower.endsWith('.7z') ||
      lower.endsWith('.tar') ||
      lower.endsWith('.tar.gz') ||
      lower.endsWith('.tgz') ||
      lower.endsWith('.tar.xz') ||
      lower.endsWith('.txz') ||
      lower.endsWith('.tar.bz2') ||
      lower.endsWith('.tbz2');
}

Widget _buildItemIcon(BuildContext context, FileItem item, {double size = 20}) {
  if (_isArchivePath(item.path)) {
    return Icon(
      AppIcons.archive,
      size: size,
      color: Theme.of(context).colorScheme.primary,
    );
  }
  if (_isImageFile(item)) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: _ImagePreview(
        path: item.path,
        size: size,
        fit: BoxFit.cover,
      ),
    );
  }
  return Icon(
    item.isDirectory ? AppIcons.folder : AppIcons.file,
    size: size,
    color: item.isDirectory
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).iconTheme.color,
  );
}
