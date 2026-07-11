#!/usr/bin/env python3
"""Generate all Dart source files for AdvanceFileManager Flutter+C++ project."""
import os

BASE = '/home/npznnz/Project/advance_file_manager'

files = {}

# ============================================================
# 1. lib/utils/formatters.dart
# ============================================================
files['lib/utils/formatters.dart'] = r'''class Formatters {
  static String formatSize(int bytes) {
    if (bytes < 0) return '--';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes < 1099511627776) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    return '${(bytes / 1099511627776).toStringAsFixed(1)} TB';
  }

  static String formatDate(int epochSeconds) {
    if (epochSeconds <= 0) return '--';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String formatPermissions(int mode) {
    return '${_typeChar(mode >> 12)}'
        '${(mode & 0400) != 0 ? 'r' : '-'}${(mode & 0200) != 0 ? 'w' : '-'}${(mode & 0100) != 0 ? 'x' : '-'}'
        '${(mode & 040) != 0 ? 'r' : '-'}${(mode & 020) != 0 ? 'w' : '-'}${(mode & 010) != 0 ? 'x' : '-'}'
        '${(mode & 04) != 0 ? 'r' : '-'}${(mode & 02) != 0 ? 'w' : '-'}${(mode & 01) != 0 ? 'x' : '-'}';
  }

  static String _typeChar(int type) {
    switch (type) {
      case 0x4: return 'd';
      case 0xA: return 'l';
      case 0x1: return 'p';
      case 0x2: return 'c';
      case 0x6: return 'b';
      case 0xC: return 's';
      default: return '-';
    }
  }

  static String formatOctalPermissions(int mode) {
    return '0${(mode >> 6) & 7}${(mode >> 3) & 7}${mode & 7}';
  }
}
'''

# ============================================================
# 2. lib/models/file_entry.dart
# ============================================================
files['lib/models/file_entry.dart'] = r'''import '../utils/formatters.dart';

enum FileType {
  unknown, regular, directory, symlink, socket, fifo, blockDevice, charDevice;

  static FileType fromInt(int v) {
    switch (v) {
      case 1: return FileType.regular;
      case 2: return FileType.directory;
      case 3: return FileType.symlink;
      case 4: return FileType.socket;
      case 5: return FileType.fifo;
      case 6: return FileType.blockDevice;
      case 7: return FileType.charDevice;
      default: return FileType.unknown;
    }
  }
}

enum SortMode { name, size, modified, type }
enum ViewMode { list, grid }

class FileEntry {
  final String name;
  final String path;
  final String symlinkTarget;
  final FileType type;
  final int size;
  final int modifiedTime;
  final int accessTime;
  final int createdTime;
  final int permissions;
  final int uid;
  final int gid;
  final String ownerName;
  final String groupName;
  final String mimeType;
  final bool isReadable;
  final bool isWritable;
  final bool isExecutable;
  final bool isHidden;

  FileEntry({
    required this.name,
    required this.path,
    this.symlinkTarget = '',
    required this.type,
    required this.size,
    required this.modifiedTime,
    this.accessTime = 0,
    this.createdTime = 0,
    required this.permissions,
    this.uid = 0,
    this.gid = 0,
    this.ownerName = '',
    this.groupName = '',
    this.mimeType = '',
    this.isReadable = true,
    this.isWritable = false,
    this.isExecutable = false,
    this.isHidden = false,
  });

  bool get isDirectory => type == FileType.directory;
  bool get isFile => type == FileType.regular;
  bool get isSymlink => type == FileType.symlink;
  String get sizeFormatted => isDirectory ? '--' : Formatters.formatSize(size);
  String get modifiedFormatted => Formatters.formatDate(modifiedTime);
  String get permissionsFormatted => Formatters.formatPermissions(permissions);
  String get octalPermissions => Formatters.formatOctalPermissions(permissions);

  factory FileEntry.fromJson(Map<String, dynamic> json) => FileEntry(
    name: json['name'] ?? '',
    path: json['path'] ?? '',
    symlinkTarget: json['symlinkTarget'] ?? '',
    type: FileType.fromInt(json['type'] ?? 0),
    size: json['size'] ?? 0,
    modifiedTime: json['modifiedTime'] ?? 0,
    accessTime: json['accessTime'] ?? 0,
    createdTime: json['createdTime'] ?? 0,
    permissions: json['permissions'] ?? 0,
    uid: json['uid'] ?? 0,
    gid: json['gid'] ?? 0,
    ownerName: json['ownerName'] ?? '',
    groupName: json['groupName'] ?? '',
    mimeType: json['mimeType'] ?? '',
    isReadable: json['isReadable'] ?? false,
    isWritable: json['isWritable'] ?? false,
    isExecutable: json['isExecutable'] ?? false,
    isHidden: json['isHidden'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'path': path, 'type': type.index, 'size': size,
    'modifiedTime': modifiedTime, 'permissions': permissions,
  };
}

class DiskUsage {
  final int totalSpace;
  final int freeSpace;
  final int usedSpace;
  DiskUsage({required this.totalSpace, required this.freeSpace, required this.usedSpace});
  double get percent => totalSpace > 0 ? usedSpace / totalSpace * 100 : 0;
  String get totalFormatted => Formatters.formatSize(totalSpace);
  String get freeFormatted => Formatters.formatSize(freeSpace);
  String get usedFormatted => Formatters.formatSize(usedSpace);
}

class FileHash {
  final String md5, sha1, sha256, sha512, crc32;
  FileHash({required this.md5, required this.sha1, required this.sha256, required this.sha512, required this.crc32});
}
'''

# ============================================================
# 3. lib/models/bookmark.dart
# ============================================================
files['lib/models/bookmark.dart'] = r'''class Bookmark {
  final String name;
  final String path;
  Bookmark({required this.name, required this.path});
}
'''

