
#include "fs.h"
#include "fs_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { char* data; int len; int capacity; } JsonBuilder;

static JsonBuilder* jb_new(void) {
    JsonBuilder* jb = (JsonBuilder*)calloc(1, sizeof(JsonBuilder));
    if (!jb) return NULL;
    jb->capacity = 4096;
    jb->data = (char*)malloc(jb->capacity);
    if (!jb->data) { free(jb); return NULL; }
    jb->data[0] = '\0'; jb->len = 0;
    return jb;
}
static void jb_ensure(JsonBuilder* jb, int extra) {
    if (jb->len + extra + 1 > jb->capacity) {
        jb->capacity = (jb->len + extra + 1) * 2;
        jb->data = (char*)realloc(jb->data, jb->capacity);
    }
}
static void jb_append(JsonBuilder* jb, const char* str) {
    int slen = (int)strlen(str);
    jb_ensure(jb, slen);
    memcpy(jb->data + jb->len, str, slen);
    jb->len += slen;
    jb->data[jb->len] = '\0';
}
static void jb_append_esc(JsonBuilder* jb, const char* str) {
    if (!str) { jb_append(jb, "\"\""); return; }
    jb_append(jb, "\"");
    for (const char* p = str; *p; p++) {
        switch (*p) {
            case '"': jb_append(jb, "\\\""); break;
            case '\\': jb_append(jb, "\\\\"); break;
            case '\n': jb_append(jb, "\\n"); break;
            case '\r': jb_append(jb, "\\r"); break;
            case '\t': jb_append(jb, "\\t"); break;
            default: jb_ensure(jb, 2); jb->data[jb->len++] = *p; jb->data[jb->len] = '\0'; break;
        }
    }
    jb_append(jb, "\"");
}
static void jb_append_int(JsonBuilder* jb, long long val) {
    char buf[32]; snprintf(buf, sizeof(buf), "%lld", val); jb_append(jb, buf);
}
static char* jb_finish(JsonBuilder* jb) { char* r = jb->data; free(jb); return r; }

static void fi_to_json(JsonBuilder* jb, const FileInfo* i) {
    jb_append(jb, "{\"name\":"); jb_append_esc(jb, i->name);
    jb_append(jb, ",\"path\":"); jb_append_esc(jb, i->path);
    jb_append(jb, ",\"symlinkTarget\":"); jb_append_esc(jb, i->symlink_target);
    jb_append(jb, ",\"type\":"); jb_append_int(jb, i->type);
    jb_append(jb, ",\"size\":"); jb_append_int(jb, i->size);
    jb_append(jb, ",\"modifiedTime\":"); jb_append_int(jb, i->modified_time);
    jb_append(jb, ",\"accessTime\":"); jb_append_int(jb, i->access_time);
    jb_append(jb, ",\"createdTime\":"); jb_append_int(jb, i->created_time);
    jb_append(jb, ",\"permissions\":"); jb_append_int(jb, i->permissions);
    jb_append(jb, ",\"uid\":"); jb_append_int(jb, i->uid);
    jb_append(jb, ",\"gid\":"); jb_append_int(jb, i->gid);
    jb_append(jb, ",\"ownerName\":"); jb_append_esc(jb, i->owner_name);
    jb_append(jb, ",\"groupName\":"); jb_append_esc(jb, i->group_name);
    jb_append(jb, ",\"mimeType\":"); jb_append_esc(jb, i->mime_type);
    jb_append(jb, ",\"isReadable\":"); jb_append(jb, i->is_readable ? "true" : "false");
    jb_append(jb, ",\"isWritable\":"); jb_append(jb, i->is_writable ? "true" : "false");
    jb_append(jb, ",\"isExecutable\":"); jb_append(jb, i->is_executable ? "true" : "false");
    jb_append(jb, ",\"isHidden\":"); jb_append(jb, i->is_hidden ? "true" : "false");
    jb_append(jb, "}");
}

