# AdvanceFileManager - 完整函数级设计文档
## 用于 Flutter + C++ 精确复刻参考 App

---

## 一、App 整体架构

### 1.1 Activity 结构 (参考 App)
```
FileListActivity (主入口, LAUNCHER)
  └── FileListFragment (核心)
       ├── NavigationFragment (导航抽屉)
       ├── BreadcrumbLayout (面包屑)
       ├── FileListAdapter (文件列表/网格)
       └── BottomBarLayout (底部操作栏)

SettingsActivity → SettingsPreferenceFragment
FileToolsActivity → FileSearchToolFragment / DuplicateFinderTool / ...
ToolHostActivity → 通用工具宿主
ImageViewerActivity / VideoViewerActivity / AudioPlayerActivity / ...
TextEditorActivity / PdfViewerActivity / CsvViewerActivity / EbookViewerActivity
```

### 1.2 Flutter 对应结构
```
FileManagerPage (StatefulWidget)
  ├── ChangeNotifierProvider<FileManagerState>
  └── _FileManagerView (StatelessWidget)
       ├── _buildAppBar()         → 顶部工具栏
       ├── _buildDrawer()         → 导航抽屉
       ├── _buildTabBar()         → 标签栏
       ├── BreadcrumbBar          → 面包屑
       ├── _buildContent()        → 文件列表/网格
       ├── _buildStatusBar()      → 底部状态栏
       └── FloatingActionButton   → 新建按钮
```

---

## 二、主页面详细设计 (FileListFragment)

### 2.1 Toolbar 顶部工具栏

**参考 App MenuProvider 的 onPrepareMenu 中更新菜单状态：**

#### 2.1.1 左侧导航
- **菜单按钮 (≡)**: `android.R.id.home` → 打开抽屉 (`drawerLayout.openDrawer(GravityCompat.START)`)
- 如果是 PersistentDrawerLayout，切换抽屉打开状态

#### 2.1.2 标题区
- **主标题**: 当前目录名 (通过 `activity.setTitle(R.string.file_list_title)`)
- **副标题**: 由 `getSubtitle(files)` 生成
  - 计算 directoryCount 和 fileCount
  - 格式: "X directories, Y files" (使用 `getQuantityString`)
  - 或单独显示 "X directories" 或 "Y files"
  - 空目录显示 "Empty"
- 加载中: 副标题显示 "Loading"
- 错误时: 副标题显示 "Error"

#### 2.1.3 右侧操作按钮

**始终显示在 Toolbar (showAsAction="always"):**
1. **排序/视图按钮** (action_view_sort): 排序图标，带子菜单
   - 子菜单分为两组（带 groupDivider 分隔线）:
     - **视图组** (checkableBehavior="single"):
       - 列表视图 ✓
       - 网格视图
     - **排序组** (checkableBehavior="single"):
       - 按名称 ✓
       - 按类型
       - 按大小
       - 按最后修改时间
       - ✓ 目录优先 (checkable="true"，独立复选)

**溢出菜单 (showAsAction="never"):**
2. 新标签页 (orderInCategory=100)
3. 新建文件 (orderInCategory=110)
4. 新建目录 (orderInCategory=110)
5. 入口设置-基本 (orderInCategory=200)
6. 入口设置-文件工具 (orderInCategory=200)
7. 入口设置-媒体工具 (orderInCategory=200)
8. 显示隐藏文件 (orderInCategory=300, checkable="true", 快捷键 h)

#### 2.1.4 菜单项处理函数
```dart
// 对应 FileListFragment.onMenuItemSelected()
switch (menuItem.itemId) {
  case 'home':
    drawerLayout.openDrawer(GravityCompat.START);
    // 如果是 persistent drawer，切换打开状态
    break;
  case 'action_view_list':
    viewModel.viewType = FileViewType.LIST;
    break;
  case 'action_view_grid':
    viewModel.viewType = FileViewType.GRID;
    break;
  case 'action_create_file':
    showCreateFileDialog(); // 弹出文件名输入对话框
    break;
  case 'action_create_directory':
    showCreateDirectoryDialog(); // 弹出目录名输入对话框
    break;
  case 'action_sort_by_name':
    viewModel.setSortBy(By.NAME);
    break;
  case 'action_sort_by_type':
    viewModel.setSortBy(By.TYPE);
    break;
  case 'action_sort_by_size':
    viewModel.setSortBy(By.SIZE);
    break;
  case 'action_sort_by_last_modified':
    viewModel.setSortBy(By.LAST_MODIFIED);
    break;
  case 'action_sort_directories_first':
    viewModel.setSortDirectoriesFirst(!isChecked);
    break;
  case 'action_new_task':
    openInNewTask(currentPath); // 新窗口打开
    break;
  case 'action_entry_basic_tools':
    showEntrySettings(FeatureSettingsFragment.SECTION_BASIC);
    break;
  case 'action_entry_file_tools':
    showEntrySettings(FeatureSettingsFragment.SECTION_FILE_TOOLS);
    break;
  case 'action_entry_media_tools':
    showEntrySettings(FeatureSettingsFragment.SECTION_MEDIA_TOOLS);
    break;
  case 'action_show_hidden_files':
    setShowHiddenFiles(!isChecked);
    break;
}
```

