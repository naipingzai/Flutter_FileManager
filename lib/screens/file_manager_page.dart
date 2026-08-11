import 'dart:io';
import 'package:flutter_file_manager/screens/viewer/audio_player_page.dart';
import 'package:flutter_file_manager/screens/viewer/csv_viewer_page.dart';
import 'package:flutter_file_manager/screens/viewer/ebook_viewer_page.dart';
import 'package:flutter_file_manager/screens/viewer/image_viewer_page.dart';
import 'package:flutter_file_manager/screens/viewer/pdf_viewer_page.dart';
import 'package:flutter_file_manager/screens/viewer/text_editor_page.dart';
import 'package:flutter_file_manager/screens/viewer/video_player_page.dart';

import '../services/file_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_manager_state.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/file_list_tile.dart';
import '../widgets/file_grid_tile.dart';
import '../widgets/properties_dialog.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import '../utils/formatters.dart';

class FileManagerPage extends StatefulWidget {
  const FileManagerPage({super.key});

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  late final FileManagerState _state;

  @override
  void initState() {
    super.initState();
    _state = FileManagerState();
    _state.initialize();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
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
          if (state.tabs.length > 1 || true) _buildTabBar(context, state),
          // Breadcrumb
          BreadcrumbBar(
            currentPath: tab.currentPath,
            onNavigate: state.navigateTo,
          ),
          const Divider(height: 1),
          // Content
          Expanded(child: _buildContent(context, state, entries)),
          // Status bar
          _buildStatusBar(context, state, entries),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    FileManagerState state,
  ) {
    final tab = state.currentTab;
    return AppBar(
      title: tab.isSearching
          ? TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索文件...',
                border: InputBorder.none,
              ),
              onChanged: state.setSearchQuery,
            )
          : Text(FileService.getFileName(tab.currentPath)),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      actions: [
        if (tab.selectedPaths.isNotEmpty) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${tab.selectedPaths.length} 已选',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: state.selectAll,
            tooltip: '全选',
          ),
          IconButton(
            icon: const Icon(Icons.deselect),
            onPressed: state.clearSelection,
            tooltip: '取消选择',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteSelected(context, state),
            tooltip: '删除',
          ),
        ] else ...[
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: state.goBack,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: state.goForward,
          ),
          IconButton(
            icon: Icon(tab.isSearching ? Icons.close : Icons.search),
            onPressed: () {
              if (tab.isSearching)
                state.toggleSearch();
              else
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SearchPage(state: state)),
                );
            },
          ),
          IconButton(
            icon: Icon(
              tab.showHidden ? Icons.visibility : Icons.visibility_off,
            ),
            tooltip: tab.showHidden ? '隐藏隐藏文件' : '显示隐藏文件',
            onPressed: state.toggleHidden,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (v) => _handleMenu(context, state, v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'sort_name',
                checked: tab.sortMode == SortMode.name,
                child: const Text('按名称排序'),
              ),
              CheckedPopupMenuItem(
                value: 'sort_size',
                checked: tab.sortMode == SortMode.size,
                child: const Text('按大小排序'),
              ),
              CheckedPopupMenuItem(
                value: 'sort_modified',
                checked: tab.sortMode == SortMode.modified,
                child: const Text('按修改时间排序'),
              ),
              CheckedPopupMenuItem(
                value: 'sort_type',
                checked: tab.sortMode == SortMode.type,
                child: const Text('按类型排序'),
              ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                value: 'view_list',
                checked: tab.viewMode == ViewMode.list,
                child: const Text('列表视图'),
              ),
              CheckedPopupMenuItem(
                value: 'view_grid',
                checked: tab.viewMode == ViewMode.grid,
                child: const Text('网格视图'),
              ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _handleMenu(context, state, v),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'new_folder',
                child: Row(children: [SizedBox(width: 12), Text('新建文件夹')]),
              ),
              const PopupMenuItem(
                value: 'new_file',
                child: Row(children: [SizedBox(width: 12), Text('新建文件')]),
              ),
              const PopupMenuItem(
                value: 'select_all',
                child: Row(children: [SizedBox(width: 12), Text('全选')]),
              ),
              const PopupMenuItem(
                value: 'new_tab',
                child: Row(children: [SizedBox(width: 12), Text('新标签页')]),
              ),
              const PopupMenuItem(
                value: 'bookmark',
                child: Row(children: [SizedBox(width: 12), Text('添加书签')]),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(children: [SizedBox(width: 12), Text('刷新')]),
              ),
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
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.folder_special,
                  size: 48,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 8),
                Text(
                  'Flutter File Manager',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Flutter + C++ 版本',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Storage
          _drawerItem(
            context,
            state,
            Icons.storage,
            '存储',
            DrawerSection.storage,
            () {
              state.setDrawerSection(DrawerSection.storage);
              Navigator.pop(context);
            },
          ),
          FutureBuilder<DiskUsage?>(
            future: Future(() => state.getDiskUsage('/')),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data == null) return const SizedBox();
              final d = snap.data!;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: d.percent / 100,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${d.usedFormatted} / ${d.totalFormatted} (${d.percent.toStringAsFixed(1)}%)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          // Quick access
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '快速访问',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          _quickAccessItem(
            context,
            state,
            Icons.home,
            '主目录',
            _platformHomeDir(),
          ),
          _quickAccessItem(
            context,
            state,
            Icons.folder,
            '根目录',
            _platformRootDir(),
          ),
          if (_platformIsLinux()) ...[
            _quickAccessItem(
              context,
              state,
              Icons.download,
              '下载',
              '${_platformHomeDir()}/Downloads',
            ),
            _quickAccessItem(
              context,
              state,
              Icons.description,
              '文档',
              '${_platformHomeDir()}/Documents',
            ),
            _quickAccessItem(
              context,
              state,
              Icons.image,
              '图片',
              '${_platformHomeDir()}/Pictures',
            ),
            _quickAccessItem(
              context,
              state,
              Icons.music_note,
              '音乐',
              '${_platformHomeDir()}/Music',
            ),
            _quickAccessItem(
              context,
              state,
              Icons.movie,
              '视频',
              '${_platformHomeDir()}/Videos',
            ),
          ],
          const Divider(),
          // Bookmarks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '书签',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (state.bookmarks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '暂无书签',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ...state.bookmarks.asMap().entries.map(
            (e) => ListTile(
              leading: const Icon(Icons.bookmark, size: 20),
              title: Text(e.value.name, style: const TextStyle(fontSize: 14)),
              // dense: true,
              onTap: () {
                state.navigateTo(e.value.path);
                Navigator.pop(context);
              },
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => state.removeBookmark(e.key),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '更多',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          _drawerItem(
            context,
            state,
            Icons.settings,
            '设置',
            DrawerSection.settings,
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsPage(state: state)),
              );
            },
          ),
          _drawerItem(
            context,
            state,
            Icons.info,
            '关于',
            DrawerSection.settings,
            () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    BuildContext ctx,
    FileManagerState state,
    IconData icon,
    String title,
    DrawerSection section,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(ctx);

    final selected = state.drawerSection == section;
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: selected ? theme.colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? theme.colorScheme.primary : null,
        ),
      ),
      selected: selected,
      onTap: onTap,
    );
  }

  Widget _quickAccessItem(
    BuildContext ctx,
    FileManagerState state,
    IconData icon,
    String title,
    String path,
  ) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      // dense: true,
      onTap: () {
        state.navigateTo(path);
        Navigator.pop(ctx);
      },
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
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
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
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
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

  Widget _buildContent(
    BuildContext context,
    FileManagerState state,
    List<FileEntry> entries,
  ) {
    final tab = state.currentTab;
    if (tab.loading) return const Center(child: CircularProgressIndicator());
    if (tab.error != null)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(tab.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state.loadCurrentTab,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    if (entries.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tab.isSearching ? Icons.search_off : Icons.folder_open,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              tab.isSearching ? '无搜索结果' : '此目录为空',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );

    if (tab.viewMode == ViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          childAspectRatio: 0.8,
        ),
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

  Widget _buildStatusBar(
    BuildContext context,
    FileManagerState state,
    List<FileEntry> entries,
  ) {
    final theme = Theme.of(context);
    final dirs = entries.where((e) => e.isDirectory).length;
    final files = entries.where((e) => !e.isDirectory).length;
    final totalSize = entries
        .where((e) => e.isFile)
        .fold<int>(0, (sum, e) => sum + e.size);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text('$dirs 个目录, $files 个文件', style: const TextStyle(fontSize: 12)),
          if (totalSize > 0)
            Text(
              '  (${Formatters.formatSize(totalSize)})',
              style: const TextStyle(fontSize: 12),
            ),
          if (state.currentTab.selectedPaths.isNotEmpty)
            Text(
              '  |  ${state.currentTab.selectedPaths.length} 已选',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
            ),
          const Spacer(),
          FutureBuilder<DiskUsage?>(
            future: Future(
              () => state.getDiskUsage(state.currentTab.currentPath),
            ),
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

  void _openEntry(
    BuildContext context,
    FileManagerState state,
    FileEntry entry,
  ) {
    final type = state.fileService.determineViewer(entry.path);
    switch (type) {
      case FileViewerType.text:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TextEditorPage(path: entry.path)),
        );
        break;
      case FileViewerType.image:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewerPage(initialPath: entry.path),
          ),
        );
        break;
      case FileViewerType.csv:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CsvViewerPage(path: entry.path)),
        );
        break;
      case FileViewerType.video:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VideoPlayerPage(path: entry.path)),
        );
        break;
      case FileViewerType.audio:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AudioPlayerPage(path: entry.path)),
        );
        break;
      case FileViewerType.pdf:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PdfViewerPage(path: entry.path)),
        );
        break;
      case FileViewerType.ebook:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EbookViewerPage(path: entry.path)),
        );
        break;
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法在应用内打开: ${entry.name}')));
    }
  }

  void _handleTap(
    BuildContext context,
    FileManagerState state,
    FileEntry entry,
  ) {
    if (state.currentTab.selectedPaths.isNotEmpty) {
      state.toggleSelection(entry.path);
    } else if (entry.isDirectory) {
      state.navigateTo(entry.path);
    } else {
      _openEntry(context, state, entry);
    }
  }

  void _handleMenu(
    BuildContext context,
    FileManagerState state,
    String action,
  ) {
    switch (action) {
      case 'new_folder':
        _createItem(context, state, true);
        break;
      case 'new_file':
        _createItem(context, state, false);
        break;
      case 'sort_name':
        state.setSortMode(SortMode.name);
        break;
      case 'sort_size':
        state.setSortMode(SortMode.size);
        break;
      case 'sort_modified':
        state.setSortMode(SortMode.modified);
        break;
      case 'sort_type':
        state.setSortMode(SortMode.type);
        break;
      case 'view_list':
        state.setViewMode(ViewMode.list);
        break;
      case 'view_grid':
        state.setViewMode(ViewMode.grid);
        break;
      case 'select_all':
        state.selectAll();
        break;
      case 'new_tab':
        state.addTab(state.currentTab.currentPath);
        break;
      case 'bookmark':
        state.addBookmark(
          FileService.getFileName(state.currentTab.currentPath),
          state.currentTab.currentPath,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已添加书签')));
        break;
      case 'refresh':
        state.loadCurrentTab();
        break;
    }
  }

  void _showEntryMenu(
    BuildContext context,
    FileManagerState state,
    FileEntry entry,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('属性'),
              onTap: () {
                Navigator.pop(ctx);
                _showProperties(context, state, entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, state, entry);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, state, [entry]);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProperties(
    BuildContext context,
    FileManagerState state,
    FileEntry entry,
  ) {
    showDialog(
      context: context,
      builder: (_) => PropertiesDialog(entry: entry, state: state),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    FileManagerState state,
    FileEntry entry,
  ) {
    final controller = TextEditingController(text: entry.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == entry.name) {
                Navigator.pop(ctx);
                return;
              }
              final newPath = FileService.joinPath(
                FileService.getParentPath(entry.path),
                newName,
              );
              final err = state.rename(entry.path, newPath);
              Navigator.pop(ctx);
              if (err != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(err)));
              }
              state.loadCurrentTab();
            },
            child: const Text('重命名'),
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
          decoration: InputDecoration(
            labelText: isDir ? '文件夹名' : '文件名',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final fullPath = FileService.joinPath(
                state.currentTab.currentPath,
                name,
              );
              final err = isDir
                  ? state.createDirectory(fullPath)
                  : state.createFile(fullPath);
              Navigator.pop(ctx);
              if (err != null)
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(err)));
              state.loadCurrentTab();
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    FileManagerState state,
    List<FileEntry> entries,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${entries.length} 个项目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              for (final e in entries) {
                final err = state.deleteFile(e.path);
                if (err != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('${e.name}: $err')));
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

  String _platformHomeDir() {
    if (Platform.isLinux) return '/home';
    if (Platform.isAndroid) return '/storage/emulated/0';
    if (Platform.isIOS) return '.'; // iOS sandbox
    return '/';
  }

  String _platformRootDir() {
    if (Platform.isLinux) return '/';
    if (Platform.isAndroid) return '/';
    if (Platform.isIOS) return '.'; // iOS sandbox
    return '/';
  }

  bool _platformIsLinux() => Platform.isLinux;

  void _deleteSelected(BuildContext context, FileManagerState state) {
    final selected = state.currentTab.entries
        .where((e) => state.currentTab.selectedPaths.contains(e.path))
        .toList();
    _confirmDelete(context, state, selected);
  }
}
