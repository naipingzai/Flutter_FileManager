/*
 * file_ops_ffi.cpp - file 模块 FFI 层
 *
 * 调用 core 层的 file_ops_* 接口，使用 common JsonBuilder
 * 生成 JSON 返回给 Dart FFI。
 *
 * 对 Dart 暴露的 API 前缀：file_*
 */

#include "file/file.h"
#include "file_internal.h"
#include "common/json_builder.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ============================================================
// JSON 辅助：FileInfo → JSON 对象
// ============================================================
static void fi_to_json(JsonBuilder *jb, const FileInfo *i) {
    jb_append_str(jb, "{\"name\":");      jb_append_esc(jb, i->name);
    jb_append_str(jb, ",\"path\":");      jb_append_esc(jb, i->path);
    jb_append_str(jb, ",\"symlinkTarget\":"); jb_append_esc(jb, i->symlink_target);
    jb_append_str(jb, ",\"type\":");      jb_append_int(jb, i->type);
    jb_append_str(jb, ",\"size\":");      jb_append_int(jb, i->size);
    jb_append_str(jb, ",\"modifiedTime\":"); jb_append_int(jb, i->modified_time);
    jb_append_str(jb, ",\"accessTime\":");jb_append_int(jb, i->access_time);
    jb_append_str(jb, ",\"createdTime\":");jb_append_int(jb, i->created_time);
    jb_append_str(jb, ",\"permissions\":");jb_append_int(jb, i->permissions);
    jb_append_str(jb, ",\"uid\":");       jb_append_int(jb, i->uid);
    jb_append_str(jb, ",\"gid\":");       jb_append_int(jb, i->gid);
    jb_append_str(jb, ",\"ownerName\":"); jb_append_esc(jb, i->owner_name);
    jb_append_str(jb, ",\"groupName\":"); jb_append_esc(jb, i->group_name);
    jb_append_str(jb, ",\"mimeType\":");  jb_append_esc(jb, i->mime_type);
    jb_append_str(jb, ",\"isReadable\":");jb_append_bool(jb, i->is_readable);
    jb_append_str(jb, ",\"isWritable\":");jb_append_bool(jb, i->is_writable);
    jb_append_str(jb, ",\"isExecutable\":");jb_append_bool(jb, i->is_executable);
    jb_append_str(jb, ",\"isHidden\":");  jb_append_bool(jb, i->is_hidden);
    jb_append_str(jb, "}");
}