---

### 2.2 面包屑导航 (BreadcrumbLayout)

**实现方式：**
- 水平滚动的 chip/tag 列表
- 从当前路径解析每一级目录名
- 每级可点击 → `navigateTo(path)`
- 路径分隔符 (">") 可点击
- 支持编辑路径 (长按)

**数据模型 (BreadcrumbData):**
```dart
class BreadcrumbData {
  final List<BreadcrumbItem> items;
  final int selectedIndex;
}

class BreadcrumbItem {
  final String name;     // 显示名
  final String path;     // 完整路径
}
```

---

### 2.3 文件列表内容区

#### 2.3.1 状态显示 (4种状态互斥)
```dart
// onFileListChanged(stateful) 处理:
switch (stateful) {
  case Failure():
    toolbar.setSubtitle('Error');
    if (!hasFiles) errorText.visible = true;
    else showToast(error);
    break;
  case Loading() when !isSearching:
    toolbar.setSubtitle('Loading');
    break;
  case Success():
    toolbar.subtitle = getSubtitle(files);
    if (!hasFiles) emptyView.visible = true;
    break;
}
// 进度条: Loading && !(hasFiles || isSearching) 时显示
// SwipeRefresh: Loading && (hasFiles || isSearching) 时显示
```

#### 2.3.2 RecyclerView 设置
- **列表模式**: GridLayoutManager(spanCount=1)
- **网格模式**: GridLayoutManager(spanCount=自动计算)
  - 计算公式: `(screenWidthDp - drawerWidth) / GRID_COLUMN_WIDTH_DP(180)`
  - 最少2列
- **SwipeRefreshLayout**: 下拉刷新，超时30秒自动隐藏
- **FastScroller**: 快速滚动条
- **动画**: AnimatedListAdapter 支持渐入动画

---

### 2.4 文件列表项 (FileListAdapter)

#### 2.4.1 列表项布局 (file_item_list.xml)

```
┌─────────────────────────────────────────────────┐
│ [iconLayout: 48x48] [nameText]        [menuButton: 48x48] │
│   ├── iconImage (24dp)                           │
│   ├── thumbnailImage (仅文件)                     │
│   ├── appIconBadgeImage (仅App目录)               │
│   └── badgeImage (符号链接/加密标记)              │        │
│   [descriptionText: "日期 + 大小"]                │
└─────────────────────────────────────────────────┘
```

**详细字段绑定 (onBindViewHolder):**
```dart
// 1. 启用/禁用状态
bool isEnabled = isFileSelectable(file) || isDirectory;
itemLayout.isEnabled = isEnabled;
menuButton.isEnabled = isEnabled;

// 2. 选中状态
bool checked = file in selectedFiles;
itemLayout.isChecked = checked;

// 3. 文件名省略
nameText.ellipsize = nameEllipsize; // 可配置: START, MIDDLE, END, MARQUEE

// 4. 点击行为
itemLayout.onClick:
  if (selectedFiles.isEmpty) → listener.openFile(file)
  else → selectFile(file)

itemLayout.onLongClick:
  if (selectedFiles.isEmpty) → selectFile(file)
  else → listener.openFile(file)

iconLayout.onClick → selectFile(file)

// 5. 图标
iconImage: setImageResource(mimeType.iconRes) // 根据MIME类型
directoryThumbnailImage: visible if isDirectory
thumbnailOutlineView: visible if !isDirectory

// 6. 缩略图 (使用 Coil 图片加载)
thumbnailIconImage: APK图标缩略图
thumbnailImage: 图片/视频缩略图

// 7. App图标徽章
appIconBadgeImage: 如果是App目录(packageName), 显示App图标

// 8. 标记徽章
badgeImage:
  - 符号链接 → symbolic_link_badge_icon_18dp
  - 损坏链接 → error_badge_icon_18dp
  - 加密文件 → encrypted_badge_icon_18dp

// 9. 文件名
nameText.text = file.name

// 10. 描述文字 (仅文件，目录为null)
descriptionText.text = "日期 + 分隔符 + 大小"
  例: "2024-01-15  1.5 MB"
```

#### 2.4.2 网格项布局 (file_item_grid.xml)

```
┌────────────────────────┐
│ ┌────────────────────┐ │
│ │ thumbnailImage     │ │  ← 1.78:1 宽高比
│ │ 或 iconImage (40dp)│ │     圆角8dp
│ │                    │ │
│ └────────────────────┘ │
│ [iconLayout] [nameText]│  ← 底部48dp
│            [menuButton]│
└────────────────────────┘
```

**网格特有元素:**
- directoryThumbnailImage: 目录缩略图
- thumbnailOutlineView: 缩略图边框（非目录）
- thumbnailIconImage: 缩略图图标叠加层
- background: CheckableItemBackground(圆角12dp)
- foreground: Material3 网格前景遮罩

#### 2.4.3 文件项右键菜单 (file_item.xml)

**菜单项分3组 (带 groupDivider):**

