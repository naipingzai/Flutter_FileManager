#ifndef CORE_H
#define CORE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// File type enum
// ============================================================
typedef enum {
    FILE_TYPE_UNKNOWN = 0,
    FILE_TYPE_REGULAR = 1,
    FILE_TYPE_DIRECTORY = 2,
    FILE_TYPE_SYMLINK = 3,
    FILE_TYPE_SOCKET = 4,
    FILE_TYPE_FIFO = 5,
    FILE_TYPE_BLOCK_DEVICE = 6,
    FILE_TYPE_CHAR_DEVICE = 7,
} FileType;

// ============================================================
// File info struct
// ============================================================
typedef struct {
    char name[256];
    char path[1024];
    char symlink_target[1024];
    FileType type;
    int64_t size;
    int64_t modified_time;
    int64_t access_time;
    int64_t created_time;
    uint32_t permissions;
    uint32_t uid;
    uint32_t gid;
    char owner_name[64];
    char group_name[64];
    char mime_type[128];
    bool is_readable;
    bool is_writable;
    bool is_executable;
    bool is_hidden;
} FileInfo;

// ============================================================
// Directory listing result
// ============================================================
typedef struct {
    FileInfo *items;
    int count;
    int capacity;
    char error[256];
} DirListResult;

// ============================================================
// Search result
// ============================================================
typedef struct {
    char path[1024];
    char name[256];
    FileType type;
    int64_t size;
    int64_t modified_time;
} SearchResult;

typedef struct {
    SearchResult *items;
    int count;
    int capacity;
    char error[256];
} SearchResultList;

// ============================================================
// Hash result
// ============================================================
typedef struct {
    char md5[65];
    char sha1[65];
    char sha256[65];
    char sha512[129];
    char crc32[17];
    char error[256];
} HashResult;

// ============================================================
// Disk usage info
// ============================================================
typedef struct {
    int64_t total_space;
    int64_t free_space;
    int64_t used_space;
    char error[256];
} DiskUsageInfo;

// ============================================================
// ====================  TEXT OPERATIONS  =====================
// ============================================================
// Large text file efficient reader with line index support.
typedef void* TextOpsHandle;

TextOpsHandle text_ops_create(void);
void text_ops_destroy(TextOpsHandle handle);
int text_ops_open(TextOpsHandle handle, const char* path);
void text_ops_close(TextOpsHandle handle);
int text_ops_is_open(TextOpsHandle handle);
size_t text_ops_size(TextOpsHandle handle);
const char* text_ops_path(TextOpsHandle handle);
size_t text_ops_read(
    TextOpsHandle handle,
    size_t offset,
    size_t length,
    unsigned char* buffer,
    size_t buffer_size);
size_t text_ops_line_count(TextOpsHandle handle);
size_t text_ops_read_line(
    TextOpsHandle handle,
    size_t line,
    unsigned char* buffer,
    size_t buffer_size);
const char* text_ops_error(TextOpsHandle handle);

// ============================================================
// ====================  FILE OPERATIONS  =====================
// ============================================================

// Core file operations
DirListResult* file_ops_list_directory(const char *path, bool show_hidden);
void file_ops_free_dir_list(DirListResult *result);

FileInfo* file_ops_get_file_info(const char *path);
void file_ops_free_file_info(FileInfo *info);

// File operations
int file_ops_create_directory(const char *path, char *error, int error_size);
int file_ops_create_file(const char *path, char *error, int error_size);
int file_ops_delete_file(const char *path, char *error, int error_size);
int file_ops_delete_directory(const char *path, bool recursive, char *error, int error_size);
int file_ops_rename(const char *old_path, const char *new_path, char *error, int error_size);
int file_ops_copy_file(const char *src, const char *dst, char *error, int error_size);
int file_ops_move_file(const char *src, const char *dst, char *error, int error_size);
int file_ops_exists(const char *path);
int file_ops_is_directory(const char *path);