extern "C" {

// ============================================================
// 目录/文件列表
// ============================================================
char *file_list_directory(const char *path, int show_hidden) {
    JsonBuilder jb = jb_new();
    DirListResult *r = file_ops_list_directory(path, show_hidden != 0);
    if (!r) {
        jb_append_str(&jb, "{\"error\":\"null\",\"items\":[]}");
        return jb_finish(&jb);
    }
    if (r->error[0]) {
        jb_append_str(&jb, "{\"error\":");
        jb_append_esc(&jb, r->error);
        jb_append_str(&jb, ",\"items\":[]}");
        file_ops_free_dir_list(r);
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    for (int i = 0; i < r->count; i++) {
        if (i > 0) jb_append_str(&jb, ",");
        fi_to_json(&jb, &r->items[i]);
    }
    jb_append_str(&jb, "]}");
    file_ops_free_dir_list(r);
    return jb_finish(&jb);
}

char *file_get_file_info(const char *path) {
    JsonBuilder jb = jb_new();
    FileInfo *i = file_ops_get_file_info(path);
    if (!i) {
        jb_append_str(&jb, "{\"error\":\"not found\"}");
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"info\":");
    fi_to_json(&jb, i);
    jb_append_str(&jb, "}");
    file_ops_free_file_info(i);
    return jb_finish(&jb);
}

// ============================================================
// 搜索
// ============================================================
static void search_item_to_json(JsonBuilder *jb, const SearchResult *r, bool include_modified) {
    jb_append_str(jb, "{\"path\":");      jb_append_esc(jb, r->path);
    jb_append_str(jb, ",\"name\":");      jb_append_esc(jb, r->name);
    jb_append_str(jb, ",\"type\":");      jb_append_int(jb, r->type);
    jb_append_str(jb, ",\"size\":");      jb_append_int(jb, r->size);
    if (include_modified) {
        jb_append_str(jb, ",\"modifiedTime\":");
        jb_append_int(jb, r->modified_time);
    }
    jb_append_str(jb, "}");
}

char *file_search_files(const char *dir, const char *pattern, int max_results) {
    JsonBuilder jb = jb_new();
    SearchResultList *r = file_ops_search_files(dir, pattern, max_results);
    if (!r) {
        jb_append_str(&jb, "{\"error\":\"null\",\"items\":[]}");
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    for (int i = 0; i < r->count; i++) {
        if (i > 0) jb_append_str(&jb, ",");
        search_item_to_json(&jb, &r->items[i], true);
    }
    jb_append_str(&jb, "]}");
    file_ops_free_search_results(r);
    return jb_finish(&jb);
}

// ============================================================
// 哈希
// ============================================================
char *file_compute_hash(const char *path) {
    JsonBuilder jb = jb_new();
    HashResult *r = file_ops_compute_hash(path);
    if (!r) {
        jb_append_str(&jb, "{\"error\":\"failed\"}");
        return jb_finish(&jb);
    }
    if (r->error[0]) {
        jb_append_str(&jb, "{\"error\":");
        jb_append_esc(&jb, r->error);
        jb_append_str(&jb, "}");
        file_ops_free_hash_result(r);
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"md5\":");    jb_append_esc(&jb, r->md5);
    jb_append_str(&jb, ",\"sha1\":");   jb_append_esc(&jb, r->sha1);
    jb_append_str(&jb, ",\"sha256\":"); jb_append_esc(&jb, r->sha256);
    jb_append_str(&jb, ",\"sha512\":"); jb_append_esc(&jb, r->sha512);
    jb_append_str(&jb, ",\"crc32\":");  jb_append_esc(&jb, r->crc32);
    jb_append_str(&jb, "}");
    file_ops_free_hash_result(r);
    return jb_finish(&jb);
}

// ============================================================
// 磁盘用量
// ============================================================
char *file_get_disk_usage(const char *path) {
    JsonBuilder jb = jb_new();
    DiskUsageInfo *d = file_ops_get_disk_usage(path);
    if (!d) {
        jb_append_str(&jb, "{\"error\":\"failed\"}");
        return jb_finish(&jb);
    }
    if (d->error[0]) {
        jb_append_str(&jb, "{\"error\":");
        jb_append_esc(&jb, d->error);
        jb_append_str(&jb, "}");
        file_ops_free_disk_usage(d);
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"totalSpace\":");
    jb_append_int(&jb, d->total_space);
    jb_append_str(&jb, ",\"freeSpace\":");
    jb_append_int(&jb, d->free_space);
    jb_append_str(&jb, ",\"usedSpace\":");
    jb_append_int(&jb, d->used_space);
    jb_append_str(&jb, "}");
    file_ops_free_disk_usage(d);
    return jb_finish(&jb);
}

// ============================================================
// 去重 / 空文件 / 最近文件
// ============================================================
char *file_find_duplicates(const char *dir, int max_results) {
    JsonBuilder jb = jb_new();
    SearchResultList *r = file_ops_find_duplicates(dir, max_results);
    if (!r) {
        jb_append_str(&jb, "{\"error\":\"null\",\"items\":[]}");
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    for (int i = 0; i < r->count; i++) {
        if (i > 0) jb_append_str(&jb, ",");
        jb_append_str(&jb, "{\"path\":");  jb_append_esc(&jb, r->items[i].path);
        jb_append_str(&jb, ",\"name\":");  jb_append_esc(&jb, r->items[i].name);
        jb_append_str(&jb, ",\"size\":");  jb_append_int(&jb, r->items[i].size);
        jb_append_str(&jb, "}");
    }
    jb_append_str(&jb, "]}");
    file_ops_free_search_results(r);
    return jb_finish(&jb);
}

char *file_find_empty_files(const char *dir, int max_results) {
    JsonBuilder jb = jb_new();
    SearchResultList *r = file_ops_find_empty_files(dir, max_results);
    if (!r) {
        jb_append_str(&jb, "{\"error\":\"null\",\"items\":[]}");
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    for (int i = 0; i < r->count; i++) {
        if (i > 0) jb_append_str(&jb, ",");
        search_item_to_json(&jb, &r->items[i], false);
    }
    jb_append_str(&jb, "]}");
    file_ops_free_search_results(r);
    return jb_finish(&jb);
}

char *file_get_recent_files(const char *dir, int days, int max_results) {
    JsonBuilder jb = jb_new();
    SearchResultList *r = file_ops_get_recent_files(dir, days, max_results);
    if (!r) {
        jb_append_str(&jb, "{\"error\":\"null\",\"items\":[]}");
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    for (int i = 0; i < r->count; i++) {
        if (i > 0) jb_append_str(&jb, ",");
        search_item_to_json(&jb, &r->items[i], true);
    }
    jb_append_str(&jb, "]}");
    file_ops_free_search_results(r);
    return jb_finish(&jb);
}

// ============================================================
// 标准目录（home/root 路径）
// ============================================================
char *file_get_home_dir(void) {
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"path\":");
    jb_append_esc(&jb, file_ops_get_home_dir());
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

char *file_get_root_dir(void) {
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"path\":");
    jb_append_esc(&jb, file_ops_get_root_dir());
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

// ============================================================
// 文件操作（创建/删除/重命名/复制/移动/存在性）
// ============================================================
int file_create_directory(const char *path, char *error, int error_size) {
    return file_ops_create_directory(path, error, error_size);
}
int file_create_file(const char *path, char *error, int error_size) {
    return file_ops_create_file(path, error, error_size);
}
int file_delete_file(const char *path, char *error, int error_size) {
    return file_ops_delete_file(path, error, error_size);
}
int file_rename(const char *old_path, const char *new_path, char *error, int error_size) {
    return file_ops_rename(old_path, new_path, error, error_size);
}
int file_copy_file(const char *src, const char *dst, char *error, int error_size) {
    return file_ops_copy_file(src, dst, error, error_size);
}
int file_move_file(const char *src, const char *dst, char *error, int error_size) {
    return file_ops_move_file(src, dst, error, error_size);
}
int file_exists(const char *path)      { return file_ops_exists(path); }
int file_is_directory(const char *path){ return file_ops_is_directory(path); }

void file_free_json(char *json) { free(json); }

// ============================================================
// 权限/链接操作
// ============================================================
int file_access(const char *path, int mode) {
    return file_ops_access(path, mode);
}
int file_chmod(const char *path, uint32_t mode, char *error, int error_size) {
    return file_ops_chmod(path, mode, error, error_size);
}
int file_chown(const char *path, uint32_t uid, uint32_t gid, char *error, int error_size) {
    return file_ops_chown(path, uid, gid, error, error_size);
}
int file_lchown(const char *path, uint32_t uid, uint32_t gid, char *error, int error_size) {
    return file_ops_lchown(path, uid, gid, error, error_size);
}
int file_symlink(const char *target, const char *linkpath, char *error, int error_size) {
    return file_ops_symlink(target, linkpath, error, error_size);
}
int file_link(const char *oldpath, const char *newpath, char *error, int error_size) {
    return file_ops_link(oldpath, newpath, error, error_size);
}

char *file_realpath(const char *path) {
    JsonBuilder jb = jb_new();
    const char *rp = file_ops_realpath(path);
    jb_append_str(&jb, "{\"path\":");
    jb_append_esc(&jb, rp ? rp : "");
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

char *file_readlink(const char *path) {
    JsonBuilder jb = jb_new();
    const char *rl = file_ops_readlink(path);
    jb_append_str(&jb, "{\"target\":");
    jb_append_esc(&jb, rl ? rl : "");
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

// ============================================================
// 加密/解密
// ============================================================
int file_encrypt_file(const char *src, const char *dst, const char *password,
                      char *error, int error_size) {
    return file_ops_encrypt_file(src, dst, password, error, error_size);
}
int file_decrypt_file(const char *src, const char *dst, const char *password,
                      char *error, int error_size) {
    return file_ops_decrypt_file(src, dst, password, error, error_size);
}

// ============================================================
// 文件内容 I/O
// ============================================================
char *file_read_text_file(const char *path) {
    JsonBuilder jb = jb_new();
    char *text = file_ops_read_file_text(path);
    if (!text) {
        jb_append_str(&jb, "{\"error\":\"failed to read file\"}");
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"text\":");
    jb_append_esc(&jb, text);
    free(text);
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

int file_write_text_file(const char *path, const char *content, char *error, int error_size) {
    return file_ops_write_file_text(path, content, error, error_size);
}

char *file_read_csv_file(const char *path) {
    JsonBuilder jb = jb_new();
    char *text = file_ops_read_file_text(path);
    if (!text) {
        jb_append_str(&jb, "{\"error\":\"failed to read file\",\"rows\":[]}");
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"rows\":[");
    const char *p = text;
    int row_count = 0;
    while (*p) {
        if (row_count > 0) jb_append_str(&jb, ",");
        jb_append_str(&jb, "[");
        int col_count = 0;
        while (*p && *p != '\n') {
            if (col_count > 0) jb_append_str(&jb, ",");
            const char *start = p;
            while (*p && *p != ',' && *p != '\n') p++;
            char save = *p;
            *(char *)p = '\0';
            jb_append_esc(&jb, start);
            *(char *)p = save;
            col_count++;
            if (*p == ',') p++;
        }
        jb_append_str(&jb, "]");
        row_count++;
        if (*p == '\n') p++;
    }
    free(text);
    jb_append_str(&jb, "]}");
    return jb_finish(&jb);
}

char *file_read_hex_chunk(const char *path, long long offset, int length) {
    JsonBuilder jb = jb_new();
    int actual_len = 0;
    unsigned char *data = file_ops_read_file_chunk(path, offset, length, &actual_len);
    if (!data || actual_len == 0) {
        jb_append_str(&jb, "{\"error\":\"read failed\",\"hex\":\"\",\"ascii\":\"\",\"length\":0}");
        if (data) free(data);
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"hex\":\"");
    for (int i = 0; i < actual_len; i++) {
        char buf[4];
        snprintf(buf, sizeof(buf), "%02x", data[i]);
        jb_append_str(&jb, buf);
        if (i < actual_len - 1) jb_append_str(&jb, " ");
    }
    jb_append_str(&jb, "\",\"ascii\":\"");
    for (int i = 0; i < actual_len; i++) {
        unsigned char c = data[i];
        if (c >= 0x20 && c <= 0x7E) {
            char buf[2] = { (char)c, 0 };
            jb_append_str(&jb, buf);
        } else {
            jb_append_str(&jb, ".");
        }
    }
    char lenbuf[32];
    snprintf(lenbuf, sizeof(lenbuf), "\",\"length\":%d}", actual_len);
    jb_append_str(&jb, lenbuf);
    free(data);
    return jb_finish(&jb);
}

static const char b64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static char *make_base64(const unsigned char *data, int len) {
    int out_len = 4 * ((len + 2) / 3);
    char *b64 = (char *)malloc((size_t)out_len + 1);
    if (!b64) return nullptr;
    int i = 0, j = 0;
    while (i < len) {
        unsigned int a = i < len ? data[i++] : 0;
        unsigned int b = i < len ? data[i++] : 0;
        unsigned int c = i < len ? data[i++] : 0;
        unsigned int triple = (a << 16) | (b << 8) | c;
        b64[j++] = b64_table[(triple >> 18) & 0x3F];
        b64[j++] = b64_table[(triple >> 12) & 0x3F];
        b64[j++] = (i > len + 1) ? '=' : b64_table[(triple >> 6) & 0x3F];
        b64[j++] = (i > len) ? '=' : b64_table[triple & 0x3F];
    }
    b64[j] = '\0';
    return b64;
}

char *file_read_image_as_base64(const char *path) {
    JsonBuilder jb = jb_new();
    int data_len = 0;
    unsigned char *data = file_ops_read_file_bytes(path, &data_len);
    if (!data || data_len == 0) {
        jb_append_str(&jb, "{\"error\":\"read failed\",\"base64\":\"\"}");
        if (data) free(data);
        return jb_finish(&jb);
    }
    char *b64 = make_base64(data, data_len);
    free(data);
    if (!b64) {
        jb_append_str(&jb, "{\"error\":\"alloc failed\",\"base64\":\"\"}");
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"base64\":\"");
    jb_append_str(&jb, b64);
    char lenbuf[32];
    snprintf(lenbuf, sizeof(lenbuf), "\",\"length\":%d}", data_len);
    jb_append_str(&jb, lenbuf);
    free(b64);
    return jb_finish(&jb);
}

char *file_read_binary_as_base64(const char *path) {
    JsonBuilder jb = jb_new();
    int data_len = 0;
    unsigned char *data = file_ops_read_file_bytes(path, &data_len);
    if (!data || data_len == 0) {
        jb_append_str(&jb, "{\"error\":\"read failed\",\"base64\":\"\",\"length\":0}");
        if (data) free(data);
        return jb_finish(&jb);
    }
    char *b64 = make_base64(data, data_len);
    free(data);
    if (!b64) {
        jb_append_str(&jb, "{\"error\":\"alloc failed\",\"base64\":\"\",\"length\":0}");
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"base64\":\"");
    jb_append_str(&jb, b64);
    char lenbuf[32];
    snprintf(lenbuf, sizeof(lenbuf), "\",\"length\":%d}", data_len);
    jb_append_str(&jb, lenbuf);
    free(b64);
    return jb_finish(&jb);
}

// ============================================================
// 文本统计 / 编码检测 / 文件比较
// ============================================================
char *file_detect_encoding(const char *path) {
    JsonBuilder jb = jb_new();
    const char *enc = file_ops_detect_encoding(path);
    jb_append_str(&jb, "{\"error\":\"\",\"encoding\":");
    jb_append_esc(&jb, enc ? enc : "unknown");
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

char *file_text_stats(const char *path) {
    JsonBuilder jb = jb_new();
    long long bytes = 0, chars = 0, lines = 0, words = 0;
    if (file_ops_text_stats(path, &bytes, &chars, &lines, &words) != 0) {
        jb_append_str(&jb, "{\"error\":\"failed to read file\",\"bytes\":0,\"chars\":0,\"lines\":0,\"words\":0}");
        return jb_finish(&jb);
    }
    jb_append_str(&jb, "{\"error\":\"\",\"bytes\":"); jb_append_int(&jb, bytes);
    jb_append_str(&jb, ",\"chars\":");  jb_append_int(&jb, chars);
    jb_append_str(&jb, ",\"lines\":");  jb_append_int(&jb, lines);
    jb_append_str(&jb, ",\"words\":");  jb_append_int(&jb, words);
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

char *file_compare_files(const char *path_a, const char *path_b) {
    JsonBuilder jb = jb_new();
    int equal = 0;
    long long first_diff = -1;
    if (file_ops_compare_files(path_a, path_b, &equal, &first_diff) != 0) {
        jb_append_str(&jb, "{\"error\":\"failed to read files\",\"equal\":false,\"sizeA\":0,\"sizeB\":0,\"firstDiff\":-1}");
        return jb_finish(&jb);
    }
    long long size_a = 0, size_b = 0;
    FILE *fa = fopen(path_a, "rb");
    FILE *fb = fopen(path_b, "rb");
    if (fa) { fseek(fa, 0, SEEK_END); size_a = ftell(fa); fclose(fa); }
    if (fb) { fseek(fb, 0, SEEK_END); size_b = ftell(fb); fclose(fb); }
    jb_append_str(&jb, "{\"error\":\"\",\"equal\":");
    jb_append_bool(&jb, equal != 0);
    jb_append_str(&jb, ",\"sizeA\":");    jb_append_int(&jb, size_a);
    jb_append_str(&jb, ",\"sizeB\":");    jb_append_int(&jb, size_b);
    jb_append_str(&jb, ",\"firstDiff\":"); jb_append_int(&jb, first_diff);
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

int file_split_file(const char *path, long long part_size, const char *out_dir,
                    char *error, int error_size) {
    return file_ops_split_file(path, part_size, out_dir, error, error_size);
}

int file_merge_files(const char *parts_dir, const char *base_name, const char *out_path,
                     char *error, int error_size) {
    return file_ops_merge_files(parts_dir, base_name, out_path, error, error_size);
}

} // extern "C"