**Common Group:**
1. 打开方式... (open_with) — 仅当 BasicSettings 允许时显示
2. 剪切 (cut) — 仅非 Picker 模式 && 非只读
3. 复制 (copy) — 仅非 Picker 模式
   - 如果是归档路径 → 标题改为 "提取"
4. 删除 (delete) — 仅非只读
5. 重命名 (rename) — 仅非只读
6. 提取 (extract) — 仅压缩文件 (isArchiveFile)
7. 压缩 (archive) — 仅非归档路径 && BasicSettings 允许
8. 分享 (share) — 仅当 BasicSettings 允许

**Plugin Group (动态):**
- 根据已启用的功能动态添加菜单项
- 遍历 FeatureManager.getAllFeatures()
- 过滤已启用的子功能

**Extended Group:**
1. 复制路径 (copy_path) — 仅当 BasicSettings 允许
2. 添加书签 (add_bookmark) — 仅目录 && BasicSettings 允许
3. 属性 (properties) — 仅当 BasicSettings 允许

#### 2.4.4 菜单项点击处理
```dart
switch (itemId) {
  case 'action_open_with': listener.openFileWith(file); break;
  case 'action_cut':       listener.cutFile(file); break;
  case 'action_copy':      listener.copyFile(file); break;
  case 'action_delete':    listener.confirmDeleteFile(file); break;
  case 'action_rename':    listener.showRenameFileDialog(file); break;
  case 'action_extract':   listener.extractFile(file); break;
  case 'action_archive':   listener.showCreateArchiveDialog(file); break;
  case 'action_share':     listener.shareFile(file); break;
  case 'action_copy_path': listener.copyPath(file); break;
  case 'action_add_bookmark': listener.addBookmark(file); break;
  case 'action_properties':   listener.showPropertiesDialog(file); break;
  default:
    // 功能菜单项处理
    final featureIndex = itemId - Menu.FIRST;
    if (featureIndex in enabledSubFeatures.indices) {
      final (featInfo, subFeature) = enabledSubFeatures[featureIndex];
      listener.launchFeature(featInfo, file, mimeType, subFeature.actionType, selectedFiles);
    }
}
```

---

### 2.5 选中模式 (Overlay ActionMode)

**触发**: 用户选中文件后激活

**Toolbar 标题**: "已选择 X 项" (`getString(R.string.file_list_select_title_format, files.size)`)

**菜单 (file_list_select.xml):**
- 剪切 (✂ icon, always show) — 仅非只读文件
- 复制 (📋 icon, always show)
  - 如果全是归档路径 → 图标改为提取图标，标题改为"提取"
- 删除 (🗑 icon, always show) — 仅非只读文件
- 全选 (☑ icon, always show)
- 提取 (never show) — 仅当全是压缩文件
- 压缩 (never show) — 仅当前路径非只读 && BasicSettings 允许
- 分享 (never show) — 仅当 BasicSettings 允许

**退出选中**: `overlayActionMode.finish()` → `viewModel.clearSelectedFiles()`

---

### 2.6 粘贴栏 (Bottom ActionMode)

**触发**: 用户执行复制/剪切后

**状态显示**:
```
复制: "X个文件已复制" (file_list_paste_copy_title_format)
剪切: "X个文件已剪切" (file_list_paste_move_title_format)
如果全是归档路径: "X个文件已提取" (file_list_paste_extract_title_format)
```

**菜单 (file_list_paste.xml):**
- 粘贴 (📋 icon, always show)
  - 如果全是归档路径 → 标题改为 "提取到此处"
  - 如果当前路径只读 → 禁用

**关闭按钮**: 
- 导航图标 (✕) → `viewModel.clearPasteState()` → 关闭底部栏

---

### 2.7 文件打开逻辑 (openFile)

```dart
void openFile(FileEntry file) {
  // 1. Picker 模式
  if (pickOptions != null) {
    if (file.isDirectory) {
      navigateTo(file.path);
    } else {
      switch (pickOptions.mode) {
        case OPEN_FILE: pickFiles({file}); break;
        case CREATE_FILE: confirmReplaceFile(file); break;
        case OPEN_DIRECTORY: /* 无操作 */ break;
      }
    }
    return;
  }
  
  // 2. APK 文件
  if (file.mimeType.isApk) {
    switch (Settings.OPEN_APK_DEFAULT_ACTION) {
      case INSTALL: installApk(file); break;
      case VIEW: viewApk(file); break;
      case ASK: OpenApkDialogFragment.show(file, this); break;
    }
    return;
  }
  
  // 3. PDF → PdfViewerActivity
  if (file.mimeType.isPdf) { openPdfViewer(file); return; }
  
  // 4. EPUB/MOBI → EbookViewerActivity
  if (file.mimeType.isMobi || file.mimeType.isEpub) { openEbookViewer(file); return; }
  
  // 5. CSV → CsvViewerActivity
  if (file.mimeType.isCsv) { openCsvViewer(file); return; }
  
  // 6. 图片 → ImageViewerActivity
  if (file.mimeType.isImage) { openImageViewer(file); return; }
  
  // 7. 视频 → VideoViewerActivity
  if (file.mimeType.isVideo) { openVideoViewer(file); return; }
  
  // 8. 音频 → AudioPlayerActivity
  if (file.mimeType.isAudio) { openAudioPlayer(file); return; }
  
  // 9. 文本 → TextEditorActivity
  if (file.mimeType.isText) { openTextEditor(file); return; }
  
  // 10. 可列出的(压缩包) → 导航进入
  if (file.isListable) { navigateTo(file.listablePath); return; }
  
  // 11. 其他 → 系统 Intent
  openFileWithIntent(file, false);
}
```

