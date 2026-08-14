/*
 * fs_internal.h - file 模块核心层内部声明
 *
 * 这些是 file_ops_* 底层核心实现，仅在本库内部使用
 * （file_ops_core.cpp 定义、file_ops_ffi.cpp 调用）。
 * 不作为公共 API 对外暴露，Dart 通过 file_* JSON 接口调用。
 */

#ifndef FILE_FS_INTERNAL_H
#define FILE_FS_INTERNAL_H

#include "file/file.h"
#include "common/common.h"

#ifdef __cplusplus
extern "C" {
#endif

DirListResult* file_ops_list_directory(const char *path, bool show_hidden);
void file_ops_free_dir_list(DirListResult *result);

FileInfo* file_ops_get_file_info(const char *path);
void file_ops_free_file_info(FileInfo *info);

int file_ops_create_directory(const char *path, char *error, int error_size);
int file_ops_create_file(const char *path, char *error, int error_size);
int file_ops_delete_file(const char *path, char *error, int error_size);
int file_ops_delete_directory(const char *path, bool recursive, char *error, int error_size);
int file_ops_rename(const char *old_path, const char *new_path, char *error, int error_size);
int file_ops_copy_file(const char *src, const char *dst, char *error, int error_size);
int file_ops_move_file(const char *src, const char *dst, char *error, int error_size);
int file_ops_exists(const char *path);
int file_ops_is_directory(const char *path);

int file_ops_access(const char *path, int mode);
int file_ops_chmod(const char *path, uint32_t mode, char *error, int error_size);
int file_ops_chown(const char *path, uint32_t uid, uint32_t gid, char *error, int error_size);
int file_ops_lchown(const char *path, uint32_t uid, uint32_t gid, char *error, int error_size);
int file_ops_symlink(const char *target, const char *linkpath, char *error, int error_size);
int file_ops_link(const char *oldpath, const char *newpath, char *error, int error_size);
const char* file_ops_realpath(const char *path);
const char* file_ops_readlink(const char *path);

SearchResultList* file_ops_search_files(const char *dir, const char *pattern, int max_results);
void file_ops_free_search_results(SearchResultList *result);

HashResult* file_ops_compute_hash(const char *path);
void file_ops_free_hash_result(HashResult *result);

DiskUsageInfo* file_ops_get_disk_usage(const char *path);
void file_ops_free_disk_usage(DiskUsageInfo *info);

const char* file_ops_get_mime_type(const char *filename);
const char* file_ops_get_home_dir(void);
const char* file_ops_get_root_dir(void);
void file_ops_free_string(const char *str);

SearchResultList* file_ops_find_duplicates(const char *dir, int max_results);
SearchResultList* file_ops_find_empty_files(const char *dir, int max_results);
SearchResultList* file_ops_get_recent_files(const char *dir, int days, int max_results);

int file_ops_encrypt_file(const char *src, const char *dst, const char *password, char *error, int error_size);
int file_ops_decrypt_file(const char *src, const char *dst, const char *password, char *error, int error_size);

char* file_ops_read_file_text(const char *path);
int file_ops_write_file_text(const char *path, const char *content, char *error, int error_size);
unsigned char* file_ops_read_file_chunk(const char *path, int64_t offset, int length, int *out_len);
unsigned char* file_ops_read_file_bytes(const char *path, int *out_len);

const char* file_ops_detect_encoding(const char *path);
int file_ops_text_stats(const char *path, long long *bytes, long long *chars, long long *lines, long long *words);
int file_ops_compare_files(const char *path_a, const char *path_b, int *equal, long long *first_diff);
int file_ops_split_file(const char *path, long long part_size, const char *out_dir, char *error, int error_size);
int file_ops_merge_files(const char *parts_dir, const char *base_name, const char *out_path, char *error, int error_size);

#ifdef __cplusplus
}
#endif

#endif // FILE_FS_INTERNAL_H