# ============================================================
# 4. lib/providers/file_manager_state.dart
# ============================================================
files['lib/providers/file_manager_state.dart'] = r'''import 'package:flutter/material.dart';
import '../models/file_entry.dart';
import '../models/bookmark.dart';
import '../services/file_service.dart';

class TabState {
  final String id;
  String currentPath;
  List<FileEntry> entries;
  bool loading;
  String? error;
  List<String> history;
  int historyIndex;
  bool showHidden;
  SortMode sortMode;
  bool sortAscending;
  ViewMode viewMode;
  Set<String> selectedPaths;
  String searchQuery;
  bool isSearching;

  TabState({
    required this.id,
    required this.currentPath,
    List<FileEntry>? entries,
    this.loading = true,
    this.error,
    List<String>? history,
    this.historyIndex = 0,
    this.showHidden = false,
    this.sortMode = SortMode.name,
    this.sortAscending = true,
    this.viewMode = ViewMode.list,
    Set<String>? selectedPaths,
    this.searchQuery = '',
    this.isSearching = false,
  }) : entries = entries ?? [],
       history = history ?? [currentPath],
       selectedPaths = selectedPaths ?? {};
}

class FileManagerState extends ChangeNotifier {
  final FileService _fileService = FileService();
  List<TabState> tabs = [];
  int currentTabIndex = 0;
  List<Bookmark> bookmarks = [];
  DrawerSection drawerSection = DrawerSection.storage;

  FileManagerState() {
    final home = _fileService.getHomeDirectory();
    tabs.add(TabState(id: '0', currentPath: home));
    loadCurrentTab();
  }

  TabState get currentTab => tabs[currentTabIndex];
  FileService get fileService => _fileService;

  void addTab(String path) {
    final id = '${tabs.length}';
    tabs.add(TabState(id: id, currentPath: path));
    currentTabIndex = tabs.length - 1;
    loadCurrentTab();
    notifyListeners();
  }

  void closeTab(int index) {
    if (tabs.length <= 1) return;
    tabs.removeAt(index);
    if (currentTabIndex >= tabs.length) currentTabIndex = tabs.length - 1;
    notifyListeners();
  }

  void switchTab(int index) {
    currentTabIndex = index;
    notifyListeners();
  }

  void loadCurrentTab() {
    final tab = currentTab;
    tab.loading = true;
    tab.error = null;
    notifyListeners();

    try {
      final entries = _fileService.listDirectory(tab.currentPath, showHidden: tab.showHidden);
      _sortEntries(entries, tab.sortMode, tab.sortAscending);
      tab.entries = entries;
      tab.loading = false;
    } catch (e) {
      tab.error = e.toString();
      tab.loading = false;
    }
    notifyListeners();
  }

  void _sortEntries(List<FileEntry> entries, SortMode mode, bool ascending) {
    entries.sort((a, b) {
      // Directories always first
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int cmp;
      switch (mode) {
        case SortMode.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortMode.size:
          cmp = a.size.compareTo(b.size);
          break;
        case SortMode.modified:
          cmp = a.modifiedTime.compareTo(b.modifiedTime);
          break;
        case SortMode.type:
          cmp = a.mimeType.compareTo(b.mimeType);
          if (cmp == 0) cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
      }
      return ascending ? cmp : -cmp;
    });
  }

  void navigateTo(String path) {
    final tab = currentTab;
    if (tab.historyIndex < tab.history.length - 1) {
      tab.history.removeRange(tab.historyIndex + 1, tab.history.length);
    }
    tab.currentPath = path;
    tab.history.add(path);
    tab.historyIndex = tab.history.length - 1;
    tab.selectedPaths.clear();
    tab.isSearching = false;
    tab.searchQuery = '';
    loadCurrentTab();
  }

  void goBack() {
    final tab = currentTab;
    if (tab.historyIndex > 0) {
      tab.historyIndex--;
      tab.currentPath = tab.history[tab.historyIndex];
      tab.selectedPaths.clear();
      loadCurrentTab();
    }
  }

  void goForward() {
    final tab = currentTab;
    if (tab.historyIndex < tab.history.length - 1) {
      tab.historyIndex++;
      tab.currentPath = tab.history[tab.historyIndex];
      tab.selectedPaths.clear();
      loadCurrentTab();
    }
  }

  void goUp() {
    final parent = FileService.getParentPath(currentTab.currentPath);
    if (parent != currentTab.currentPath) navigateTo(parent);
  }

  void toggleHidden() {
    currentTab.showHidden = !currentTab.showHidden;
    loadCurrentTab();
  }

  void setSortMode(SortMode mode) {
    final tab = currentTab;
    if (tab.sortMode == mode) {
      tab.sortAscending = !tab.sortAscending;
    } else {
      tab.sortMode = mode;
      tab.sortAscending = true;
    }
    _sortEntries(tab.entries, tab.sortMode, tab.sortAscending);
    notifyListeners();
  }

  void setViewMode(ViewMode mode) {
    currentTab.viewMode = mode;
    notifyListeners();
  }

  void toggleSelection(String path) {
    final tab = currentTab;
    if (tab.selectedPaths.contains(path)) {
      tab.selectedPaths.remove(path);
    } else {
      tab.selectedPaths.add(path);
    }
    notifyListeners();
  }

  void selectAll() {
    final tab = currentTab;
    tab.selectedPaths = tab.entries.map((e) => e.path).toSet();
    notifyListeners();
  }

  void clearSelection() {
    currentTab.selectedPaths.clear();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    currentTab.searchQuery = query;
    notifyListeners();
  }

  void toggleSearch() {
    final tab = currentTab;
    tab.isSearching = !tab.isSearching;
    if (!tab.isSearching) tab.searchQuery = '';
    notifyListeners();
  }

  List<FileEntry> get filteredEntries {
    final tab = currentTab;
    if (tab.isSearching && tab.searchQuery.isNotEmpty) {
      return tab.entries.where((e) =>
        e.name.toLowerCase().contains(tab.searchQuery.toLowerCase())
      ).toList();
    }
    return tab.entries;
  }

  void addBookmark(String name, String path) {
    bookmarks.add(Bookmark(name: name, path: path));
    notifyListeners();
  }

  void removeBookmark(int index) {
    bookmarks.removeAt(index);
    notifyListeners();
  }

  void setDrawerSection(DrawerSection section) {
    drawerSection = section;
    notifyListeners();
  }

  // File operations
  String? createDirectory(String path) => _fileService.createDirectory(path);
  String? createFile(String path) => _fileService.createFile(path);
  String? deleteFile(String path) => _fileService.deleteFile(path);
  String? rename(String oldPath, String newPath) => _fileService.rename(oldPath, newPath);
  String? copyFile(String src, String dst) => _fileService.copyFile(src, dst);
  String? moveFile(String src, String dst) => _fileService.moveFile(src, dst);
  bool exists(String path) => _fileService.exists(path);
  FileEntry? getFileInfo(String path) => _fileService.getFileInfo(path);
  FileHash? computeHash(String path) => _fileService.computeHash(path);
  DiskUsage? getDiskUsage(String path) => _fileService.getDiskUsage(path);
  List<FileEntry> searchFiles(String dir, String pattern) => _fileService.searchFiles(dir, pattern);
  List<FileEntry> findDuplicates(String dir) => _fileService.findDuplicates(dir);
  List<FileEntry> findEmptyFiles(String dir) => _fileService.findEmptyFiles(dir);
}

enum DrawerSection { storage, bookmarks, tools, settings }
'''

