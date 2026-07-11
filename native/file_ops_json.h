#ifndef FILE_OPS_JSON_H
#define FILE_OPS_JSON_H
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// All functions return JSON strings. Caller must free with file_ops_free_json().

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

void file_ops_free_json(char* json);

#ifdef __cplusplus
}
#endif

#endif // FILE_OPS_JSON_H