**图片/视频/音频查看器额外逻辑:**
- 收集当前列表中所有同类型文件的路径列表
- 传递给查看器以便滑动切换
- 最大传递1000个路径避免 TransactionTooLargeException

---

### 2.8 排序逻辑 (FileSortOptions)

```dart
Comparator<FileItem> createComparator() {
  // 1. 基础比较器：忽略前缀(., #) + 名称排序
  var comparator = compareBy((it) => NAME_UNIMPORTANT_PREFIXES.any((p) => it.name.startsWith(p)))
    .thenBy((it) => it.nameCollationKey);
  
  // 2. 按类型额外排序
  switch (by) {
    case NAME: /* 无额外排序 */
    case TYPE: comparator = compareBy<String>((it) => it.extension, caseInsensitive: true).then(comparator);
    case SIZE: comparator = compareBy((it) => it.attributes.size).then(comparator);
    case LAST_MODIFIED: comparator = compareBy((it) => it.attributes.lastModifiedTime).then(comparator);
  }
  
  // 3. 排序方向
  if (order == DESCENDING) comparator = comparator.reversed();
  
  // 4. 目录优先
  if (isDirectoriesFirst) {
    comparator = compareBy((it) => it.isDirectory).reversed().then(comparator);
  }
  
  return comparator;
}
```

**排序特殊规则:**
- `NAME_UNIMPORTANT_PREFIXES = [".", "#"]` — 以这些开头的文件排在后面
- 名称使用 collationKey 排序 (支持本地化)
- 类型排序使用不区分大小写比较

---

### 2.9 导航抽屉 (NavigationFragment)

**NavigationItemListLiveData 生成导航项列表:**

```dart
List<NavigationItem?> get navigationItems => [
  // 1. 存储区标题
  NavigationHeader(title: "存储"),
  
  // 2. 存储卷 (从 Settings.STORAGES 和 StorageVolumeListLiveData)
  ...storages.map((s) => StorageItem(storage: s)),
  
  // 3. 导航区标题
  NavigationHeader(title: "导航"),
  
  // 4. 标准目录 (从 StandardDirectoriesLiveData)
  ...standardDirectories.map((d) => StandardDirectoryItem(directory: d)),
  // 包括: 根目录, 主目录, 下载, 图片, 音乐, 影片, 文档, DCIM
  
  // 5. 书签区标题
  NavigationHeader(title: "书签"),
  
  // 6. 书签目录 (从 Settings.BOOKMARK_DIRECTORIES)
  ...bookmarks.map((b) => BookmarkDirectoryItem(bookmark: b)),
  
  // 7. 工具区标题
  NavigationHeader(title: "工具"),
  
  // 8. 文件工具
  FileToolsNavigationItem(),
  
  // 9. 存储分析
  StorageAnalysisNavigationItem(),
  
  // 10. 设置
  SettingsNavigationItem(),
  
  // 11. 关于
  AboutNavigationItem(),
];
```

**每个 NavigationItem 的行为:**
```dart
abstract class NavigationItem {
  int get id;
  IconData getIcon();     // 图标
  String getTitle();      // 标题
  String? getSubtitle();  // 副标题（可选，如路径）
  bool isChecked();       // 是否高亮（当前路径匹配）
  void onClick();         // 点击行为
  bool onLongClick();     // 长按行为（可选）
}
```

**导航项类型:**
1. **StorageItem**: 图标=storage, 标题=存储名, 副标题=路径, 点击=navigateToRoot(path)
2. **StandardDirectoryItem**: 图标=对应图标, 标题=目录名, 点击=navigateToRoot(path)
3. **BookmarkDirectoryItem**: 图标=bookmark, 标题=自定义名或目录名, 点击=navigateTo(path)
4. **FileToolsNavigationItem**: 图标=build, 标题="文件工具", 点击=启动FileToolsActivity
5. **StorageAnalysisNavigationItem**: 图标=pie_chart, 标题="存储分析"
6. **SettingsNavigationItem**: 图标=settings, 标题="设置", 点击=启动SettingsActivity
7. **AboutNavigationItem**: 图标=info, 标题="关于"

---

### 2.10 搜索功能

**触发**: Toolbar 中 SearchView 展开

**实现**:
```dart
// FileListViewModel
void search(String query) {
  searchState = SearchState(isSearching: true, query: query);
  // → FileListSwitchMapLiveData 切换到 SearchFileListLiveData
}

void stopSearching() {
  searchState = SearchState(isSearching: false, query: '');
  // → 切换回 FileListLiveData
}
```

**SearchFileListLiveData**: 使用 glob 模式递归搜索当前目录下所有文件

---

## 三、设置页面详细设计

### 3.1 设置项列表 (SettingsFragment)