# ============================================================
# 5. lib/widgets/breadcrumb_bar.dart
# ============================================================
files['lib/widgets/breadcrumb_bar.dart'] = r'''import 'package:flutter/material.dart';
import '../services/file_service.dart';

class BreadcrumbBar extends StatelessWidget {
  final String currentPath;
  final Function(String) onNavigate;

  const BreadcrumbBar({super.key, required this.currentPath, required this.onNavigate});

  List<String> get _parts {
    if (currentPath == '/') return ['/'];
    final parts = currentPath.split('/').where((p) => p.isNotEmpty).toList();
    final result = <String>['/'];
    String accum = '';
    for (final p in parts) {
      accum += '/$p';
      result.add(accum);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parts;
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: parts.length,
        separatorBuilder: (_, __) => const Icon(Icons.chevron_right, size: 18),
        itemBuilder: (ctx, i) {
          final p = parts[i];
          final label = p == '/' ? '/' : FileService.getFileName(p);
          final isLast = i == parts.length - 1;
          return Center(
            child: InkWell(
              onTap: isLast ? null : () => onNavigate(p),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                    color: isLast ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
'''

# ============================================================
# 6. lib/widgets/file_list_tile.dart
# ============================================================
files['lib/widgets/file_list_tile.dart'] = r'''import 'package:flutter/material.dart';
import '../models/file_entry.dart';
import '../utils/file_icons.dart';

class FileListTile extends StatelessWidget {
  final FileEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenuAction;
  final String menuAction;

  const FileListTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onMenuAction,
    this.menuAction = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      leading: Stack(
        children: [
          Icon(FileIcons.iconForEntry(entry), color: FileIcons.colorForEntry(entry), size: 32),
          if (entry.isSymlink)
            Positioned(
              right: 0, bottom: 0,
              child: Icon(Icons.link, size: 12, color: theme.colorScheme.outline),
            ),
          if (!entry.isReadable)
            Positioned(
              right: 0, top: 0,
              child: Icon(Icons.lock, size: 12, color: theme.colorScheme.error),
            ),
        ],
      ),
      title: Text(
        entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: entry.isDirectory ? FontWeight.w600 : FontWeight.normal,
          color: entry.isHidden ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Text(
        '${entry.sizeFormatted}  ${entry.modifiedFormatted}  ${entry.permissionsFormatted}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (_) => onMenuAction(),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'open', child: Text('打开')),
          const PopupMenuItem(value: 'rename', child: Text('重命名')),
          const PopupMenuItem(value: 'copy', child: Text('复制')),
          const PopupMenuItem(value: 'move', child: Text('移动')),
          const PopupMenuItem(value: 'delete', child: Text('删除')),
          const PopupMenuItem(value: 'properties', child: Text('属性')),
          const PopupMenuItem(value: 'hash', child: Text('计算校验和')),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
'''

# ============================================================
# 7. lib/widgets/file_grid_tile.dart
# ============================================================
files['lib/widgets/file_grid_tile.dart'] = r'''import 'package:flutter/material.dart';
import '../models/file_entry.dart';
import '../utils/file_icons.dart';

class FileGridTile extends StatelessWidget {
  final FileEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FileGridTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: selected ? 4 : 1,
        color: selected ? theme.colorScheme.primaryContainer : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FileIcons.iconForEntry(entry), size: 48, color: FileIcons.colorForEntry(entry)),
              const SizedBox(height: 8),
              Text(
                entry.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              if (entry.isFile)
                Text(entry.sizeFormatted, style: TextStyle(fontSize: 10, color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
'''

# ============================================================
# 8. lib/utils/file_icons.dart
# ============================================================
files['lib/utils/file_icons.dart'] = r'''import 'package:flutter/material.dart';
import '../models/file_entry.dart';

class FileIcons {
  static IconData iconForEntry(FileEntry e) {
    if (e.isDirectory) return Icons.folder;
    final mime = e.mimeType;
    final ext = e.name.contains('.') ? e.name.split('.').last.toLowerCase() : '';

    if (mime.startsWith('image/') || ['jpg','jpeg','png','gif','bmp','svg','webp','ico','tiff','heic','avif'].contains(ext)) return Icons.image;
    if (mime.startsWith('video/') || ['mp4','avi','mkv','mov','wmv','flv','webm','m4v','3gp'].contains(ext)) return Icons.movie;
    if (mime.startsWith('audio/') || ['mp3','wav','flac','aac','ogg','wma','m4a','opus'].contains(ext)) return Icons.music_note;
    if (mime == 'application/pdf' || ext == 'pdf') return Icons.picture_as_pdf;
    if (mime.contains('zip') || mime.contains('tar') || mime.contains('archive') || mime.contains('compressed') ||
        ['zip','tar','gz','bz2','xz','7z','rar','zst','lz4','iso','deb','rpm'].contains(ext)) return Icons.archive;
    if (mime.startsWith('text/') || ['txt','md','json','xml','csv','log','ini','conf','yaml','yml','toml'].contains(ext)) return Icons.description;
    if (['c','cpp','h','hpp','java','py','rs','go','kt','swift','dart','sh','bat','ps1','js','ts','html','css'].contains(ext)) return Icons.code;
    if (['doc','docx','odt','rtf'].contains(ext)) return Icons.article;
    if (['xls','xlsx','ods'].contains(ext)) return Icons.table_chart;
    if (['ppt','pptx','odp'].contains(ext)) return Icons.slideshow;
    if (['db','sqlite','sql'].contains(ext)) return Icons.storage;
    if (['exe','so','dll','bin','apk','appimage'].contains(ext)) return Icons.apps;
    if (e.isSymlink) return Icons.link;
    return Icons.insert_drive_file;
  }

  static Color colorForEntry(FileEntry e) {
    if (e.isDirectory) return Colors.amber.shade700;
    final ext = e.name.contains('.') ? e.name.split('.').last.toLowerCase() : '';
    if (['jpg','jpeg','png','gif','bmp','svg','webp','ico','heic','avif'].contains(ext)) return Colors.green;
    if (['mp4','avi','mkv','mov','wmv','flv','webm'].contains(ext)) return Colors.purple;
    if (['mp3','wav','flac','aac','ogg','wma','m4a'].contains(ext)) return Colors.orange;
    if (ext == 'pdf') return Colors.red;
    if (['zip','tar','gz','bz2','xz','7z','rar','zst'].contains(ext)) return Colors.brown;
    if (['c','cpp','h','hpp','java','py','rs','go','kt','swift','dart','sh','js','ts','html','css'].contains(ext)) return Colors.teal;
    if (['txt','md','json','xml','csv','log','ini','conf','yaml'].contains(ext)) return Colors.blue;
    return Colors.grey.shade600;
  }
}
'''

