📘 产品全案：M3 Design 本地智能文件管理器（代号：TagFile）
一、产品定位
一款纯本地、标签驱动、隐私优先的跨平台文件管理工具。不扫描系统全盘，所有文件由用户主动“导入”至应用私有沙箱，通过标签体系实现高效分类与检索，UI遵循Material You（M3）设计规范。

二、核心功能需求（细化）
2.1 文件导入（唯一入口）
平台	导入来源	实现方式
Android	系统文件管理器、相册、媒体库	Intent.ACTION_OPEN_DOCUMENT / MediaStore
iOS	系统“文件”App、相册	UIDocumentPickerViewController / PHPicker
导入时自动复制文件到应用私有目录（getApplicationDocumentsDirectory），保留原始文件名、创建时间、修改时间、大小。

导入后强制要求用户至少分配1个标签，否则文件不进入主库（暂存区）。

支持批量导入，批量时可为所有文件统一添加相同标签，或逐个标记。

2.2 文件存储与私有空间
所有文件存储在应用沙箱内，目录结构按导入日期自动分区（如 /files/2026/08/08/），但不对用户暴露此物理路径。

用户界面只显示文件逻辑列表，不显示真实文件系统路径。

应用卸载时，所有文件彻底删除（符合GDPR/隐私合规）。

2.3 标签管理系统（核心）
每个文件可拥有多个标签（多对多关系）。

标签属性：id, name, color（M3动态色）, icon（可选）, create_time。

系统预置标签：📷 照片、🎬 视频、🎵 音频、📄 文档、📑 PDF，用户可编辑、删除、新增。

标签支持重命名、改色、合并（将A标签所有文件转移到B标签后删除A）。

支持标签层级（父标签/子标签），最多3级（如“工作/项目A/设计稿”）。

2.4 文件查看与预览（内嵌播放/查看器）
文件类型	预览方式
图片（jpg/png/webp/heic/gif）	图片查看器（支持缩放、滑动浏览、横屏）
视频（mp4/mov/avi）	视频播放器（进度条、播放/暂停、全屏）
音频（mp3/wav/aac/m4a）	音频播放器（封面图、波形、锁屏控制）
PDF	PDF查看器（页面缩放、目录跳转、搜索）
文本（txt/md/json/xml）	代码高亮文本查看器
其他（zip/apk/ipa）	显示文件信息（大小、类型），提供“分享”按钮
所有预览器不联网，纯本地解码（依赖Flutter插件，如video_player、audioplayers、pdfx）。

2.5 搜索引擎（标签驱动）
搜索框支持实时搜索（输入时过滤）。

搜索维度：

标签名（输入“工作” → 显示所有含“工作”标签的文件）

文件名（模糊匹配）

组合搜索：标签:工作 + 类型:pdf + 日期:2026-08（简易语法）

搜索历史记录（本地保存最近10条）。

搜索结果按相关度排序（标签匹配优先 > 文件名匹配）。

2.6 其他常规文件操作
复制、移动（仅限应用内不同标签组间）、重命名、删除（二次确认）。

排序：按名称、大小、创建日期、修改日期（升/降序）。

视图切换：网格模式（缩略图） / 列表模式（详细信息）。

文件信息详情弹窗（路径、大小、创建/修改时间、所有标签）。

三、UI/UX 设计规范（严格遵循 M3）
3.1 色彩系统
使用 dynamic_color 包，自动提取Android 12+壁纸主色，iOS降级为自定义M3调色板。

主色（Primary）、次色（Secondary）、容器色（Container）、表面色（Surface）。

标签颜色使用 tonal 风格，即背景淡色 + 文字深色。

3.2 布局结构（三页式底部导航）
底部Tab	内容
📁 文件	默认显示所有文件（按修改时间倒序），顶部有筛选栏（按标签过滤）
🏷️ 标签	显示所有标签（卡片网格），点击进入该标签下的文件列表
🔍 搜索	搜索框 + 历史记录 + 高级筛选条件
⚙️ 设置	导入来源管理、标签管理、存储空间统计、清空缓存、关于
3.3 交互细节
长按文件进入多选模式（批量操作）。

滑动删除（仅在列表模式支持）。

下拉刷新（重新扫描沙箱目录，同步文件状态）。

加载/空状态显示M3风格的骨架屏或插图。

四、技术架构（Flutter + C++ + SQLite）
4.1 技术选型理由
Flutter：一套代码覆盖Android/iOS，且M3组件支持完善。

C++：用于高性能文件操作（复制、哈希计算）、媒体元数据提取（通过ffmpeg），通过dart:ffi调用。

SQLite：存储文件元数据、标签关系、搜索索引，使用sqflite + drift（类型安全ORM）。

4.2 数据库设计（核心表）
sql
-- 文件表
CREATE TABLE files (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  size INTEGER,
  mime_type TEXT,
  path TEXT UNIQUE NOT NULL,
  create_time INTEGER,
  modify_time INTEGER,
  import_time INTEGER,
  thumbnail_path TEXT -- 缩略图缓存路径
);

-- 标签表
CREATE TABLE tags (
  id INTEGER PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  color INTEGER,
  parent_id INTEGER DEFAULT 0,
  icon_code TEXT
);