**使用 PreferenceFragmentCompat，每个设置项格式:**
```
┌──────────────────────────────┐
│ 标题 (textAppearanceTitleMedium) │
│ 摘要 (textAppearanceBodyMedium, onSurfaceVariant) │
└──────────────────────────────┘
```

**设置项:**

| 键 | 标题 | 默认值 | 类型 |
|---|---|---|---|
| pref_key_language | 语言 | 系统默认 | 列表选择 |
| pref_key_file_name_ellipsize | 显示长文件名 | 省略开头 | 列表(START/MIDDLE/END/MARQUEE) |
| pref_key_file_list_default_directory | 默认文件夹 | /storage/emulated/0 | 路径选择 |
| pref_key_storages | 存储空间 | 内部存储+主卷 | 多选存储 |
| pref_key_bookmark_directories | 书签文件夹 | 空 | 书签列表 |
| pref_key_root_strategy | Root 访问模式 | 仅普通访问 | 列表(NONE/ROOT/SHIZUKU) |
| pref_key_archive_file_name_encoding | 归档文件名编码 | UTF-8 | 文本输入 |
| pref_key_open_apk_default_action | 打开 Android 安装包 | 安装 | 列表(INSTALL/VIEW/ASK) |

---

## 四、文件工具详细设计

### 4.1 FileToolsActivity 布局
```xml
<LinearLayout orientation="vertical">
  <Toolbar navigationIcon="back" />  <!-- 返回按钮 -->
  <SelectedFilesPreview />            <!-- 选中文件预览(可选) -->
  <FrameLayout id="content" />        <!-- Fragment 容器 -->
</LinearLayout>
```

**默认打开 FileSearchToolFragment (actionType="file_search")**

### 4.2 FileSearchToolFragment

**布局 (fragment_file_search.xml):**
```
┌──────────────────────────────┐
│ SearchView (搜索框)           │  ← queryHint="输入文件名或正则"
├──────────────────────────────┤
│ LinearProgressIndicator       │  ← 搜索中(indeterminate, gone)
├──────────────────────────────┤
│ TextView (空提示)             │  ← "输入关键字开始搜索"
├──────────────────────────────┤
│ RecyclerView (结果列表)       │  ← padding底部8dp
│ ┌──────────────────────────┐ │
│ │ [icon] title             │ │
│ │        subtitle (路径)   │ │
│ ├──────────────────────────┤ │
│ │ ...                      │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

**结果列表项 (tool_file_item.xml):**
```
┌──────────────────────────────────────┐
│ [Switch(可选)] │ 标题 (bodyLarge)      │
│                │ 副标题 (bodySmall, 最多2行) │
└──────────────────────────────────────┘
```

### 4.3 DuplicateFinderToolFragment

**布局 (tool_fragment_base.xml):**
```
┌──────────────────────────────┐
│ [查找重复文件] [清除结果]     │  ← 双按钮操作栏
├──────────────────────────────┤
│ LinearProgressIndicator       │
│ TextView (空提示)             │
│ RecyclerView                  │
│ ┌──────────────────────────┐ │
│ │ ExpansionTile:           │ │
│ │   标题: 哈希前16字符     │ │
│ │   副标题: X个文件, Y MB  │ │
│ │   ├ [icon] name          │ │
│ │   │       path           │ │
│ │   │       size           │ │
│ │   └ [icon] name          │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

### 4.4 EmptySearchToolFragment

- 主按钮: "查找空文件"
- 结果: 文件名 + 路径，图标区分文件/目录

### 4.5 RecentFilesToolFragment

- 主按钮: "扫描最近文件"
- 次按钮: "清除结果"
- 结果: 文件名 + 路径 + 大小 + 修改时间
- 默认扫描7天内

### 4.6 HexViewerToolFragment

**布局 (fragment_hex_viewer_tool.xml):**
```
┌──────────────────────────────┐
│ [文件路径输入框]              │
│ [打开] 按钮                   │
├──────────────────────────────┤
│ RecyclerView (Hex 行列表)     │
│ ┌──────────────────────────┐ │
│ │ 00000000: 4865 6C6C ... │ Hello... │ │
│ │ 00000010: ...           │          │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

### 4.7 EncryptionToolFragment

**布局 (fragment_encryption.xml):**
```
┌──────────────────────────────┐
│ [源文件路径]                  │
│ [密码输入框]                  │
│ [加密] [解密] 按钮            │
├──────────────────────────────┤
│ LinearProgressIndicator       │
│ TextView (结果/错误)          │
└──────────────────────────────┘
```

### 4.8 FileCompareToolFragment

**布局 (fragment_file_compare.xml):**
```
┌──────────────────────────────┐
│ [文件1路径]                   │
│ [文件2路径]                   │
│ [对比] 按钮                   │
├──────────────────────────────┤
│ LinearProgressIndicator       │
│ TextView (结果: 相同/不同)    │
│   ├── MD5, SHA1, SHA256      │
│   └── 逐字节对比结果          │
└──────────────────────────────┘
```

### 4.9 TrashToolFragment

**布局 (fragment_trash.xml):**
```
┌──────────────────────────────┐
│ [恢复全部] [清空回收站] 按钮  │
├──────────────────────────────┤
│ RecyclerView (已删除文件列表) │
│ ┌──────────────────────────┐ │
│ │ [icon] 文件名            │ │
│ │        原始路径           │ │
│ │        删除时间           │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