# ============================================================
# 9. lib/widgets/properties_dialog.dart
# ============================================================
files['lib/widgets/properties_dialog.dart'] = r'''import 'package:flutter/material.dart';
import '../models/file_entry.dart';
import '../models/file_entry.dart' show FileHash;
import '../providers/file_manager_state.dart';
import '../utils/formatters.dart';

class PropertiesDialog extends StatelessWidget {
  final FileEntry entry;
  final FileManagerState state;

  const PropertiesDialog({super.key, required this.entry, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            entry.isDirectory ? Icons.folder : Icons.insert_drive_file,
            color: entry.isDirectory ? Colors.amber : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(entry.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _section('基本信息', [
                _row('路径', entry.path),
                _row('类型', entry.isDirectory ? '目录' : entry.isSymlink ? '符号链接' : entry.mimeType.isNotEmpty ? entry.mimeType : '文件'),
                _row('大小', entry.sizeFormatted),
                _row('修改时间', entry.modifiedFormatted),
                if (entry.createdTime > 0) _row('创建时间', Formatters.formatDate(entry.createdTime)),
                if (entry.accessTime > 0) _row('访问时间', Formatters.formatDate(entry.accessTime)),
              ]),
              _section('权限', [
                _row('权限', '${entry.permissionsFormatted} (${entry.octalPermissions})'),
                _row('所有者', '${entry.ownerName} (${entry.uid})'),
                _row('组', '${entry.groupName} (${entry.gid})'),
                _row('可读', entry.isReadable ? '是' : '否'),
                _row('可写', entry.isWritable ? '是' : '否'),
                _row('可执行', entry.isExecutable ? '是' : '否'),
              ]),
              if (entry.isSymlink)
                _section('符号链接', [
                  _row('目标', entry.symlinkTarget),
                ]),
              if (entry.isFile) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('校验和', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                ),
                FutureBuilder<FileHash?>(
                  future: Future(() => state.computeHash(entry.path)),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!snap.hasData || snap.data == null) {
                      return const Text('计算失败');
                    }
                    final h = snap.data!;
                    return Column(
                      children: [
                        _row('MD5', h.md5),
                        _row('SHA1', h.sha1),
                        _row('SHA256', h.sha256),
                        _row('SHA512', h.sha512),
                        _row('CRC32', h.crc32),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
'''