-- 文件-标签关联表（多对多）
CREATE TABLE file_tags (
  file_id INTEGER,
  tag_id INTEGER,
  FOREIGN KEY(file_id) REFERENCES files(id) ON DELETE CASCADE,
  FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY(file_id, tag_id)
);

-- 索引加速
CREATE INDEX idx_file_tags_tag ON file_tags(tag_id);
CREATE INDEX idx_file_name ON files(name);
4.3 C++ 模块职责
文件拷贝/移动（带进度回调）

计算文件MD5（用于去重检测）

提取媒体元数据（分辨率、时长、比特率）存入SQLite

生成缩略图（图片/video frame）存为WebP

4.4 Flutter插件依赖（推荐）
yaml
dependencies:
  flutter:
    sdk: flutter
  dynamic_color: ^1.7.0
  sqflite: ^2.3.0
  drift: ^2.14.0
  file_picker: ^6.1.0
  image_picker: ^1.0.0
  video_player: ^2.8.0
  audioplayers: ^5.2.0
  pdfx: ^2.5.0
  photo_view: ^0.14.0
  path_provider: ^2.1.0
  flutter_ffi: ^0.2.0  # 用于C++桥接
五、目录结构规范（清晰分层）
text
lib/
├── main.dart                      # 应用入口，主题配置
├── core/                          # 核心基础设施
│   ├── database/                  # 数据库操作（drift生成代码）
│   │   ├── app_database.dart
│   │   ├── dao/
│   │   │   ├── file_dao.dart
│   │   │   └── tag_dao.dart
│   │   └── migrations/
│   ├── ffi/                       # C++桥接层
│   │   ├── native_bridge.dart     # FFI方法声明
│   │   └── native_utils.dart      # 类型转换工具
│   └── models/                    # 数据实体（PODO）
│       ├── file_model.dart
│       ├── tag_model.dart
│       └── file_tag_model.dart
├── services/                      # 业务逻辑层
│   ├── file_service.dart          # 导入/删除/移动/复制
│   ├── tag_service.dart           # 增删改查/合并
│   ├── search_service.dart        # 搜索逻辑（含SQL优化）
│   └── import_service.dart        # 平台差异化导入
├── ui/                            # 界面层
│   ├── screens/                   # 页面
│   │   ├── file_list_screen.dart
│   │   ├── tag_list_screen.dart
│   │   ├── search_screen.dart
│   │   └── settings_screen.dart
│   ├── widgets/                   # 可复用组件
│   │   ├── file_card.dart
│   │   ├── tag_chip.dart
│   │   ├── media_preview/         # 预览器子组件
│   │   │   ├── image_viewer.dart
│   │   │   ├── video_player.dart
│   │   │   ├── audio_player.dart
│   │   │   └── pdf_viewer.dart
│   │   └── custom_app_bar.dart
│   └── theme/                     # M3主题配置
│       ├── app_theme.dart
│       └── color_scheme.dart
└── utils/                         # 工具函数
    ├── file_type_helper.dart      # MIME类型判断
    ├── date_formatter.dart
    ├── size_converter.dart
    └── permission_handler.dart    # 权限请求封装
六、开发流程与验收标准（给AI的SOP）
6.1 开发优先级（MVP阶段）
数据库层（SQLite建表 + DAO）

导入功能（Android + iOS双端实现）

文件列表 + 标签管理（CRUD）

基础预览器（图片、视频、PDF）

搜索功能（标签+文件名）

批量操作 + 设置页

6.2 非功能性要求
冷启动时间 < 2秒（优化SQL索引和缩略图懒加载）

导入大文件（1GB）不阻塞UI（使用compute或Isolate）

内存占用不超过200MB（图片/视频预览时释放缓存）

代码注释覆盖率达到30%以上（关键方法须有文档注释）

6.3 测试用例（AI自测清单）
□ 导入10张图片，分配标签 → 文件列表显示正确
□ 切换标签筛选 → 只显示对应文件
□ 删除标签 → 关联文件标签自动移除（不删文件）
□ 搜索“标签:工作” → 正确过滤
□ 视频播放进度保存（下次打开继续）
□ 深色/浅色模式跟随系统（M3动态色）
七、给AI的补充指令（避免常见陷阱）
文件路径处理：所有路径存储使用相对路径（相对于应用根目录），避免硬编码绝对路径。

缩略图生成：在后台Isolate中异步生成，不阻塞UI，且生成后更新数据库thumbnail_path。

iOS权限：须在Info.plist中添加NSPhotoLibraryUsageDescription和NSFileProviderDomainUsageDescription。

C++集成：提供CMakeLists.txt和iOS桥接头文件，使用cgo风格导出函数，确保跨平台编译通过。

状态管理：使用Riverpod或Provider（AI自选，但需保持全局状态清晰），避免深层嵌套传递。

八、交付物要求（AI输出应包含）
完整可编译的Flutter项目源码（包含android/和ios/原生配置）

CMakeLists.txt 和 C++源文件（用于FFI）

数据库迁移脚本（初始建表）

一份README.md，说明如何运行、编译、导入测试文件

一份ARCHITECTURE.md，描述各模块交互关系（含时序图文字描述）

