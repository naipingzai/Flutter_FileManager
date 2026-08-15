/*
 * database.h - database 模块统一 C API
 *
 * 文件管理器的核心：把系统文件「导入」到内部数据库后，基于数据库
 * 进行管理、展示、检索，而非直接访问系统文件（尤其 iOS 无法直接访问）。
 *
 * 三张关系表：files / tags / file_tags
 * 当前用轻量嵌入式存储实现（持久化到 data_dir/files.db），
 * 后续可替换为 SQLite 预编译库（接口不变，见 docs/architecture.md）。
 *
 * 所有函数返回 malloc 的 JSON 字符串，调用方用 db_free_string 释放。
 * 数据目录由 db_init 传入（应用私有目录）。
 */
#ifndef CORE_DATABASE_H
#define CORE_DATABASE_H

#ifdef __cplusplus
extern "C" {
#endif

// 初始化/打开数据库（data_dir 为应用私有数据目录）。返回 {"error":""} 或错误信息。
char *db_init(const char *data_dir);

// 导入文件：把 src 复制进内部 files/ 目录，写入记录并打默认标签。
// default_tags: 逗号分隔的标签名（如 "图片,系统导入"）。
// 返回该文件记录的 JSON。
char *db_import_file(const char *src, const char *default_tags);

// 列出库内指定父目录下的文件/目录（parent_id<0 表示全部）。
char *db_list_files(int parent_id);

// 列出全部文件。
char *db_list_all(void);

// 按名称/扩展名模糊搜索库内文件。
char *db_search(const char *query);

// 批量导入文件夹（递归导入其中文件）。返回 JSON：{"error":"","imported":n,"failed":n}
char *db_import_dir(const char *dir, const char *default_tags);

// 库内统计。返回 JSON：files/dirs/size/byType/byTag。
char *db_stats(void);

// 库内新建目录。返回目录记录 JSON。
char *db_mkdir(const char *name, int parent_id);

// 库内移动文件/目录到新父目录。
char *db_move(int file_id, int new_parent_id);

// 重命名库内文件/目录。
char *db_rename(int file_id, const char *name);

// 逻辑删除（deleted=1）。
char *db_delete(int file_id);

// 导出：把内部文件复制到 dest（系统位置）。返回 JSON：{"error":"","path":"..."}
char *db_export_file(int file_id, const char *dest);

// 所有标签列表。
char *db_tag_list(void);

// 标签列表（含每个标签的文件计数）。
char *db_tag_counts(void);

// 重命名标签。
char *db_tag_rename(int tag_id, const char *name);

// 设置标签颜色。
char *db_tag_set_color(int tag_id, const char *color);

// 新建标签。返回标签 JSON。
char *db_tag_create(const char *name, const char *color);

// 批量给多个文件添加多个标签（file_ids/tag_ids 为逗号分隔的 id 列表）。
char *db_tag_add_to_files(const char *file_ids, const char *tag_ids);

// 从某文件移除某标签。
char *db_tag_remove_from_file(int file_id, int tag_id);

// 删除标签（同时清理 file_tags 关联）。
char *db_tag_delete(int tag_id);

// 按标签查询文件列表。
char *db_files_by_tag(int tag_id);

// 某文件的标签列表。
char *db_file_tags(int file_id);

// 释放 db_* 返回的字符串。
void db_free_string(char *str);

#ifdef __cplusplus
}
#endif

#endif // CORE_DATABASE_H