# ============================================================
# 10. lib/screens/file_manager_page.dart (main page)
# ============================================================
files['lib/screens/file_manager_page.dart'] = r'''import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_entry.dart';
import '../providers/file_manager_state.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/file_list_tile.dart';
import '../widgets/file_grid_tile.dart';
import '../widgets/properties_dialog.dart';
import 'search_page.dart';
import 'storage_analysis_page.dart';
import 'tools_page.dart';
import 'settings_page.dart';
import 'about_page.dart';

class FileManagerPage extends StatelessWidget {
  const FileManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FileManagerState(),
      child: const _FileManagerView(),
    );
  }
}

class _FileManagerView extends StatelessWidget {
  const _FileManagerView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FileManagerState>();
    final tab = state.currentTab;
    final entries = state.filteredEntries;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(context, state),
      drawer: _buildDrawer(context, state),
      body: Column(
        children: [
          // Tab bar
          if (state.tabs.length > 1 || true)
            _buildTabBar(context, state),
          // Breadcrumb
          BreadcrumbBar(currentPath: tab.currentPath, onNavigate: state.navigateTo),
          const Divider(height: 1),
          // Content
          Expanded(child: _buildContent(context, state, entries)),
          // Status bar
          _buildStatusBar(context, state, entries),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, state),
        child: const Icon(Icons.add),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, FileManagerState state) {
    final tab = state.currentTab;
    return AppBar(
      title: tab.isSearching
          ? TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: '搜索文件...', border: InputBorder.none),
              onChanged: state.setSearchQuery,
            )
          : Text(FileService.getFileName(tab.currentPath)),
      leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
      actions: [
        if (tab.selectedPaths.isNotEmpty) ...[
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${tab.selectedPaths.length} 已选', style: const TextStyle(fontSize: 14)),
          )),
          IconButton(icon: const Icon(Icons.select_all), onPressed: state.selectAll, tooltip: '全选'),
          IconButton(icon: const Icon(Icons.deselect), onPressed: state.clearSelection, tooltip: '取消选择'),
          IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteSelected(context, state), tooltip: '删除'),
        ] else ...[
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: state.goBack),
          IconButton(icon: const Icon(Icons.arrow_forward), onPressed: state.goForward),
          IconButton(icon: const Icon(Icons.arrow_upward), onPressed: state.goUp),
          IconButton(
            icon: Icon(tab.isSearching ? Icons.close : Icons.search),
            onPressed: () {
              if (tab.isSearching) state.toggleSearch();
              else Navigator.push(context, MaterialPageRoute(builder: (_) => SearchPage(state: state)));
            },
          ),
          IconButton(
            icon: Icon(tab.showHidden ? Icons.visibility : Icons.visibility_off),
            tooltip: tab.showHidden ? '隐藏隐藏文件' : '显示隐藏文件',
            onPressed: state.toggleHidden,
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _handleMenu(context, state, v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: 'sort_name', checked: tab.sortMode == SortMode.name, child: const Text('按名称排序')),
              CheckedPopupMenuItem(value: 'sort_size', checked: tab.sortMode == SortMode.size, child: const Text('按大小排序')),
              CheckedPopupMenuItem(value: 'sort_modified', checked: tab.sortMode == SortMode.modified, child: const Text('按修改时间排序')),
              CheckedPopupMenuItem(value: 'sort_type', checked: tab.sortMode == SortMode.type, child: const Text('按类型排序')),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(value: 'view_list', checked: tab.viewMode == ViewMode.list, child: const Text('列表视图')),
              CheckedPopupMenuItem(value: 'view_grid', checked: tab.viewMode == ViewMode.grid, child: const Text('网格视图')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'select_all', child: Text('全选')),
              const PopupMenuItem(value: 'new_tab', child: Text('新标签页')),
              const PopupMenuItem(value: 'bookmark', child: Text('添加书签')),
              const PopupMenuItem(value: 'refresh', child: Text('刷新')),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, FileManagerState state) {
    final theme = Theme.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.folder_special, size: 48, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(height: 8),
                Text('Advance File Manager', style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 18, fontWeight: FontWeight.bold,
                )),
                Text('Flutter + C++ 版本', style: TextStyle(color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7))),
              ],
            ),
          ),
          // Storage
          _drawerItem(context, state, Icons.storage, '存储', DrawerSection.storage, () {
            state.setDrawerSection(DrawerSection.storage);
            Navigator.pop(context);
          }),
          FutureBuilder<DiskUsage?>(
            future: Future(() => state.getDiskUsage('/')),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data == null) return const SizedBox();
              final d = snap.data!;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: d.percent / 100, backgroundColor: theme.colorScheme.surfaceContainerHighest),
                    const SizedBox(height: 4),
                    Text('${d.usedFormatted} / ${d.totalFormatted} (${d.percent.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          // Quick access
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('快速访问', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          ),
          _quickAccessItem(context, state, Icons.home, '主目录', state.fileService.getHomeDirectory()),
          _quickAccessItem(context, state, Icons.folder, '根目录', '/'),
          _quickAccessItem(context, state, Icons.person, '用户目录', '${state.fileService.getHomeDirectory()}'),
          const Divider(),
          // Bookmarks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('书签', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          ),
          if (state.bookmarks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('暂无书签', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ...state.bookmarks.asMap().entries.map((e) => ListTile(
            leading: const Icon(Icons.bookmark, size: 20),
            title: Text(e.value.name, style: const TextStyle(fontSize: 14)),
            dense: true,
            onTap: () { state.navigateTo(e.value.path); Navigator.pop(context); },
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => state.removeBookmark(e.key),
            ),
          )),
          const Divider(),
          // Tools
          _drawerItem(context, state, Icons.build, '文件工具', DrawerSection.tools, () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => ToolsPage(state: state)));
          }),
          _drawerItem(context, state, Icons.pie_chart, '存储分析', DrawerSection.storage, () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => StorageAnalysisPage(state: state)));
          }),
          _drawerItem(context, state, Icons.settings, '设置', DrawerSection.settings, () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
          }),
          _drawerItem(context, state, Icons.info, '关于', DrawerSection.settings, () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()));
          }),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext ctx, FileManagerState state, IconData icon, String title,
      DrawerSection section, VoidCallback onTap) {
    final theme = Theme.of(ctx);
    final selected = state.drawerSection == section;
    return ListTile(
      leading: Icon(icon, color: selected ? theme.colorScheme.primary : null),
      title: Text(title, style: TextStyle(
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? theme.colorScheme.primary : null,
      )),
      selected: selected,
      onTap: onTap,
    );
  }

  Widget _quickAccessItem(BuildContext ctx, FileManagerState state, IconData icon, String title, String path) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      dense: true,
      onTap: () { state.navigateTo(path); Navigator.pop(ctx); },
    );
  }

  Widget _buildTabBar(BuildContext context, FileManagerState state) {
    return Container(
      height: 36,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.tabs.length,
              itemBuilder: (ctx, i) {
                final t = state.tabs[i];
                final isCurrent = i == state.currentTabIndex;
                return InkWell(
                  onTap: () => state.switchTab(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isCurrent ? Theme.of(context).colorScheme.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          FileService.getFileName(t.currentPath),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (state.tabs.length > 1)
                          GestureDetector(
                            onTap: () => state.closeTab(i),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.close, size: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => state.addTab(state.currentTab.currentPath),
            tooltip: '新标签页',
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, FileManagerState state, List<FileEntry> entries) {
    final tab = state.currentTab;
    if (tab.loading) return const Center(child: CircularProgressIndicator());
    if (tab.error != null) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text(tab.error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        FilledButton(onPressed: state.loadCurrentTab, child: const Text('重试')),
      ],
    ));
    if (entries.isEmpty) return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tab.isSearching ? Icons.search_off : Icons.folder_open, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(tab.isSearching ? '无搜索结果' : '此目录为空', style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );

    if (tab.viewMode == ViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, childAspectRatio: 0.8),
        itemCount: entries.length,
        itemBuilder: (ctx, i) {
          final e = entries[i];
          return FileGridTile(
            entry: e,
            selected: tab.selectedPaths.contains(e.path),
            onTap: () => _handleTap(context, state, e),
            onLongPress: () => state.toggleSelection(e.path),
          );
        },
      );
    }

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final e = entries[i];
        return FileListTile(
          entry: e,
          selected: tab.selectedPaths.contains(e.path),
          onTap: () => _handleTap(context, state, e),
          onLongPress: () => state.toggleSelection(e.path),
          onMenuAction: () => _showEntryMenu(context, state, e),
        );
      },
    );
  }

  Widget _buildStatusBar(BuildContext context, FileManagerState state, List<FileEntry> entries) {
    final theme = Theme.of(context);
    final dirs = entries.where((e) => e.isDirectory).length;
    final files = entries.where((e) => !e.isDirectory).length;
    final totalSize = entries.where((e) => e.isFile).fold<int>(0, (sum, e) => sum + e.size);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text('$dirs 个目录, $files 个文件', style: const TextStyle(fontSize: 12)),
          if (totalSize > 0)
            Text('  (${Formatters.formatSize(totalSize)})', style: const TextStyle(fontSize: 12)),
          if (state.currentTab.selectedPaths.isNotEmpty)
            Text('  |  ${state.currentTab.selectedPaths.length} 已选', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
          const Spacer(),
          FutureBuilder<DiskUsage?>(
            future: Future(() => state.getDiskUsage(state.currentTab.currentPath)),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data == null) return const SizedBox();
              final d = snap.data!;
              return Text(
                '可用 ${d.freeFormatted} / ${d.totalFormatted}',
                style: const TextStyle(fontSize: 12),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, FileManagerState state, FileEntry entry) {
    if (state.currentTab.selectedPaths.isNotEmpty) {
      state.toggleSelection(entry.path);
    } else if (entry.isDirectory) {
      state.navigateTo(entry.path);
    }
  }

  void _handleMenu(BuildContext context, FileManagerState state, String action) {
    switch (action) {
      case 'sort_name': state.setSortMode(SortMode.name); break;
      case 'sort_size': state.setSortMode(SortMode.size); break;
      case 'sort_modified': state.setSortMode(SortMode.modified); break;
      case 'sort_type': state.setSortMode(SortMode.type); break;
      case 'view_list': state.setViewMode(ViewMode.list); break;
      case 'view_grid': state.setViewMode(ViewMode.grid); break;
      case 'select_all': state.selectAll(); break;
      case 'new_tab': state.addTab(state.currentTab.currentPath); break;
      case 'bookmark':
        state.addBookmark(FileService.getFileName(state.currentTab.currentPath), state.currentTab.currentPath);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已添加书签')));
        break;
      case 'refresh': state.loadCurrentTab(); break;
    }
  }

  void _showEntryMenu(BuildContext context, FileManagerState state, FileEntry entry) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('属性'),
              onTap: () { Navigator.pop(ctx); _showProperties(context, state, entry); },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () { Navigator.pop(ctx); _showRenameDialog(context, state, entry); },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制路径'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('路径: ${entry.path}')));
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () { Navigator.pop(ctx); _confirmDelete(context, state, [entry]); },
            ),
          ],
        ),
      ),
    );
  }

  void _showProperties(BuildContext context, FileManagerState state, FileEntry entry) {
    showDialog(context: context, builder: (_) => PropertiesDialog(entry: entry, state: state));
  }

  void _showRenameDialog(BuildContext context, FileManagerState state, FileEntry entry) {
    final controller = TextEditingController(text: entry.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == entry.name) { Navigator.pop(ctx); return; }
              final newPath = FileService.joinPath(FileService.getParentPath(entry.path), newName);
              final err = state.rename(entry.path, newPath);
              Navigator.pop(ctx);
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              }
              state.loadCurrentTab();
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, FileManagerState state) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('新建'),
        children: [
          SimpleDialogOption(
            child: const ListTile(leading: Icon(Icons.folder), title: Text('新建文件夹'), dense: true),
            onPressed: () { Navigator.pop(ctx); _createItem(context, state, true); },
          ),
          SimpleDialogOption(
            child: const ListTile(leading: Icon(Icons.insert_drive_file), title: Text('新建文件'), dense: true),
            onPressed: () { Navigator.pop(ctx); _createItem(context, state, false); },
          ),
        ],
      ),
    );
  }

  void _createItem(BuildContext context, FileManagerState state, bool isDir) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDir ? '新建文件夹' : '新建文件'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: isDir ? '文件夹名' : '文件名', border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final fullPath = FileService.joinPath(state.currentTab.currentPath, name);
              final err = isDir ? state.createDirectory(fullPath) : state.createFile(fullPath);
              Navigator.pop(ctx);
              if (err != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              state.loadCurrentTab();
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, FileManagerState state, List<FileEntry> entries) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${entries.length} 个项目吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              for (final e in entries) {
                final err = state.deleteFile(e.path);
                if (err != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.name}: $err')));
                }
              }
              state.clearSelection();
              state.loadCurrentTab();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _deleteSelected(BuildContext context, FileManagerState state) {
    final selected = state.currentTab.entries.where((e) => state.currentTab.selectedPaths.contains(e.path)).toList();
    _confirmDelete(context, state, selected);
  }
}
'''