// Permissions
int file_ops_access(const char *path, int mode);
int file_ops_chmod(const char *path, uint32_t mode, char *error, int error_size);
int file_ops_chown(const char *path, uint32_t uid, uint32_t gid, char *error, int error_size);
int file_ops_lchown(const char *path, uint32_t uid, uint32_t gid, char *error, int error_size);
int file_ops_symlink(const char *target, const char *linkpath, char *error, int error_size);
int file_ops_link(const char *oldpath, const char *newpath, char *error, int error_size);
const char* file_ops_realpath(const char *path);
const char* file_ops_readlink(const char *path);

// Search
SearchResultList* file_ops_search_files(const char *dir, const char *pattern, int max_results);
void file_ops_free_search_results(SearchResultList *result);

// Hash
HashResult* file_ops_compute_hash(const char *path);
void file_ops_free_hash_result(HashResult *result);

// Disk usage
DiskUsageInfo* file_ops_get_disk_usage(const char *path);
void file_ops_free_disk_usage(DiskUsageInfo *info);

// Utility
const char* file_ops_get_mime_type(const char *filename);
const char* file_ops_get_home_dir(void);
const char* file_ops_get_root_dir(void);
void file_ops_free_string(const char *str);

// Duplicate finder
SearchResultList* file_ops_find_duplicates(const char *dir, int max_results);
SearchResultList* file_ops_find_empty_files(const char *dir, int max_results);

// Recent files
SearchResultList* file_ops_get_recent_files(const char *dir, int days, int max_results);

// Encryption / Decryption (AES-256-CBC)
int file_ops_encrypt_file(const char *src, const char *dst, const char *password, char *error, int error_size);
int file_ops_decrypt_file(const char *src, const char *dst, const char *password, char *error, int error_size);

// File content I/O (raw reads for viewers)
char* file_ops_read_file_text(const char *path);
int file_ops_write_file_text(const char *path, const char *content, char *error, int error_size);
unsigned char* file_ops_read_file_chunk(const char *path, int64_t offset, int length, int *out_len);
unsigned char* file_ops_read_file_bytes(const char *path, int *out_len);

// ============================================================
// ====================  FILE TOOLS (core)  ====================
// 纯 C++ 内部实现，无系统依赖，全平台可用
// ============================================================

// 文本编码检测（BOM + 内容启发式），返回 "utf-8|utf-16le|utf-16be|gbk|ascii|binary|unknown"
const char* file_ops_detect_encoding(const char *path);

// 文本统计（字节 / 字符 / 行 / 单词数）。返回 0=成功
int file_ops_text_stats(const char *path, long long *bytes, long long *chars, long long *lines, long long *words);

// 逐字节比较两个文件。equal=1 表示相同，first_diff 为第一个不同字节偏移。返回 0=成功
int file_ops_compare_files(const char *path_a, const char *path_b, int *equal, long long *first_diff);

// 按 part_size 字节分割文件为 <out_dir>/<base>.part.NNNN。返回 0=成功
int file_ops_split_file(const char *path, long long part_size, const char *out_dir, char *error, int error_size);

// 合并 <parts_dir> 中 <base_name>.part.NNNN 分片到 out_path。返回 0=成功
int file_ops_merge_files(const char *parts_dir, const char *base_name, const char *out_path, char *error, int error_size);

// ============================================================
// ====================  JSON WRAPPER API  ====================
// ============================================================

// All JSON functions return JSON strings. Caller must free with file_ops_free_json().
char* file_ops_json_list_directory(const char* path, int show_hidden);
char* file_ops_json_get_file_info(const char* path);
char* file_ops_json_search_files(const char* dir, const char* pattern, int max_results);
char* file_ops_json_compute_hash(const char* path);
char* file_ops_json_get_disk_usage(const char* path);
char* file_ops_json_find_duplicates(const char* dir, int max_results);
char* file_ops_json_find_empty_files(const char* dir, int max_results);
char* file_ops_json_get_home_dir(void);
char* file_ops_json_get_root_dir(void);

