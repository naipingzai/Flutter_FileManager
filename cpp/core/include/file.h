/*
 * file.h - file 模块对 Dart 的统一 C API
 *
 * 提供：
 *   - 目录/文件列表（JSON）
 *   - 文件信息（JSON）
 *   - 搜索/去重/最近文件（JSON）
 *   - 文件操作（创建/删除/重命名/复制/移动）
 *   - 权限/链接操作
 *   - 哈希计算（MD5/SHA1/SHA256/SHA512/CRC32）
 *   - 加密/解密（AES-256-CBC）
 *   - 文本文件读写、CSV 解析、十六进制块、二进制 base64
 *
 * 所有函数返回 JSON 字符串或操作状态。
 * 平台差异由 core/ + platform/<os>/ 处理。
 */

#ifndef FILE_FILE_H
#define FILE_FILE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// 公共 JSON API（对 Dart FFI 主入口）
// 返回 JSON 字符串，调用方必须 file_free_json() 释放。
// ============================================================

char *file_list_directory(const char *path, int show_hidden);
char *file_get_file_info(const char *path);
char *file_search_files(const char *dir, const char *pattern, int max_results);
char *file_compute_hash(const char *path);
char *file_get_disk_usage(const char *path);
char *file_find_duplicates(const char *dir, int max_results);
char *file_find_empty_files(const char *dir, int max_results);
char *file_get_home_dir(void);
char *file_get_root_dir(void);
char *file_get_recent_files(const char *dir, int days, int max_results);

int file_create_directory(const char *path, char *error, int error_size);
int file_create_file(const char *path, char *error, int error_size);
int file_delete_file(const char *path, char *error, int error_size);
int file_rename(const char *old_path, const char *new_path, char *error, int error_size);
int file_copy_file(const char *src, const char *dst, char *error, int error_size);
int file_move_file(const char *src, const char *dst, char *error, int error_size);
int file_exists(const char *path);
int file_is_directory(const char *path);

int file_access(const char *path, int mode);
int file_chmod(const char *path, uint32_t mode, char *error, int error_size);
int file_chown(const char *path, uint32_t uid, uint32_t gid, char *error, int error_size);
int file_lchown(const char *path, uint32_t uid, uint32_t gid, char *error, int error_size);
int file_symlink(const char *target, const char *linkpath, char *error, int error_size);
int file_link(const char *oldpath, const char *newpath, char *error, int error_size);
char *file_realpath(const char *path);
char *file_readlink(const char *path);

int file_encrypt_file(const char *src, const char *dst, const char *password, char *error, int error_size);
int file_decrypt_file(const char *src, const char *dst, const char *password, char *error, int error_size);

char *file_read_text_file(const char *path);
int file_write_text_file(const char *path, const char *content, char *error, int error_size);
char *file_read_csv_file(const char *path);
char *file_read_hex_chunk(const char *path, long long offset, int length);
char *file_read_image_as_base64(const char *path);
char *file_read_binary_as_base64(const char *path);

char *file_detect_encoding(const char *path);
char *file_text_stats(const char *path);
char *file_compare_files(const char *path_a, const char *path_b);
int file_split_file(const char *path, long long part_size, const char *out_dir, char *error, int error_size);
int file_merge_files(const char *parts_dir, const char *base_name, const char *out_path, char *error, int error_size);

void file_free_json(char *json);

#ifdef __cplusplus
}
#endif

#endif // FILE_FILE_H