# ============================================================
# 11. lib/screens/search_page.dart
# ============================================================
files['lib/screens/search_page.dart'] = r'''import 'package:flutter/material.dart';
import '../models/file_entry.dart';
import '../providers/file_manager_state.dart';

class SearchPage extends StatefulWidget {
  final FileManagerState state;
  const SearchPage({super.key, required this.state});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _patternController = TextEditingController(text: '*');
  final _dirController = TextEditingController();
  List<FileEntry> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _dirController.text = widget.state.currentTab.currentPath;
  }

  void _doSearch() {
    setState(() => _searching = true);
    try {
      final results = widget.state.searchFiles(_dirController.text, _patternController.text);
      setState(() { _results = results; _searching = false; });
    } catch (e) {
      setState(() { _results = []; _searching = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _patternController,
                  decoration: const InputDecoration(
                    labelText: '搜索模式 (glob, 如 *.txt)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pattern),
                  ),
                  onSubmitted: (_) => _doSearch(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dirController,
                  decoration: const InputDecoration(
                    labelText: '搜索目录',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder),
                  ),
                  onSubmitted: (_) => _doSearch(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _doSearch,
                    icon: _searching
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label: const Text('搜索'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _results.isEmpty
                ? Center(child: Text(_searching ? '搜索中...' : '输入搜索模式并点击搜索', style: const TextStyle(color: Colors.grey)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('找到 ${_results.length} 个结果', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final e = _results[i];
                            return ListTile(
                              leading: Icon(e.isDirectory ? Icons.folder : Icons.insert_drive_file, size: 28),
                              title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(e.path, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                              trailing: Text(e.sizeFormatted, style: const TextStyle(fontSize: 12)),
                              onTap: () {
                                if (e.isDirectory) {
                                  Navigator.pop(context);
                                  widget.state.navigateTo(e.path);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
'''