---

## 五、查看器详细设计

### 5.1 TextEditorActivity

**布局 (text_editor_fragment.xml):**
```
┌──────────────────────────────┐
│ Toolbar: 文件名               │
│ [返回] [文件名]     [保存][撤销][重做] │
├──────────────────────────────┤
│ EditText (多行文本)           │
│ ─ 可编辑 ─                   │
│ ─ ─ ─ ─ ─                   │
│ ─ ─ ─ ─ ─                   │
├──────────────────────────────┤
│ 底部栏: 编码 | 行号:列号     │
└──────────────────────────────┘
```

### 5.2 ImageViewerActivity

**布局 (image_viewer_fragment.xml):**
```
┌──────────────────────────────┐
│ 全屏沉浸模式                  │
│ ┌──────────────────────────┐ │
│ │ ViewPager2               │ │
│ │ ┌──────────────────────┐ │ │
│ │ │ PhotoView (可缩放)   │ │ │
│ │ └──────────────────────┘ │ │
│ └──────────────────────────┘ │
│ Overlay Toolbar (点击显示):   │
│ [返回] [标题]     [分享][信息]│
└──────────────────────────────┘
```

### 5.3 VideoViewerActivity

**布局 (video_viewer_fragment.xml):**
```
┌──────────────────────────────┐
│ 全屏沉浸模式                  │
│ ┌──────────────────────────┐ │
│ │ PlayerView (SurfaceView) │ │
│ │ ┌──────────────────────┐ │ │
│ │ │ 视频画面              │ │ │
│ │ └──────────────────────┘ │ │
│ │ 控制栏:                  │ │
│ │ [播放/暂停] [进度条] [全屏]│ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

### 5.4 AudioPlayerActivity

**布局 (audio_player_fragment.xml):**
```
┌──────────────────────────────┐
│ 全屏沉浸模式                  │
│ ┌──────────────────────────┐ │
│ │ 专辑封面 (居中)          │ │
│ │                          │ │
│ ├──────────────────────────┤ │
│ │ 文件名                   │ │
│ │ 时长信息                  │ │
│ ├──────────────────────────┤ │
│ │ [进度条]                 │ │
│ │ [上一曲] [播放/暂停] [下一曲]│ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

### 5.5 PdfViewerActivity

**布局 (pdf_viewer_fragment.xml):**
```
┌──────────────────────────────┐
│ 全屏沉浸模式                  │
│ ┌──────────────────────────┐ │
│ │ PDF 渲染视图              │ │
│ │ (可缩放/滑动)            │ │
│ ├──────────────────────────┤ │
│ │ 底部栏: [上一页] 页码 [下一页]│ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

### 5.6 CsvViewerActivity

**布局 (csv_viewer_fragment.xml):**
```
┌──────────────────────────────┐
│ Toolbar: 文件名               │
├──────────────────────────────┤
│ HorizontalScrollView         │
│ ┌──────────────────────────┐ │
│ │ TableView (表格)          │ │
│ │ ┌────┬────┬────┐        │ │
│ │ │ 列1│ 列2│ 列3│        │ │
│ │ ├────┼────┼────┤        │ │
│ │ │ 值 │ 值 │ 值 │        │ │
│ │ └────┴────┴────┘        │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

### 5.7 EbookViewerActivity

**布局 (ebook_viewer_fragment.xml):**
```
┌──────────────────────────────┐
│ Toolbar: 书名                 │
├──────────────────────────────┤
│ WebView (电子书渲染)          │
│ ┌──────────────────────────┐ │
│ │ 电子书内容                │ │
│ │ (支持翻页/缩放)          │ │
│ └──────────────────────────┘ │
├──────────────────────────────┤
│ 底部栏: 章节导航 | 字体大小   │
└──────────────────────────────┘
```

---

## 六、核心数据模型 (精确对应)

### 6.1 FileEntry (对应 FileItem)
```dart
class FileEntry {
  final String name;           // 文件名
  final String path;           // 完整路径
  final String mimeType;       // MIME 类型 (如 "text/plain")
  final bool isDirectory;      // 是否目录
  final bool isHidden;         // 是否隐藏 (以.开头)
  final bool isSymlink;        // 是否符号链接
  final bool isReadable;       // 是否可读
  final bool isWritable;       // 是否可写
  final int size;              // 文件大小 (字节)
  final int modifiedTime;      // 最后修改时间 (Unix时间戳)
  final String permissions;    // 权限字符串 (如 "rwxr-xr-x")
  
  // 派生属性
  String get extension => ...; // 扩展名
  bool get isArchiveFile => ...; // 是否压缩文件
  bool get isListable => ...;  // 是否可列出 (压缩包目录)
  String get listablePath => ...; // 可列出路径
}
```

