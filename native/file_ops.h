#ifndef FILE_OPS_H
#define FILE_OPS_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// File type enum
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

// File info struct
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

// Directory listing result
typedef struct {
    FileInfo *items;
    int count;
    int capacity;
    char error[256];
} DirListResult;

// Search result
typedef struct {
    char path[1024];
    char name[256];
    FileType type;
    int64_t size;
    int64_t modified_time;
} SearchResult;

// Search results container
typedef struct {
    SearchResult *items;
    int count;
    int capacity;
    char error[256];
} SearchResultList;

// Hash result
typedef struct {
    char md5[65];
    char sha1[65];
    char sha256[65];
    char sha512[129];
    char crc32[17];
    char error[256];
} HashResult;

// Disk usage info
typedef struct {
    int64_t total_space;
    int64_t free_space;
    int64_t used_space;
    char error[256];
} DiskUsageInfo;

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

// Permissions (from Syscall.kt:28,31,34)
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

#ifdef __cplusplus
}
#endif

#endif // FILE_OPS_H