# ============================================================
# 12. lib/screens/storage_analysis_page.dart
# ============================================================
files['lib/screens/storage_analysis_page.dart'] = r'''import 'package:flutter/material.dart';
import '../providers/file_manager_state.dart';
import '../models/file_entry.dart';
import '../utils/formatters.dart';

class StorageAnalysisPage extends StatefulWidget {
  final FileManagerState state;
  const StorageAnalysisPage({super.key, required this.state});

  @override
  State<StorageAnalysisPage> createState() => _StorageAnalysisPageState();
}

class _StorageAnalysisPageState extends State<StorageAnalysisPage> {
  DiskUsage? _diskUsage;
  List<_TypeStat> _stats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  void _analyze() {
    setState(() => _loading = true);
    try {
      final du = widget.state.getDiskUsage('/');
      final entries = widget.state.fileService.listDirectory(widget.state.currentTab.currentPath, showHidden: true);
      final Map<String, _TypeStat> statMap = {};
      for (final e in entries) {
        if (!e.isDirectory) {
          final ext = e.name.contains('.') ? '.${e.name.split('.').last.toLowerCase()}' : '(无扩展名)';
          statMap.putIfAbsent(ext, () => _TypeStat(ext, 0, 0));
          statMap[ext]!.count++;
          statMap[ext]!.totalSize += e.size;
        }
      }
      final sorted = statMap.values.toList()..sort((a, b) => b.totalSize.compareTo(a.totalSize));
      setState(() { _diskUsage = du; _stats = sorted; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('存储分析')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_diskUsage != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 120,
                            width: 120,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: _diskUsage!.percent / 100,
                                  strokeWidth: 12,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                ),
                                Center(child: Text('${_diskUsage!.percent.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _statCol('总空间', _diskUsage!.totalFormatted, theme.colorScheme.primary),
                              _statCol('已使用', _diskUsage!.usedFormatted, theme.colorScheme.error),
                              _statCol('可用', _diskUsage!.freeFormatted, theme.colorScheme.tertiary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_stats.isNotEmpty) ...[
                  Text('按类型统计', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._stats.take(20).map((s) => Card(
                    child: ListTile(
                      title: Text(s.ext),
                      subtitle: Text('${s.count} 个文件'),
                      trailing: Text(Formatters.formatSize(s.totalSize), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )),
                ],
              ],
            ),
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _TypeStat {
  final String ext;
  int count;
  int totalSize;
  _TypeStat(this.ext, this.count, this.totalSize);
}
'''

# ============================================================
# 13. lib/screens/tools_page.dart
# ============================================================
files['lib/screens/tools_page.dart'] = r'''import 'package:flutter/material.dart';
import '../providers/file_manager_state.dart';
import '../models/file_entry.dart';

class ToolsPage extends StatelessWidget {
  final FileManagerState state;
  const ToolsPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件工具')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _toolCard(context, Icons.search, '文件搜索', '按名称模式搜索文件', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _SearchTool(state: state)));
          }),
          _toolCard(context, Icons.content_copy, '重复文件查找', '查找相同内容的重复文件', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _DuplicatesTool(state: state)));
          }),
          _toolCard(context, Icons.delete_sweep, '空文件查找', '查找空文件和空目录', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _EmptyFilesTool(state: state)));
          }),
          _toolCard(context, Icons.fingerprint, '文件校验和', '计算文件的哈希值', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _HashTool(state: state)));
          }),
          _toolCard(context, Icons.compare, '文件对比', '逐字节比较两个文件', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => _CompareTool(state: state)));
          }),
        ],
      ),
    );
  }

  Widget _toolCard(BuildContext ctx, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SearchTool extends StatefulWidget {
  final FileManagerState state;
  const _SearchTool({required this.state});
  @override
  State<_SearchTool> createState() => _SearchToolState();
}

class _SearchToolState extends State<_SearchTool> {
  final _dirCtrl = TextEditingController();
  final _patternCtrl = TextEditingController(text: '*');
  List<FileEntry> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _dirCtrl.text = widget.state.currentTab.currentPath;
  }

  void _search() {
    setState(() => _searching = true);
    try {
      final r = widget.state.searchFiles(_dirCtrl.text, _patternCtrl.text);
      setState(() { _results = r; _searching = false; });
    } catch (e) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(controller: _patternCtrl, decoration: const InputDecoration(labelText: '搜索模式 (glob)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _dirCtrl, decoration: const InputDecoration(labelText: '搜索目录', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _searching ? null : _search, icon: const Icon(Icons.search), label: const Text('搜索'))),
            ]),
          ),
          Expanded(child: _results.isEmpty
              ? const Center(child: Text('无结果'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (ctx, i) {
                    final e = _results[i];
                    return ListTile(
                      leading: Icon(e.isDirectory ? Icons.folder : Icons.insert_drive_file),
                      title: Text(e.name),
                      subtitle: Text(e.path, style: const TextStyle(fontSize: 11)),
                      trailing: Text(e.sizeFormatted),
                    );
                  },
                )),
        ],
      ),
    );
  }
}

class _DuplicatesTool extends StatefulWidget {
  final FileManagerState state;
  const _DuplicatesTool({required this.state});
  @override
  State<_DuplicatesTool> createState() => _DuplicatesToolState();
}

class _DuplicatesToolState extends State<_DuplicatesTool> {
  List<FileEntry> _results = [];
  bool _searching = false;

  void _find() {
    setState(() => _searching = true);
    try {
      final r = widget.state.findDuplicates(widget.state.currentTab.currentPath);
      setState(() { _results = r; _searching = false; });
    } catch (e) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('重复文件查找')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _searching ? null : _find,
              icon: _searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.content_copy),
              label: const Text('查找重复文件'),
            ),
          ),
        ),
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('找到 ${_results.length} 个重复文件', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        Expanded(child: _results.isEmpty
            ? Center(child: Text(_searching ? '扫描中...' : '点击按钮开始查找', style: const TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final e = _results[i];
                  return ListTile(
                    leading: Icon(Icons.copy, color: Theme.of(context).colorScheme.error),
                    title: Text(e.name),
                    subtitle: Text(e.path, style: const TextStyle(fontSize: 11)),
                    trailing: Text(e.sizeFormatted),
                  );
                },
              )),
      ]),
    );
  }
}

class _EmptyFilesTool extends StatefulWidget {
  final FileManagerState state;
  const _EmptyFilesTool({required this.state});
  @override
  State<_EmptyFilesTool> createState() => _EmptyFilesToolState();
}

class _EmptyFilesToolState extends State<_EmptyFilesTool> {
  List<FileEntry> _results = [];
  bool _searching = false;

  void _find() {
    setState(() => _searching = true);
    try {
      final r = widget.state.findEmptyFiles(widget.state.currentTab.currentPath);
      setState(() { _results = r; _searching = false; });
    } catch (e) {
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('空文件查找')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _searching ? null : _find,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('查找空文件'),
            ),
          ),
        ),
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('找到 ${_results.length} 个空文件/目录', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        Expanded(child: _results.isEmpty
            ? Center(child: Text(_searching ? '扫描中...' : '点击按钮开始查找', style: const TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final e = _results[i];
                  return ListTile(
                    leading: Icon(e.isDirectory ? Icons.folder_open : Icons.insert_drive_file, color: Colors.orange),
                    title: Text(e.name),
                    subtitle: Text(e.path, style: const TextStyle(fontSize: 11)),
                  );
                },
              )),
      ]),
    );
  }
}

class _HashTool extends StatefulWidget {
  final FileManagerState state;
  const _HashTool({required this.state});
  @override
  State<_HashTool> createState() => _HashToolState();
}

class _HashToolState extends State<_HashTool> {
  final _pathCtrl = TextEditingController();
  FileHash? _hash;
  bool _computing = false;

  void _compute() {
    setState(() => _computing = true);
    try {
      final h = widget.state.computeHash(_pathCtrl.text);
      setState(() { _hash = h; _computing = false; });
    } catch (e) {
      setState(() => _computing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件校验和')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _pathCtrl, decoration: const InputDecoration(labelText: '文件路径', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _computing ? null : _compute,
            icon: const Icon(Icons.fingerprint),
            label: const Text('计算校验和'),
          )),
          const SizedBox(height: 16),
          if (_hash != null)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hashRow('MD5', _hash!.md5),
                _hashRow('SHA1', _hash!.sha1),
                _hashRow('SHA256', _hash!.sha256),
                _hashRow('SHA512', _hash!.sha512),
                _hashRow('CRC32', _hash!.crc32),
              ],
            ))),
        ]),
      ),
    );
  }

  Widget _hashRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
        ],
      ),
    );
  }
}

class _CompareTool extends StatefulWidget {
  final FileManagerState state;
  const _CompareTool({required this.state});
  @override
  State<_CompareTool> createState() => _CompareToolState();
}

class _CompareToolState extends State<_CompareTool> {
  final _path1Ctrl = TextEditingController();
  final _path2Ctrl = TextEditingController();
  String? _result;

  void _compare() {
    final h1 = widget.state.computeHash(_path1Ctrl.text);
    final h2 = widget.state.computeHash(_path2Ctrl.text);
    if (h1 == null || h2 == null) {
      setState(() => _result = '无法读取文件');
      return;
    }
    final match = h1.md5 == h2.md5;
    setState(() => _result = match ? '文件相同 (MD5 匹配)' : '文件不同');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('文件对比')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: _path1Ctrl, decoration: const InputDecoration(labelText: '文件 1 路径', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: _path2Ctrl, decoration: const InputDecoration(labelText: '文件 2 路径', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _compare, icon: const Icon(Icons.compare), label: const Text('对比'))),
          const SizedBox(height: 16),
          if (_result != null)
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(_result!.contains('相同') ? Icons.check_circle : Icons.cancel,
                    color: _result!.contains('相同') ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(_result!, style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            )),
        ]),
      ),
    );
  }
}
'''