### 6.2 TabState
```dart
class TabState {
  String id;
  String currentPath;
  List<FileEntry> entries;
  bool loading;
  String? error;
  List<String> history;      // 导航历史
  int historyIndex;          // 历史索引
  bool showHidden;           // 显示隐藏文件
  SortMode sortMode;         // 排序模式
  bool sortAscending;        // 排序方向
  ViewMode viewMode;         // 视图模式
  Set<String> selectedPaths; // 选中路径
  String searchQuery;        // 搜索查询
  bool isSearching;          // 是否搜索中
}
```

### 6.3 PasteState
```dart
class PasteState {
  bool copy;           // true=复制, false=剪切
  Set<String> files;   // 文件路径集合
}
```

### 6.4 Settings
```dart
class Settings {
  static Path storages;                    // 存储列表
  static Path defaultDirectory;            // 默认目录
  static bool persistentDrawerOpen;        // 抽屉常开
  static bool showHiddenFiles;             // 显示隐藏文件
  static FileViewType viewType;            // 视图类型
  static FileSortOptions sortOptions;      // 排序选项
  static int createArchiveType;            // 归档类型
  static bool animation;                   // 动画
  static TextTruncateAt nameEllipsize;     // 文件名省略
  static List<StandardDirectory> standardDirs; // 标准目录
  static List<BookmarkDirectory> bookmarks; // 书签
  static RootStrategy rootStrategy;        // Root 策略
  static String archiveFileNameEncoding;   // 归档编码
  static OpenApkDefaultAction openApkAction; // APK 打开方式
}
```

---

## 七、文件操作详细流程

### 7.1 复制流程
```
1. 用户选中文件 → 点击复制
2. cutFiles/copyFiles(files):
   - viewModel.addToPasteState(copy=true, files)
   - viewModel.selectFiles(files, false) // 清除选中
3. 显示底部粘贴栏:
   - 标题: "X个文件已复制"
   - 按钮: 粘贴
4. 用户导航到目标目录
5. 用户点击粘贴
6. pasteFiles(targetDirectory):
   - 检查 hasRunningFileJob()
   - FileJobService.copy(paths, targetDir, context)
   - showToast("文件复制已开始")
   - viewModel.clearPasteState()
```

### 7.2 删除流程
```
1. 用户选中文件 → 点击删除
2. confirmDeleteFiles(files):
   - 检查 hasRunningFileJob()
   - ConfirmDeleteFilesDialogFragment.show(files)
3. 用户确认删除
4. deleteFiles(files):
   - FileJobService.delete(paths, context)
   - viewModel.selectFiles(files, false)
   - showToast("文件删除已开始")
```

### 7.3 重命名流程
```
1. 用户点击重命名
2. RenameFileDialogFragment.show(file)
3. 用户输入新名称
4. renameFile(file, newName):
   - 检查 hasRunningFileJob()
   - FileJobService.rename(path, newName, context)
   - viewModel.selectFile(file, false)
   - showToast("文件重命名已开始")
```

### 7.4 创建文件/目录流程
```
1. 菜单 → 新建文件/目录
2. CreateFileDialogFragment / CreateDirectoryDialogFragment
3. 用户输入名称
4. createFile(name) / createDirectory(name):
   - path = currentPath.resolve(name)
   - FileJobService.create(path, isDir, context)
```

### 7.5 归档流程
```
1. 选中文件 → 压缩
2. CreateArchiveDialogFragment.show(files)
3. 用户选择格式、过滤器、密码
4. archive(files, name, format, filter, password):
   - archiveFile = currentPath.resolve(name)
   - FileJobService.archive(paths, archiveFile, format, filter, password, context)
```

---

## 八、排序和视图切换

### 8.1 排序更新流程
```dart
// FileListViewModel
void setSortBy(By by) {
  _sortOptionsLiveData.putBy(by);
  // → FileSortOptionsLiveData 更新值
  // → 触发 sortOptionsLiveData observer
  // → adapter.sortOptions = newSortOptions
  // → adapter.replace(sortedList, true)
}

void setSortDirectoriesFirst(bool isDirectoriesFirst) {
  _sortOptionsLiveData.putIsDirectoriesFirst(isDirectoriesFirst);
}
```

### 8.2 视图切换流程
```dart
// FileListViewModel
set viewType(FileViewType value) {
  _viewTypeLiveData.putValue(value);
  // → 触发 viewTypeLiveData observer
  // → updateSpanCount()
  // → adapter.viewType = viewType
}
```

---

## 九、Material Design 3 设计规范

### 9.1 颜色
- primary: 主色调
- primaryContainer: 选中项背景
- surface: 表面色
- surfaceContainerHighest: 网格项背景
- onSurface: 主文字色
- onSurfaceVariant: 描述文字色
- error: 错误/锁图标色

### 9.2 尺寸
| 元素 | 尺寸 |
|---|---|
| 列表项高度 | 64dp (two_line_list_item_height) |
| 图标大小 | 24dp |
| 触摸目标 | 48dp x 48dp |
| 网格列宽 | 180dp |
| 网格缩略图宽高比 | 1.78:1 |
| 网格项圆角 | 12dp |
| 缩略图圆角 | 8dp |
| 面包屑间距 | 8dp |
| Toolbar 高度 | ?actionBarSize (56dp) |
| 底部栏高度 | ?actionBarSize (56dp) |
| 分隔线高度 | 1dp |

