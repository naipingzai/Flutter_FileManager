import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/models/bookmark.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';

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
  bool directoriesFirst;
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
    this.directoriesFirst = true,
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
    tabs.add(TabState(id: '0', currentPath: '/'));
  }

  Future<void> initialize() async {
    try {
      final home = await _fileService.getHomeDirectory();
      tabs[0] = TabState(id: '0', currentPath: home);
    } catch (_) {}
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
      final entries = _fileService.listDirectory(
        tab.currentPath,
        showHidden: tab.showHidden,
      );
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
          if (cmp == 0)
            cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
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

  void toggleHidden() {
    currentTab.showHidden = !currentTab.showHidden;
    loadCurrentTab();
  }

  void toggleDirectoriesFirst() {
    final tab = currentTab;
    tab.directoriesFirst = !tab.directoriesFirst;
    _sortEntries(tab.entries, tab.sortMode, tab.sortAscending);
    notifyListeners();
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
      return tab.entries
          .where(
            (e) => e.name.toLowerCase().contains(tab.searchQuery.toLowerCase()),
          )
          .toList();
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
  String? rename(String oldPath, String newPath) =>
      _fileService.rename(oldPath, newPath);
  String? copyFile(String src, String dst) => _fileService.copyFile(src, dst);
  String? moveFile(String src, String dst) => _fileService.moveFile(src, dst);
  bool exists(String path) => _fileService.exists(path);
  FileEntry? getFileInfo(String path) => _fileService.getFileInfo(path);
  FileHash? computeHash(String path) => _fileService.computeHash(path);
  DiskUsage? getDiskUsage(String path) => _fileService.getDiskUsage(path);
  List<FileEntry> searchFiles(String dir, String pattern) =>
      _fileService.searchFiles(dir, pattern);
  List<DuplicateGroup> findDuplicates(String dir) =>
      _fileService.findDuplicates(dir);
  List<FileEntry> findEmptyFiles(String dir) =>
      _fileService.findEmptyFiles(dir);
}

enum DrawerSection { storage, bookmarks, tools, settings }