# ============================================================
# 14. lib/screens/settings_page.dart
# ============================================================
files['lib/screens/settings_page.dart'] = r'''import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _section('通用设置', [
            _item(Icons.language, '语言', '跟随系统', () {}),
            _item(Icons.folder, '默认目录', '主目录', () {}),
            _item(Icons.sort, '排序方式', '按名称', () {}),
            _item(Icons.text_fields, '文件名显示', '完整显示', () {}),
            _item(Icons.hidden, '显示隐藏文件', '否', () {}),
          ]),
          _section('显示设置', [
            _item(Icons.format_size, '字体大小', '100%', () {}),
            _item(Icons.space_bar, '界面间距', '默认', () {}),
            _item(Icons.height, '列表项高度', '默认', () {}),
            _item(Icons.image, '图标大小', '默认', () {}),
          ]),
          _section('功能设置', [
            _item(Icons.build, '文件工具', '已启用', () {}),
            _item(Icons.movie, '媒体工具', '已启用', () {}),
            _item(Icons.delete, '回收站', '已启用', () {}),
          ]),
          _section('关于', [
            _item(Icons.info, '版本', '1.0.0', () {}),
            _item(Icons.code, '源代码', 'GPL-3.0', () {}),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _item(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}
'''

# ============================================================
# 15. lib/screens/about_page.dart
# ============================================================
files['lib/screens/about_page.dart'] = r'''import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: Icon(Icons.folder_special, size: 80, color: theme.colorScheme.primary)),
          const SizedBox(height: 16),
          Center(child: Text('Advance File Manager', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
          const SizedBox(height: 4),
          Center(child: Text('Flutter + C++ 版本', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
          const SizedBox(height: 4),
          Center(child: Text('版本 1.0.0', style: theme.textTheme.bodySmall)),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('项目信息', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(),
                  _infoRow('架构', 'Flutter (Dart) + C++ (FFI)'),
                  _infoRow('平台', 'Linux Desktop'),
                  _infoRow('UI 框架', 'Material Design 3'),
                  _infoRow('原生库', 'libfile_ops.so (POSIX API)'),
                  _infoRow('哈希算法', 'OpenSSL (MD5/SHA/SHA256/SHA512)'),
                  _infoRow('校验', 'zlib (CRC32)'),
                  _infoRow('文件遍历', 'std::filesystem + POSIX'),
                  _infoRow('许可证', 'GPL-3.0'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('功能特性', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(),
                  _feature('文件浏览 (列表/网格视图)'),
                  _feature('面包屑导航 + 标签页'),
                  _feature('文件操作 (新建/删除/重命名/复制/移动)'),
                  _feature('文件搜索 (glob 模式)'),
                  _feature('文件属性 (权限/所有者/类型)'),
                  _feature('校验和计算 (MD5/SHA1/SHA256/SHA512/CRC32)'),
                  _feature('重复文件查找'),
                  _feature('空文件/空目录查找'),
                  _feature('存储分析'),
                  _feature('符号链接检测'),
                  _feature('隐藏文件管理'),
                  _feature('排序 (名称/大小/时间/类型)'),
                  _feature('多选操作'),
                  _feature('书签管理'),
                  _feature('MIME 类型识别'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text('Copyright (C) 2026 advancefilemanager', style: theme.textTheme.bodySmall)),
          Center(child: Text('Licensed under GPL-3.0', style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _feature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
'''

# ============================================================
# 16. lib/main.dart
# ============================================================
files['lib/main.dart'] = r'''import 'package:flutter/material.dart';
import 'screens/file_manager_page.dart';

void main() {
  runApp(const AdvanceFileManagerApp());
}

class AdvanceFileManagerApp extends StatelessWidget {
  const AdvanceFileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advance File Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const FileManagerPage(),
    );
  }
}
'''

# Write all files
for relpath, content in files.items():
    fullpath = os.path.join(BASE, relpath)
    os.makedirs(os.path.dirname(fullpath), exist_ok=True)
    with open(fullpath, 'w') as f:
        f.write(content)
    print(f'Wrote {relpath} ({len(content)} bytes)')

print(f'\nTotal: {len(files)} files written.')
