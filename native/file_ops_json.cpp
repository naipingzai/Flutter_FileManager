
#include "file_ops_json.h"
#include "file_ops.h"
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

char* file_ops_json_list_directory(const char* path, int show_hidden) {
    JsonBuilder* jb = jb_new();
    DirListResult* r = file_ops_list_directory(path, show_hidden != 0);
    if (!r) { jb_append(jb, "{\"error\":\"null\",\"items\":[]}"); return jb_finish(jb); }
    if (r->error[0]) { jb_append(jb, "{\"error\":"); jb_append_esc(jb, r->error); jb_append(jb, ",\"items\":[]}"); file_ops_free_dir_list(r); return jb_finish(jb); }
    jb_append(jb, "{\"error\":\"\",\"items\":[");
    for (int i = 0; i < r->count; i++) { if (i > 0) jb_append(jb, ","); fi_to_json(jb, &r->items[i]); }
    jb_append(jb, "]}"); file_ops_free_dir_list(r); return jb_finish(jb);
}

char* file_ops_json_get_file_info(const char* path) {
    JsonBuilder* jb = jb_new();
    FileInfo* i = file_ops_get_file_info(path);
    if (!i) { jb_append(jb, "{\"error\":\"not found\"}"); return jb_finish(jb); }
    jb_append(jb, "{\"error\":\"\",\"info\":"); fi_to_json(jb, i); jb_append(jb, "}");
    file_ops_free_file_info(i); return jb_finish(jb);
}

char* file_ops_json_search_files(const char* dir, const char* pattern, int max_results) {
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

char* file_ops_json_compute_hash(const char* path) {
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

char* file_ops_json_get_disk_usage(const char* path) {
    JsonBuilder* jb = jb_new();
    DiskUsageInfo* d = file_ops_get_disk_usage(path);
    if (!d) { jb_append(jb, "{\"error\":\"failed\"}"); return jb_finish(jb); }
    if (d->error[0]) { jb_append(jb, "{\"error\":"); jb_append_esc(jb, d->error); jb_append(jb, "}"); file_ops_free_disk_usage(d); return jb_finish(jb); }
    jb_append(jb, "{\"error\":\"\",\"totalSpace\":"); jb_append_int(jb, d->total_space);
    jb_append(jb, ",\"freeSpace\":"); jb_append_int(jb, d->free_space);
    jb_append(jb, ",\"usedSpace\":"); jb_append_int(jb, d->used_space);
    jb_append(jb, "}"); file_ops_free_disk_usage(d); return jb_finish(jb);
}

char* file_ops_json_find_duplicates(const char* dir, int max_results) {
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

char* file_ops_json_find_empty_files(const char* dir, int max_results) {
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

char* file_ops_json_get_home_dir(void) {
    JsonBuilder* jb = jb_new(); jb_append(jb, "{\"path\":"); jb_append_esc(jb, file_ops_get_home_dir()); jb_append(jb, "}"); return jb_finish(jb);
}
char* file_ops_json_get_root_dir(void) {
    JsonBuilder* jb = jb_new(); jb_append(jb, "{\"path\":"); jb_append_esc(jb, file_ops_get_root_dir()); jb_append(jb, "}"); return jb_finish(jb);
}

int file_ops_json_create_directory(const char* path, char* error, int error_size) { return file_ops_create_directory(path, error, error_size); }
int file_ops_json_create_file(const char* path, char* error, int error_size) { return file_ops_create_file(path, error, error_size); }
int file_ops_json_delete_file(const char* path, char* error, int error_size) { return file_ops_delete_file(path, error, error_size); }
int file_ops_json_rename(const char* old_path, const char* new_path, char* error, int error_size) { return file_ops_rename(old_path, new_path, error, error_size); }
int file_ops_json_copy_file(const char* src, const char* dst, char* error, int error_size) { return file_ops_copy_file(src, dst, error, error_size); }
int file_ops_json_move_file(const char* src, const char* dst, char* error, int error_size) { return file_ops_move_file(src, dst, error, error_size); }
int file_ops_json_exists(const char* path) { return file_ops_exists(path); }
int file_ops_json_is_directory(const char* path) { return file_ops_is_directory(path); }
void file_ops_free_json(char* json) { free(json); }

// New functions from Syscall.kt - added by porting

int file_ops_json_access(const char* path, int mode) {
    return file_ops_access(path, mode);
}

int file_ops_json_chown(const char* path, uint32_t uid, uint32_t gid, char* error, int error_size) {
    return file_ops_chown(path, uid, gid, error, error_size);
}

int file_ops_json_lchown(const char* path, uint32_t uid, uint32_t gid, char* error, int error_size) {
    return file_ops_lchown(path, uid, gid, error, error_size);
}

int file_ops_json_symlink(const char* target, const char* linkpath, char* error, int error_size) {
    return file_ops_symlink(target, linkpath, error, error_size);
}

int file_ops_json_link(const char* oldpath, const char* newpath, char* error, int error_size) {
    return file_ops_link(oldpath, newpath, error, error_size);
}

static const char* file_ops_json_realpath_impl(const char* path) {
    return file_ops_realpath(path);
}
static const char* file_ops_json_readlink_impl(const char* path) {
    return file_ops_readlink(path);
}

char* file_ops_json_realpath(const char* path) {
    JsonBuilder* jb = jb_new();
    const char* rp = file_ops_json_realpath_impl(path);
    jb_append(jb, "{\"path\":");
    jb_append_esc(jb, rp ? rp : "");
    jb_append(jb, "}");
    return jb_finish(jb);
}

char* file_ops_json_readlink(const char* path) {
    JsonBuilder* jb = jb_new();
    const char* rl = file_ops_json_readlink_impl(path);
    jb_append(jb, "{\"target\":");
    jb_append_esc(jb, rl ? rl : "");
    jb_append(jb, "}");
    return jb_finish(jb);
}


}
