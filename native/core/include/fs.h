#ifndef FS_H
#define FS_H

/*
 * fs.h - core 静态库统一公共 C API
 *
 * 设计约定：
 *   - fs_*          JSON 封装接口（Dart 通过 FFI 调用的主入口）
 *   - fs_text_*     大文本文件读取器（行索引 / 分块读取）
 *   - file_ops_*    核心底层实现（内部使用，见 src/fs_internal.h，不对外导出）
 *
 * 所有 fs_* 函数返回 JSON 字符串，调用方必须用 fs_free_json() 释放。
 */

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
// 大文本文件读取器句柄（行索引 / 分块读取）
// ============================================================
typedef void* FsTextReader;

// 创建 / 销毁读取器
FsTextReader fs_text_create(void);
void fs_text_destroy(FsTextReader handle);
// 打开文件并建立行索引。成功返回 0。
int fs_text_open(FsTextReader handle, const char* path);
void fs_text_close(FsTextReader handle);
int fs_text_is_open(FsTextReader handle);
size_t fs_text_size(FsTextReader handle);
const char* fs_text_path(FsTextReader handle);
// 按字节偏移读取 [offset, offset+length)，返回实际读取字节数
size_t fs_text_read(FsTextReader handle, size_t offset, size_t length,
                    unsigned char* buffer, size_t buffer_size);
size_t fs_text_line_count(FsTextReader handle);
// 读取指定行（0-based，不含换行符），返回实际字节数
size_t fs_text_read_line(FsTextReader handle, size_t line,
                         unsigned char* buffer, size_t buffer_size);
const char* fs_text_error(FsTextReader handle);

// ============================================================
// JSON 封装 API（Dart FFI 主入口）
// 返回 JSON 字符串，调用方必须用 fs_free_json() 释放。
// ============================================================

char* fs_list_directory(const char* path, int show_hidden);
char* fs_get_file_info(const char* path);
char* fs_search_files(const char* dir, const char* pattern, int max_results);
char* fs_compute_hash(const char* path);
char* fs_get_disk_usage(const char* path);
char* fs_find_duplicates(const char* dir, int max_results);
char* fs_find_empty_files(const char* dir, int max_results);
char* fs_get_home_dir(void);
char* fs_get_root_dir(void);
char* fs_get_recent_files(const char* dir, int days, int max_results);

int fs_create_directory(const char* path, char* error, int error_size);
int fs_create_file(const char* path, char* error, int error_size);
int fs_delete_file(const char* path, char* error, int error_size);
int fs_rename(const char* old_path, const char* new_path, char* error, int error_size);
int fs_copy_file(const char* src, const char* dst, char* error, int error_size);
int fs_move_file(const char* src, const char* dst, char* error, int error_size);
int fs_exists(const char* path);
int fs_is_directory(const char* path);

int fs_access(const char* path, int mode);
int fs_chmod(const char* path, uint32_t mode, char* error, int error_size);
int fs_chown(const char* path, uint32_t uid, uint32_t gid, char* error, int error_size);
int fs_lchown(const char* path, uint32_t uid, uint32_t gid, char* error, int error_size);
int fs_symlink(const char* target, const char* linkpath, char* error, int error_size);
int fs_link(const char* oldpath, const char* newpath, char* error, int error_size);
char* fs_realpath(const char* path);
char* fs_readlink(const char* path);

int fs_encrypt_file(const char* src, const char* dst, const char* password, char* error, int error_size);
int fs_decrypt_file(const char* src, const char* dst, const char* password, char* error, int error_size);

char* fs_read_text_file(const char* path);
int fs_write_text_file(const char* path, const char* content, char* error, int error_size);
char* fs_read_csv_file(const char* path);
char* fs_read_hex_chunk(const char* path, long long offset, int length);
char* fs_read_image_as_base64(const char* path);
char* fs_read_binary_as_base64(const char* path);

char* fs_detect_encoding(const char* path);
char* fs_text_stats(const char* path);
char* fs_compare_files(const char* path_a, const char* path_b);
int fs_split_file(const char* path, long long part_size, const char* out_dir, char* error, int error_size);
int fs_merge_files(const char* parts_dir, const char* base_name, const char* out_path, char* error, int error_size);

void fs_free_json(char* json);

#ifdef __cplusplus
}
#endif

#endif // FS_H