extern "C" {

char* fs_list_directory(const char* path, int show_hidden) {
    JsonBuilder* jb = jb_new();
    DirListResult* r = file_ops_list_directory(path, show_hidden != 0);
    if (!r) { jb_append(jb, "{\"error\":\"null\",\"items\":[]}"); return jb_finish(jb); }
    if (r->error[0]) { jb_append(jb, "{\"error\":"); jb_append_esc(jb, r->error); jb_append(jb, ",\"items\":[]}"); file_ops_free_dir_list(r); return jb_finish(jb); }
    jb_append(jb, "{\"error\":\"\",\"items\":[");
    for (int i = 0; i < r->count; i++) { if (i > 0) jb_append(jb, ","); fi_to_json(jb, &r->items[i]); }
    jb_append(jb, "]}"); file_ops_free_dir_list(r); return jb_finish(jb);
}

char* fs_get_file_info(const char* path) {
    JsonBuilder* jb = jb_new();
    FileInfo* i = file_ops_get_file_info(path);
    if (!i) { jb_append(jb, "{\"error\":\"not found\"}"); return jb_finish(jb); }
    jb_append(jb, "{\"error\":\"\",\"info\":"); fi_to_json(jb, i); jb_append(jb, "}");
    file_ops_free_file_info(i); return jb_finish(jb);
}

char* fs_search_files(const char* dir, const char* pattern, int max_results) {
    JsonBuilder* jb = jb_new();
    SearchResultList* r = file_ops_search_files(dir, pattern, max_results);
    if (!r) { jb_append(jb, "{\"error\":\"null\",\"items\":[]}"); return jb_finish(jb); }
    jb_append(jb, "{\"error\":\"\",\"items\":[");
    for (int i = 0; i < r->count; i++) {
        if (i > 0) jb_append(jb, ",");
        jb_append(jb, "{\"path\":"); jb_append_esc(jb, r->items[i].path);
        jb_append(jb, ",\"name\":"); jb_append_esc(jb, r->items[i].name);
        jb_append(jb, ",\"type\":"); jb_append_int(jb, r->items[i].type);
        jb_append(jb, ",\"size\":"); jb_append_int(jb, r->items[i].size);
        jb_append(jb, ",\"modifiedTime\":"); jb_append_int(jb, r->items[i].modified_time);
        jb_append(jb, "}");
    }
    jb_append(jb, "]}"); file_ops_free_search_results(r); return jb_finish(jb);
}

char* fs_compute_hash(const char* path) {
    JsonBuilder* jb = jb_new();
    HashResult* r = file_ops_compute_hash(path);
    if (!r) { jb_append(jb, "{\"error\":\"failed\"}"); return jb_finish(jb); }
    if (r->error[0]) { jb_append(jb, "{\"error\":"); jb_append_esc(jb, r->error); jb_append(jb, "}"); file_ops_free_hash_result(r); return jb_finish(jb); }
    jb_append(jb, "{\"error\":\"\",\"md5\":"); jb_append_esc(jb, r->md5);
    jb_append(jb, ",\"sha1\":"); jb_append_esc(jb, r->sha1);
    jb_append(jb, ",\"sha256\":"); jb_append_esc(jb, r->sha256);
    jb_append(jb, ",\"sha512\":"); jb_append_esc(jb, r->sha512);
    jb_append(jb, ",\"crc32\":"); jb_append_esc(jb, r->crc32);
    jb_append(jb, "}"); file_ops_free_hash_result(r); return jb_finish(jb);
}

char* fs_get_disk_usage(const char* path) {
    JsonBuilder* jb = jb_new();
    DiskUsageInfo* d = file_ops_get_disk_usage(path);
    if (!d) { jb_append(jb, "{\"error\":\"failed\"}"); return jb_finish(jb); }
    if (d->error[0]) { jb_append(jb, "{\"error\":"); jb_append_esc(jb, d->error); jb_append(jb, "}"); file_ops_free_disk_usage(d); return jb_finish(jb); }
    jb_append(jb, "{\"error\":\"\",\"totalSpace\":"); jb_append_int(jb, d->total_space);
    jb_append(jb, ",\"freeSpace\":"); jb_append_int(jb, d->free_space);
    jb_append(jb, ",\"usedSpace\":"); jb_append_int(jb, d->used_space);
    jb_append(jb, "}"); file_ops_free_disk_usage(d); return jb_finish(jb);
}

char* fs_find_duplicates(const char* dir, int max_results) {
    JsonBuilder* jb = jb_new();
    SearchResultList* r = file_ops_find_duplicates(dir, max_results);
    if (!r) { jb_append(jb, "{\"error\":\"null\",\"items\":[]}"); return jb_finish(jb); }
    jb_append(jb, "{\"error\":\"\",\"items\":[");
    for (int i = 0; i < r->count; i++) {
        if (i > 0) jb_append(jb, ",");
        jb_append(jb, "{\"path\":"); jb_append_esc(jb, r->items[i].path);
        jb_append(jb, ",\"name\":"); jb_append_esc(jb, r->items[i].name);
        jb_append(jb, ",\"size\":"); jb_append_int(jb, r->items[i].size);
        jb_append(jb, "}");
    }
    jb_append(jb, "]}"); file_ops_free_search_results(r); return jb_finish(jb);
}

char* fs_find_empty_files(const char* dir, int max_results) {
    JsonBuilder* jb = jb_new();
    SearchResultList* r = file_ops_find_empty_files(dir, max_results);
    if (!r) { jb_append(jb, "{\"error\":\"null\",\"items\":[]}"); return jb_finish(jb); }
    jb_append(jb, "{\"error\":\"\",\"items\":[");
    for (int i = 0; i < r->count; i++) {
        if (i > 0) jb_append(jb, ",");
        jb_append(jb, "{\"path\":"); jb_append_esc(jb, r->items[i].path);
        jb_append(jb, ",\"name\":"); jb_append_esc(jb, r->items[i].name);
        jb_append(jb, ",\"type\":"); jb_append_int(jb, r->items[i].type);
        jb_append(jb, ",\"size\":"); jb_append_int(jb, r->items[i].size);
        jb_append(jb, "}");
    }
    jb_append(jb, "]}"); file_ops_free_search_results(r); return jb_finish(jb);
}

char* fs_get_home_dir(void) {
    JsonBuilder* jb = jb_new(); jb_append(jb, "{\"path\":"); jb_append_esc(jb, file_ops_get_home_dir()); jb_append(jb, "}"); return jb_finish(jb);
}
char* fs_get_root_dir(void) {
    JsonBuilder* jb = jb_new(); jb_append(jb, "{\"path\":"); jb_append_esc(jb, file_ops_get_root_dir()); jb_append(jb, "}"); return jb_finish(jb);
}

int fs_create_directory(const char* path, char* error, int error_size) { return file_ops_create_directory(path, error, error_size); }
int fs_create_file(const char* path, char* error, int error_size) { return file_ops_create_file(path, error, error_size); }
int fs_delete_file(const char* path, char* error, int error_size) { return file_ops_delete_file(path, error, error_size); }
int fs_rename(const char* old_path, const char* new_path, char* error, int error_size) { return file_ops_rename(old_path, new_path, error, error_size); }
int fs_copy_file(const char* src, const char* dst, char* error, int error_size) { return file_ops_copy_file(src, dst, error, error_size); }
int fs_move_file(const char* src, const char* dst, char* error, int error_size) { return file_ops_move_file(src, dst, error, error_size); }
int fs_exists(const char* path) { return file_ops_exists(path); }
int fs_is_directory(const char* path) { return file_ops_is_directory(path); }
void fs_free_json(char* json) { free(json); }

// New functions from Syscall.kt - added by porting

int fs_access(const char* path, int mode) {
    return file_ops_access(path, mode);
}

int fs_chown(const char* path, uint32_t uid, uint32_t gid, char* error, int error_size) {
    return file_ops_chown(path, uid, gid, error, error_size);
}

int fs_lchown(const char* path, uint32_t uid, uint32_t gid, char* error, int error_size) {
    return file_ops_lchown(path, uid, gid, error, error_size);
}

int fs_symlink(const char* target, const char* linkpath, char* error, int error_size) {
    return file_ops_symlink(target, linkpath, error, error_size);
}

int fs_link(const char* oldpath, const char* newpath, char* error, int error_size) {
    return file_ops_link(oldpath, newpath, error, error_size);
}

static const char* fs_realpath_impl(const char* path) {
    return file_ops_realpath(path);
}
static const char* fs_readlink_impl(const char* path) {
    return file_ops_readlink(path);
}

char* fs_get_recent_files(const char* dir, int days, int max_results) {
    JsonBuilder* jb = jb_new();
    SearchResultList* r = file_ops_get_recent_files(dir, days, max_results);
    if (!r) { jb_append(jb, "{\"error\":\"null\",\"items\":[]}"); return jb_finish(jb); }
    jb_append(jb, "{\"error\":\"\",\"items\":[");
    for (int i = 0; i < r->count; i++) {
        if (i > 0) jb_append(jb, ",");
        jb_append(jb, "{\"path\":"); jb_append_esc(jb, r->items[i].path);
        jb_append(jb, ",\"name\":"); jb_append_esc(jb, r->items[i].name);
        jb_append(jb, ",\"type\":"); jb_append_int(jb, r->items[i].type);
        jb_append(jb, ",\"size\":"); jb_append_int(jb, r->items[i].size);
        jb_append(jb, ",\"modifiedTime\":"); jb_append_int(jb, r->items[i].modified_time);
        jb_append(jb, "}");
    }
    jb_append(jb, "]}"); file_ops_free_search_results(r); return jb_finish(jb);
}

int fs_encrypt_file(const char* src, const char* dst, const char* password, char* error, int error_size) {
    return file_ops_encrypt_file(src, dst, password, error, error_size);
}

int fs_decrypt_file(const char* src, const char* dst, const char* password, char* error, int error_size) {
    return file_ops_decrypt_file(src, dst, password, error, error_size);
}

char* fs_realpath(const char* path) {
    JsonBuilder* jb = jb_new();
    const char* rp = fs_realpath_impl(path);
    jb_append(jb, "{\"path\":");
    jb_append_esc(jb, rp ? rp : "");
    jb_append(jb, "}");
    return jb_finish(jb);
}

char* fs_readlink(const char* path) {
    JsonBuilder* jb = jb_new();
    const char* rl = fs_readlink_impl(path);
    jb_append(jb, "{\"target\":");
    jb_append_esc(jb, rl ? rl : "");
    jb_append(jb, "}");
    return jb_finish(jb);
}

// ============================================================
// File content I/O (for viewers)
// ============================================================

char* fs_read_text_file(const char* path) {
    JsonBuilder* jb = jb_new();
    char* text = file_ops_read_file_text(path);
    if (!text) {
        jb_append(jb, "{\"error\":\"failed to read file\"}");
        return jb_finish(jb);
    }
    jb_append(jb, "{\"error\":\"\",\"text\":");
    jb_append_esc(jb, text);
    free(text);
    jb_append(jb, "}");
    return jb_finish(jb);
}

int fs_write_text_file(const char* path, const char* content, char* error, int error_size) {
    return file_ops_write_file_text(path, content, error, error_size);
}

char* fs_read_csv_file(const char* path) {
    JsonBuilder* jb = jb_new();
    char* text = file_ops_read_file_text(path);
    if (!text) {
        jb_append(jb, "{\"error\":\"failed to read file\",\"rows\":[]}");
        return jb_finish(jb);
    }
    jb_append(jb, "{\"error\":\"\",\"rows\":[");
    const char* p = text;
    int row_count = 0;
    while (*p) {
        if (row_count > 0) jb_append(jb, ",");
        jb_append(jb, "[");
        int col_count = 0;
        while (*p && *p != '\n') {
            if (col_count > 0) jb_append(jb, ",");
            // Find end of field
            const char* start = p;
            while (*p && *p != ',' && *p != '\n') p++;
            // Temporarily null-terminate
            char save = *p;
            *(char*)p = '\0';
            jb_append_esc(jb, start);
            *(char*)p = save;
            col_count++;
            if (*p == ',') p++;
        }
        jb_append(jb, "]");
        row_count++;
        if (*p == '\n') p++;
    }
    free(text);
    jb_append(jb, "]}");
    return jb_finish(jb);
}

char* fs_read_hex_chunk(const char* path, long long offset, int length) {
    JsonBuilder* jb = jb_new();
    int actual_len = 0;
    unsigned char* data = file_ops_read_file_chunk(path, offset, length, &actual_len);
    if (!data || actual_len == 0) {
        jb_append(jb, "{\"error\":\"read failed\",\"hex\":\"\",\"ascii\":\"\",\"length\":0}");
        if (data) free(data);
        return jb_finish(jb);
    }
    jb_append(jb, "{\"error\":\"\",\"hex\":\"");
    // Build hex string
    for (int i = 0; i < actual_len; i++) {
        char buf[4];
        snprintf(buf, sizeof(buf), "%02x", data[i]);
        jb_append(jb, buf);
        if (i < actual_len - 1) jb_append(jb, " ");
    }
    jb_append(jb, "\",\"ascii\":\"");
    for (int i = 0; i < actual_len; i++) {
        unsigned char c = data[i];
        if (c >= 0x20 && c <= 0x7E) {
            char buf[2] = { (char)c, 0 };
            jb_append(jb, buf);
        } else {
            jb_append(jb, ".");
        }
    }
    char lenbuf[32];
    snprintf(lenbuf, sizeof(lenbuf), "\",\"length\":%d}", actual_len);
    jb_append(jb, lenbuf);
    free(data);
    return jb_finish(jb);
}

static const char b64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

char* fs_read_image_as_base64(const char* path) {
    JsonBuilder* jb = jb_new();
    int data_len = 0;
    unsigned char* data = file_ops_read_file_bytes(path, &data_len);
    if (!data || data_len == 0) {
        jb_append(jb, "{\"error\":\"read failed\",\"base64\":\"\"}");
        if (data) free(data);
        return jb_finish(jb);
    }
    // Base64 encode
    int out_len = 4 * ((data_len + 2) / 3);
    char* b64 = (char*)malloc(out_len + 1);
    if (!b64) {
        jb_append(jb, "{\"error\":\"alloc failed\",\"base64\":\"\"}");
        free(data);
        return jb_finish(jb);
    }
    int i = 0, j = 0;
    while (i < data_len) {
        unsigned int a = i < data_len ? data[i++] : 0;
        unsigned int b = i < data_len ? data[i++] : 0;
        unsigned int c = i < data_len ? data[i++] : 0;
        unsigned int triple = (a << 16) | (b << 8) | c;
        b64[j++] = b64_table[(triple >> 18) & 0x3F];
        b64[j++] = b64_table[(triple >> 12) & 0x3F];
        b64[j++] = (i > data_len + 1) ? '=' : b64_table[(triple >> 6) & 0x3F];
        b64[j++] = (i > data_len) ? '=' : b64_table[triple & 0x3F];
    }
    b64[j] = '\0';
    jb_append(jb, "{\"error\":\"\",\"base64\":\"");
    jb_append(jb, b64);
    jb_append(jb, "\",\"length\":");
    char lenbuf[32];
    snprintf(lenbuf, sizeof(lenbuf), "%d}", data_len);
    jb_append(jb, lenbuf);
    free(b64);
    free(data);
    return jb_finish(jb);
}

// 通用二进制读取：视频/音频/PDF/电子书等所有 viewer 用
char* fs_read_binary_as_base64(const char* path) {
    JsonBuilder* jb = jb_new();
    int data_len = 0;
    unsigned char* data = file_ops_read_file_bytes(path, &data_len);
    if (!data || data_len == 0) {
        jb_append(jb, "{\"error\":\"read failed\",\"base64\":\"\",\"length\":0}");
        if (data) free(data);
        return jb_finish(jb);
    }
    int out_len = 4 * ((data_len + 2) / 3);
    char* b64 = (char*)malloc(out_len + 1);
    if (!b64) {
        jb_append(jb, "{\"error\":\"alloc failed\",\"base64\":\"\",\"length\":0}");
        free(data);
        return jb_finish(jb);
    }
    int i = 0, j = 0;
    while (i < data_len) {
        unsigned int a = i < data_len ? data[i++] : 0;
        unsigned int b = i < data_len ? data[i++] : 0;
        unsigned int c = i < data_len ? data[i++] : 0;
        unsigned int triple = (a << 16) | (b << 8) | c;
        b64[j++] = b64_table[(triple >> 18) & 0x3F];
        b64[j++] = b64_table[(triple >> 12) & 0x3F];
        b64[j++] = (i > data_len + 1) ? '=' : b64_table[(triple >> 6) & 0x3F];
        b64[j++] = (i > data_len) ? '=' : b64_table[triple & 0x3F];
    }
    b64[j] = '\0';
    jb_append(jb, "{\"error\":\"\",\"base64\":\"");
    jb_append(jb, b64);
    jb_append(jb, "\",\"length\":");
    char lenbuf[32];
    snprintf(lenbuf, sizeof(lenbuf), "%d}", data_len);
    jb_append(jb, lenbuf);
    free(b64);
    free(data);
    return jb_finish(jb);
}

// ============================================================
// ====================  FILE TOOL API (JSON)  =================
// ============================================================

int fs_chmod(const char* path, uint32_t mode, char* error, int error_size) {
    return file_ops_chmod(path, mode, error, error_size);
}

char* fs_detect_encoding(const char* path) {
    JsonBuilder* jb = jb_new();
    const char* enc = file_ops_detect_encoding(path);
    jb_append(jb, "{\"error\":\"\",\"encoding\":");
    jb_append_esc(jb, enc ? enc : "unknown");
    jb_append(jb, "}");
    return jb_finish(jb);
}

char* fs_text_stats(const char* path) {
    JsonBuilder* jb = jb_new();
    long long bytes = 0, chars = 0, lines = 0, words = 0;
    if (file_ops_text_stats(path, &bytes, &chars, &lines, &words) != 0) {
        jb_append(jb, "{\"error\":\"failed to read file\",\"bytes\":0,\"chars\":0,\"lines\":0,\"words\":0}");
        return jb_finish(jb);
    }
    jb_append(jb, "{\"error\":\"\",\"bytes\":"); jb_append_int(jb, bytes);
    jb_append(jb, ",\"chars\":"); jb_append_int(jb, chars);
    jb_append(jb, ",\"lines\":"); jb_append_int(jb, lines);
    jb_append(jb, ",\"words\":"); jb_append_int(jb, words);
    jb_append(jb, "}");
    return jb_finish(jb);
}

char* fs_compare_files(const char* path_a, const char* path_b) {
    JsonBuilder* jb = jb_new();
    int equal = 0;
    long long first_diff = -1;
    if (file_ops_compare_files(path_a, path_b, &equal, &first_diff) != 0) {
        jb_append(jb, "{\"error\":\"failed to read files\",\"equal\":false,\"sizeA\":0,\"sizeB\":0,\"firstDiff\":-1}");
        return jb_finish(jb);
    }
    long long size_a = 0, size_b = 0;
    // 获取大小用于展示
    {
        FILE* fa = fopen(path_a, "rb");
        FILE* fb = fopen(path_b, "rb");
        if (fa) { fseek(fa, 0, SEEK_END); size_a = ftell(fa); fclose(fa); }
        if (fb) { fseek(fb, 0, SEEK_END); size_b = ftell(fb); fclose(fb); }
    }
    jb_append(jb, "{\"error\":\"\",\"equal\":");
    jb_append(jb, equal ? "true" : "false");
    jb_append(jb, ",\"sizeA\":"); jb_append_int(jb, size_a);
    jb_append(jb, ",\"sizeB\":"); jb_append_int(jb, size_b);
    jb_append(jb, ",\"firstDiff\":"); jb_append_int(jb, first_diff);
    jb_append(jb, "}");
    return jb_finish(jb);
}

int fs_split_file(const char* path, long long part_size, const char* out_dir, char* error, int error_size) {
    return file_ops_split_file(path, part_size, out_dir, error, error_size);
}

int fs_merge_files(const char* parts_dir, const char* base_name, const char* out_path, char* error, int error_size) {
    return file_ops_merge_files(parts_dir, base_name, out_path, error, error_size);
}

}