### 9.3 字体
| 用途 | 样式 |
|---|---|
| Toolbar 标题 | titleLarge |
| 文件名 | titleMedium (列表), bodyMedium (网格) |
| 描述文字 | bodyMedium (onSurfaceVariant) |
| 导航项标题 | bodyLarge |
| 设置项标题 | titleMedium |
| 设置项摘要 | bodyMedium (onSurfaceVariant) |
| 按钮文字 | labelLarge |
| 工具列表标题 | bodyLarge |
| 工具列表副标题 | bodySmall (最多2行) |

---

## 十、函数级对照表

### 10.1 FileManagerState (对应 FileListViewModel)
```
FileManagerState.initialize()        → FileListViewModel 构造 + 初始路径
FileManagerState.currentTab          → viewModel.currentPath
FileManagerState.navigateTo(path)    → viewModel.navigateTo(state, path)
FileManagerState.goBack()            → viewModel.navigateUp()
FileManagerState.goForward()         → trailLiveData.navigateForward()
FileManagerState.goUp()              → navigateTo(parentPath)
FileManagerState.loadCurrentTab()    → FileListLiveData.loadValue()
FileManagerState.toggleHidden()      → Settings.FILE_LIST_SHOW_HIDDEN_FILES
FileManagerState.setSortMode()       → viewModel.setSortBy(by)
FileManagerState.setViewMode()       → viewModel.viewType = value
FileManagerState.toggleSelection()   → viewModel.selectFile(file, !selected)
FileManagerState.selectAll()         → adapter.selectAllFiles()
FileManagerState.clearSelection()    → viewModel.clearSelectedFiles()
FileManagerState.setSearchQuery()    → viewModel.search(query)
FileManagerState.toggleSearch()      → viewModel.stopSearching()
FileManagerState.filteredEntries     → updateAdapterFileList()
FileManagerState.copyToClipboard()   → viewModel.addToPasteState(copy, files)
FileManagerState.pasteClipboard()    → pasteFiles(targetDir)
FileManagerState.createDirectory()   → FileJobService.create(path, true)
FileManagerState.createFile()        → FileJobService.create(path, false)
FileManagerState.deleteFile()        → FileJobService.delete(path)
FileManagerState.rename()            → FileJobService.rename(oldPath, newPath)
FileManagerState.copyFile()          → FileJobService.copy(src, dst)
FileManagerState.moveFile()          → FileJobService.move(src, dst)
FileManagerState.openFileEntry()     → openFile(file) 逻辑
FileManagerState.searchFiles()       → SearchFileListLiveData
FileManagerState.findDuplicates()    → DuplicateFinderToolFragment
FileManagerState.findEmptyFiles()    → EmptySearchToolFragment
FileManagerState.computeHash()       → HexViewerToolFragment
FileManagerState.getDiskUsage()      → Storage 使用信息
```

---

## 十一、开发检查清单

### Phase 1: 核心框架
- [ ] FileManagerState 状态管理 (所有 TabState 字段)
- [ ] 主页面 Scaffold (AppBar + Drawer + Body + FAB)
- [ ] 导航抽屉 (所有导航项类型)
- [ ] 面包屑导航 (路径解析 + 点击 + 滚动)
- [ ] 文件列表 (ListView + GridView 切换)
- [ ] 文件列表项 (64dp 高度, 图标+标题+描述+更多按钮)
- [ ] 文件网格项 (Card + 缩略图区 + 底部栏)
- [ ] 排序功能 (4种排序 + 目录优先 + 升降序)
- [ ] 文件操作菜单 (底部弹出菜单, 所有菜单项)
- [ ] 选中模式 (顶部操作栏, 6个操作按钮)
- [ ] 粘贴栏 (底部显示, 粘贴/关闭按钮)
- [ ] 隐藏文件切换
- [ ] 加载/错误/空状态显示
- [ ] 下拉刷新

### Phase 2: 文件操作
- [ ] 复制/剪切/粘贴 (完整流程)
- [ ] 删除 (确认对话框 + 批量删除)
- [ ] 重命名 (对话框 + 冲突检测)
- [ ] 新建文件/目录
- [ ] 属性对话框
- [ ] 复制路径
- [ ] 添加书签
- [ ] 分享文件
- [ ] 归档/压缩

### Phase 3: 查看器
- [ ] 文本编辑器 (编辑+保存+撤销+重做)
- [ ] 图片查看器 (缩放+滑动+分享)
- [ ] 视频播放器 (播放控制)
- [ ] 音频播放器 (播放控制+播放列表)
- [ ] PDF 查看器 (翻页+缩放)
- [ ] CSV 查看器 (表格视图)
- [ ] 电子书查看器

### Phase 4: 文件工具
- [ ] 文件搜索 (glob 模式)
- [ ] 重复文件查找 (SHA256 分组)
- [ ] 空文件查找
- [ ] 最近文件
- [ ] 十六进制查看器
- [ ] 文件加密
- [ ] 文件对比
- [ ] 回收站

### Phase 5: 设置和其他
- [ ] 设置页面 (所有设置项)
- [ ] 存储分析
- [ ] Picker 模式
- [ ] 多标签页
- [ ] 快捷键支持
- [ ] 深色主题