int file_ops_json_create_directory(const char* path, char* error, int error_size);
int file_ops_json_create_file(const char* path, char* error, int error_size);
int file_ops_json_delete_file(const char* path, char* error, int error_size);
int file_ops_json_rename(const char* old_path, const char* new_path, char* error, int error_size);
int file_ops_json_copy_file(const char* src, const char* dst, char* error, int error_size);
int file_ops_json_move_file(const char* src, const char* dst, char* error, int error_size);
int file_ops_json_exists(const char* path);
int file_ops_json_is_directory(const char* path);

int file_ops_json_access(const char* path, int mode);
int file_ops_json_chown(const char* path, uint32_t uid, uint32_t gid, char* error, int error_size);
int file_ops_json_lchown(const char* path, uint32_t uid, uint32_t gid, char* error, int error_size);
int file_ops_json_symlink(const char* target, const char* linkpath, char* error, int error_size);
int file_ops_json_link(const char* oldpath, const char* newpath, char* error, int error_size);
char* file_ops_json_realpath(const char* path);
char* file_ops_json_readlink(const char* path);

// Recent files
char* file_ops_json_get_recent_files(const char* dir, int days, int max_results);

// Encryption / Decryption
int file_ops_json_encrypt_file(const char* src, const char* dst, const char* password, char* error, int error_size);
int file_ops_json_decrypt_file(const char* src, const char* dst, const char* password, char* error, int error_size);

// File content I/O (for viewers)
char* file_ops_json_read_text_file(const char* path);
int file_ops_json_write_text_file(const char* path, const char* content, char* error, int error_size);
char* file_ops_json_read_csv_file(const char* path);
char* file_ops_json_read_hex_chunk(const char* path, long long offset, int length);
char* file_ops_json_read_image_as_base64(const char* path);
// 通用二进制读取（视频/音频/PDF/电子书等所有 viewer 用）
char* file_ops_json_read_binary_as_base64(const char* path);

// ============================================================
// ====================  FILE TOOL API (JSON)  =================
// 全部文件类型工具：编码检测 / 文本统计 / 权限修改 /
// 文件比较 / 文件分割 / 文件合并（纯 C++ 内部实现，无系统依赖）
// ============================================================

// 修改文件权限（chmod）。返回 int (0=成功)
int file_ops_json_chmod(const char* path, uint32_t mode, char* error, int error_size);

// 文本编码检测（BOM + 内容启发式）。
// 返回 JSON：{"error":"","encoding":"utf-8|utf-16le|utf-16be|gbk|ascii|binary"}
char* file_ops_json_detect_encoding(const char* path);

// 文本统计（字节 / 字符 / 行 / 单词数）。
// 返回 JSON：{"error":"","bytes":n,"chars":n,"lines":n,"words":n}
char* file_ops_json_text_stats(const char* path);

// 逐字节比较两个文件。
// 返回 JSON：{"error":"","equal":bool,"sizeA":n,"sizeB":n,"firstDiff":n}
char* file_ops_json_compare_files(const char* path_a, const char* path_b);

// 按指定大小分割文件为 <out_dir>/<base>.part.NNNN 分片。
// 返回 int (0=成功)，成功后在 out_dir 中生成分片文件。
int file_ops_json_split_file(const char* path, long long part_size, const char* out_dir, char* error, int error_size);

// 合并 <parts_dir> 中按顺序命名的 <base_name>.part.NNNN 分片到 out_path。
// 返回 int (0=成功)。
int file_ops_json_merge_files(const char* parts_dir, const char* base_name, const char* out_path, char* error, int error_size);

void file_ops_free_json(char* json);

#ifdef __cplusplus
}
#endif

#endif // CORE_H
