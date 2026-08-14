# 文件管理器架构：数据库 + 导入 + 标签系统

> 核心转变：文件管理器**不再直接访问系统文件**，而是把文件**导入内部数据库**
> （含复制到应用私有目录）后，基于数据库进行管理、展示、检索。适用于所有平台
> （尤其 iOS 无法直接访问系统文件，必须经导入）。

## 1. 总体流程

```
系统文件 / 相册 / 分享
        │  import_file()
        ▼
┌─────────────────────────────────────────────┐
│  Import Service（core/database）            │
│  1. 把源文件复制进应用私有目录 app_data/files/  │
│  2. 解析元数据（名称/大小/类型/来源/时间）       │
│  3. 写入数据库 files 表                        │
│  4. 打上默认标签（按类型/来源）                 │
└─────────────────────────────────────────────┘
        ▼
┌─────────────────────────────────────────────┐
│  Database（core/database）                  │
│   files / tags / file_tags 三张关系表        │
└─────────────────────────────────────────────┘
        ▼
┌─────────────────────────────────────────────┐
│  文件管理 UI（列表 / 标签视图 / 搜索 / 新建目录）│
│  标签：默认标签、多文件批量加标签、按标签过滤      │
└─────────────────────────────────────────────┘
```

## 2. 数据库设计（SQLite，预编译库，后续 vendor 进 third_party）

三张表：

```sql
-- 导入的文件
CREATE TABLE files (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid          TEXT UNIQUE,             -- 内部唯一 id
    name          TEXT NOT NULL,           -- 显示名
    ext           TEXT,                    -- 扩展名（不含点）
    mime          TEXT,                    -- MIME 类型
    size          INTEGER DEFAULT 0,
    internal_path TEXT NOT NULL,           -- 应用私有目录内的实际路径
    source_path   TEXT,                    -- 导入来源（系统路径/相册）
    source_type   TEXT,                    -- filesystem | photos | share | ...
    is_dir        INTEGER DEFAULT 0,
    parent_id     INTEGER,                 -- 内部目录树（新建目录/移动用）
    import_time   INTEGER,                 -- 导入时间(epoch)
    created_time  INTEGER,
    modified_time INTEGER,
    deleted       INTEGER DEFAULT 0
);

-- 标签
CREATE TABLE tags (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    name  TEXT UNIQUE NOT NULL,
    color TEXT,
    builtin INTEGER DEFAULT 0              -- 系统内置默认标签
);

-- 文件-标签（多对多）
CREATE TABLE file_tags (
    file_id INTEGER NOT NULL,
    tag_id  INTEGER NOT NULL,
    PRIMARY KEY (file_id, tag_id),
    FOREIGN KEY(file_id) REFERENCES files(id),
    FOREIGN KEY(tag_id)  REFERENCES tags(id)
);
```

> 说明：当前先在 native 层用轻量嵌入式存储实现等价逻辑（可持久化、支持关系查询），
> 之后把 SQLite 预编译库 vendor 进 `third_party/`，替换为真 SQL，接口不变。

## 3. 标签系统（核心）

- **默认标签**：导入时按文件类型/来源自动添加，例如：`图片`、`视频`、`音频`、
  `文档`、`压缩包`、`电子书`、`代码`、`相册导入`、`系统导入`。
- **批量加标签**：选中多个文件 → 一次性添加一个或多个标签（`db_tag_add_to_files`）。
- **按标签过滤**：点标签 → 列出所有带该标签的文件。
- **标签管理**：新建、改色、重命名、删除。

## 4. 目录与移动（数据库内）

- 导入的文件进入库内"未分类"（根目录）。
- 支持在库内 `db_mkdir` 新建目录、`db_move` 移动文件到目录 —— 全部改的是
  `files.parent_id`，不直接动系统文件。

## 5. native 模块（core/database）

```
core/database/
  database.h        FFI 统一接口
  database.cpp      数据库 + 导入 + 标签实现
  store.h           （私有）嵌入式存储
```

FFI 入口（前缀 `db_`）：

| 函数 | 说明 |
|------|------|
| `db_init(data_dir)` | 初始化/打开数据库 |
| `db_import_file(src, default_tags)` | 导入文件，打默认标签 |
| `db_list_files(parent_id)` | 列出库内文件（JSON） |
| `db_list_all()` | 全部文件 |
| `db_mkdir(name, parent_id)` | 库内新建目录 |
| `db_move(file_id, new_parent_id)` | 库内移动 |
| `db_rename(file_id, name)` | 重命名 |
| `db_delete(file_id)` | 逻辑删除 |
| `db_tag_list()` | 所有标签 |
| `db_tag_create(name, color)` | 新建标签 |
| `db_tag_add_to_files(file_ids, tag_ids)` | **多文件批量加标签** |
| `db_tag_remove_from_file(file_id, tag_id)` | 移除某文件标签 |
| `db_files_by_tag(tag_id)` | 按标签查文件 |
| `db_file_tags(file_id)` | 某文件的标签 |

## 6. 平台差异

所有平台共用一套 `core/database` + `core/import` 逻辑；唯一平台相关的是
"获取系统文件/相册的读取能力"，放 `platform/<os>/`：

| 平台 | 导入来源 |
|------|---------|
| Android | MediaStore 相册 + SAF 文件（原生） |
| iOS | Photos 相册 + Files App（原生，经 FFI） |
| Windows/Linux/macOS | 文件选择器（原生） |
