/*
 * database.cpp - database 模块实现（SQLite：files/tags/file_tags）
 *
 * 文件管理器的核心：把系统文件「导入」到内部 SQLite 数据库后管理。
 * 依赖预编译 sqlite3（third_party/<platform>/lib/libsqlite3.a）。
 *
 * 对外统一返回 JSON（使用 json_builder），供 Dart FFI 解析。
 */

#include "database.h"
#include "json_builder.h"
#include <sqlite3.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <vector>
#include <filesystem>
#include <chrono>

namespace fs = std::filesystem;

// ============================================================
// 全局（单数据库）
// ============================================================
static sqlite3 *g_db = nullptr;
static std::string g_data_dir;

// ============================================================
// 工具
// ============================================================
static long long now_epoch() {
    return std::chrono::duration_cast<std::chrono::seconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
}

static std::string file_ext(const std::string &name) {
    size_t p = name.rfind('.');
    if (p == std::string::npos || p == name.size() - 1) return "";
    std::string e = name.substr(p + 1);
    for (auto &c : e) c = (char)tolower(c);
    return e;
}

static const char *ext_mime(const std::string &ext) {
    static const struct { const char *e, *m; } m[] = {
        {"png","image/png"},{"jpg","image/jpeg"},{"jpeg","image/jpeg"},{"gif","image/gif"},
        {"webp","image/webp"},{"bmp","image/bmp"},{"tiff","image/tiff"},{"ico","image/x-icon"},
        {"mp4","video/mp4"},{"mkv","video/x-matroska"},{"mov","video/quicktime"},
        {"webm","video/webm"},{"avi","video/x-msvideo"},{"3gp","video/3gpp"},{"flv","video/x-flv"},
        {"mp3","audio/mpeg"},{"wav","audio/wav"},{"flac","audio/flac"},{"aac","audio/aac"},
        {"ogg","audio/ogg"},{"m4a","audio/mp4"},{"opus","audio/opus"},
        {"zip","application/zip"},{"epub","application/epub+zip"},
        {"pdf","application/pdf"},{"txt","text/plain"},{"md","text/markdown"},
        {"json","application/json"},{"xml","application/xml"},{"csv","text/csv"},
        {"html","text/html"},{"htm","text/html"},
    };
    for (auto &p : m) if (ext == p.e) return p.m;
    return "application/octet-stream";
}

static const char *default_tag_for_ext(const std::string &ext) {
    static const struct { const char *e; const char *tag; } t[] = {
        {"png","图片"},{"jpg","图片"},{"jpeg","图片"},{"gif","图片"},{"webp","图片"},
        {"bmp","图片"},{"tiff","图片"},{"ico","图片"},
        {"mp4","视频"},{"mkv","视频"},{"mov","视频"},{"webm","视频"},{"avi","视频"},
        {"3gp","视频"},{"flv","视频"},
        {"mp3","音频"},{"wav","音频"},{"flac","音频"},{"aac","音频"},{"ogg","音频"},
        {"m4a","音频"},{"opus","音频"},
        {"zip","压缩包"},{"7z","压缩包"},{"rar","压缩包"},{"tar","压缩包"},{"gz","压缩包"},
        {"epub","电子书"},{"mobi","电子书"},{"azw3","电子书"},
        {"pdf","文档"},{"doc","文档"},{"docx","文档"},{"xls","文档"},{"xlsx","文档"},
        {"ppt","文档"},{"pptx","文档"},{"odt","文档"},{"csv","文档"},
        {"c","代码"},{"cpp","代码"},{"h","代码"},{"hpp","代码"},{"java","代码"},
        {"py","代码"},{"js","代码"},{"ts","代码"},{"go","代码"},{"rs","代码"},
        {"dart","代码"},{"sh","代码"},{"rb","代码"},{"php","代码"},
    };
    for (auto &p : t) if (ext == p.e) return p.tag;
    return "其他";
}

// 拆分逗号分隔
static std::vector<std::string> split_csv(const char *s) {
    std::vector<std::string> out;
    if (!s) return out;
    std::string cur;
    for (const char *p = s; *p; p++) {
        if (*p == ',') { out.push_back(cur); cur.clear(); }
        else cur += *p;
    }
    out.push_back(cur);
    return out;
}

// ============================================================
// SQLite 初始化 / 建表
// ============================================================
static int db_exec(const char *sql) {
    char *err = nullptr;
    if (sqlite3_exec(g_db, sql, nullptr, nullptr, &err) != SQLITE_OK) {
        sqlite3_free(err);
        return -1;
    }
    return 0;
}

static long long last_insert_id() { return sqlite3_last_insert_rowid(g_db); }

// 确保标签存在，返回其 id
static long long ensure_tag(const char *name) {
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db, "SELECT id FROM tags WHERE name=?", -1, &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(st, 1, name, -1, SQLITE_TRANSIENT);
        if (sqlite3_step(st) == SQLITE_ROW) {
            long long id = sqlite3_column_int64(st, 0);
            sqlite3_finalize(st);
            return id;
        }
        sqlite3_finalize(st);
    }
    sqlite3_stmt *ins;
    if (sqlite3_prepare_v2(g_db, "INSERT INTO tags(name,color,builtin) VALUES(?,?,0)", -1, &ins, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(ins, 1, name, -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(ins, 2, "", -1, SQLITE_STATIC);
        sqlite3_step(ins);
        long long id = last_insert_id();
        sqlite3_finalize(ins);
        return id;
    }
    return -1;
}

// ============================================================
// JSON 输出（把一行 files 结果转为 JSON）
// ============================================================
static void file_row_to_json(JsonBuilder *jb, sqlite3_stmt *st) {
    jb_append_str(jb, "{\"id\":");        jb_append_int(jb, sqlite3_column_int64(st, 0));
    jb_append_str(jb, ",\"name\":");      jb_append_esc(jb, (const char*)sqlite3_column_text(st, 1));
    jb_append_str(jb, ",\"ext\":");       jb_append_esc(jb, (const char*)sqlite3_column_text(st, 2));
    jb_append_str(jb, ",\"mime\":");      jb_append_esc(jb, (const char*)sqlite3_column_text(st, 3));
    jb_append_str(jb, ",\"size\":");      jb_append_int(jb, sqlite3_column_int64(st, 4));
    jb_append_str(jb, ",\"path\":");      jb_append_esc(jb, (const char*)sqlite3_column_text(st, 5));
    jb_append_str(jb, ",\"source\":");    jb_append_esc(jb, (const char*)sqlite3_column_text(st, 6));
    jb_append_str(jb, ",\"sourceType\":"); jb_append_esc(jb, (const char*)sqlite3_column_text(st, 7));
    jb_append_str(jb, ",\"isDir\":");     jb_append_int(jb, sqlite3_column_int(st, 8));
    jb_append_str(jb, ",\"parentId\":");  jb_append_int(jb, sqlite3_column_int64(st, 9));
    jb_append_str(jb, ",\"importTime\":"); jb_append_int(jb, sqlite3_column_int64(st, 10));
    jb_append_str(jb, ",\"deleted\":");   jb_append_int(jb, sqlite3_column_int(st, 11));
    jb_append_str(jb, ",\"tags\":[");
    long long fid = sqlite3_column_int64(st, 0);
    sqlite3_stmt *ts = nullptr;
    bool first = true;
    if (sqlite3_prepare_v2(g_db,
            "SELECT t.id,t.name,t.color FROM file_tags ft JOIN tags t ON t.id=ft.tag_id WHERE ft.file_id=?",
            -1, &ts, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(ts, 1, fid);
        while (sqlite3_step(ts) == SQLITE_ROW) {
            if (!first) jb_append_str(jb, ",");
            first = false;
            jb_append_str(jb, "{\"id\":"); jb_append_int(jb, sqlite3_column_int64(ts, 0));
            jb_append_str(jb, ",\"name\":"); jb_append_esc(jb, (const char*)sqlite3_column_text(ts, 1));
            jb_append_str(jb, ",\"color\":"); jb_append_esc(jb, (const char*)sqlite3_column_text(ts, 2));
            jb_append_str(jb, "}");
        }
        sqlite3_finalize(ts);
    }
    jb_append_str(jb, "]}");
}

// 执行一条查询并把结果行转成 JSON items 数组
static char *query_files_json(const char *sql, int bind_int, sqlite3_int64 param) {
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    sqlite3_stmt *st = nullptr;
    if (sqlite3_prepare_v2(g_db, sql, -1, &st, nullptr) == SQLITE_OK) {
        if (bind_int) sqlite3_bind_int64(st, 1, param);
        bool first = true;
        while (sqlite3_step(st) == SQLITE_ROW) {
            if (!first) jb_append_str(&jb, ",");
            first = false;
            file_row_to_json(&jb, st);
        }
        sqlite3_finalize(st);
    }
    jb_append_str(&jb, "]}");
    return jb_finish(&jb);
}

// ============================================================
// FFI 实现
// ============================================================
extern "C" {

char *db_init(const char *data_dir) {
    g_data_dir = data_dir ? data_dir : "";
    if (g_db) { sqlite3_close(g_db); g_db = nullptr; }
    if (g_data_dir.empty()) return strdup("{\"error\":\"no data dir\"}");
    try { fs::create_directories(g_data_dir + "/files"); } catch (...) {}
    std::string dbpath = g_data_dir + "/files.db";
    if (sqlite3_open(dbpath.c_str(), &g_db) != SQLITE_OK) {
        sqlite3_close(g_db); g_db = nullptr;
        return strdup("{\"error\":\"open failed\"}");
    }
    const char *schema =
        "CREATE TABLE IF NOT EXISTS files("
        " id INTEGER PRIMARY KEY AUTOINCREMENT,"
        " uuid TEXT, name TEXT NOT NULL, ext TEXT, mime TEXT,"
        " size INTEGER DEFAULT 0, internal_path TEXT, source_path TEXT,"
        " source_type TEXT, is_dir INTEGER DEFAULT 0, parent_id INTEGER DEFAULT 0,"
        " import_time INTEGER, deleted INTEGER DEFAULT 0);"
        "CREATE TABLE IF NOT EXISTS tags("
        " id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL,"
        " color TEXT, builtin INTEGER DEFAULT 0);"
        "CREATE TABLE IF NOT EXISTS file_tags("
        " file_id INTEGER NOT NULL, tag_id INTEGER NOT NULL,"
        " PRIMARY KEY(file_id, tag_id));";
    if (db_exec(schema) != 0) return strdup("{\"error\":\"schema\"}");
    return strdup("{\"error\":\"\"}");
}

char *db_list_files(int parent_id) {
    const char *sql = parent_id < 0
        ? "SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted FROM files WHERE deleted=0"
        : "SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted FROM files WHERE deleted=0 AND parent_id=?";
    return query_files_json(sql, parent_id >= 0, parent_id);
}

char *db_list_all(void) { return db_list_files(-1); }

char *db_search(const char *query) {
    if (!query || !*query) return db_list_files(-1);
    // 转义 LIKE 特殊字符
    std::string esc;
    for (const char *p = query; *p; p++) {
        if (*p == '\\' || *p == '%' || *p == '_') esc += '\\';
        esc += *p;
    }
    std::string like = "%" + esc + "%";
    sqlite3_stmt *st;
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    if (sqlite3_prepare_v2(g_db,
            "SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted"
            " FROM files WHERE deleted=0 AND name LIKE ? ESCAPE '\\'", -1, &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(st, 1, like.c_str(), -1, SQLITE_TRANSIENT);
        bool first = true;
        while (sqlite3_step(st) == SQLITE_ROW) {
            if (!first) jb_append_str(&jb, ",");
            first = false;
            file_row_to_json(&jb, st);
        }
        sqlite3_finalize(st);
    }
    jb_append_str(&jb, "]}");
    return jb_finish(&jb);
}

// 单文件导入（复制进内部 + 记录 + 默认标签），返回 0 失败 / 1 成功
static int import_one(const char *src, const char *default_tags) {
    fs::path src_path(src);
    std::string name = src_path.filename().string();
    std::string ext = file_ext(name);
    std::string uuid = std::to_string(now_epoch()) + "_" + name;
    std::string dest = g_data_dir + "/files/" + uuid;
    try {
        fs::create_directories(g_data_dir + "/files");
        fs::copy_file(src_path, dest, fs::copy_options::overwrite_existing);
    } catch (...) { return 0; }
    long long size = 0;
    try { size = (long long)fs::file_size(src_path); } catch (...) {}
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db,
        "INSERT INTO files(uuid,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted)"
        " VALUES(?,?,?,?,?,?,?,?,0,0,?,0)", -1, &st, nullptr) != SQLITE_OK) return 0;
    sqlite3_bind_text(st, 1, uuid.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(st, 2, name.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(st, 3, ext.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(st, 4, ext_mime(ext), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(st, 5, size);
    sqlite3_bind_text(st, 6, dest.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(st, 7, src, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(st, 8, "filesystem", -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(st, 9, now_epoch());
    if (sqlite3_step(st) != SQLITE_DONE) { sqlite3_finalize(st); return 0; }
    long long fid = last_insert_id();
    sqlite3_finalize(st);
    // 默认标签
    auto link_tag = [&](const std::string &tname) {
        long long tid = ensure_tag(tname.c_str());
        if (tid <= 0) return;
        sqlite3_stmt *ft;
        if (sqlite3_prepare_v2(g_db, "INSERT OR IGNORE INTO file_tags(file_id,tag_id) VALUES(?,?)", -1, &ft, nullptr) == SQLITE_OK) {
            sqlite3_bind_int64(ft, 1, fid); sqlite3_bind_int64(ft, 2, tid);
            sqlite3_step(ft); sqlite3_finalize(ft);
        }
    };
    link_tag(default_tag_for_ext(ext));
    if (default_tags && *default_tags) {
        for (auto &t : split_csv(default_tags)) if (!t.empty()) link_tag(t);
    }
    return 1;
}

char *db_import_file(const char *src, const char *default_tags) {
    if (!src || !*src) return strdup("{\"error\":\"no source\"}");
    if (!import_one(src, default_tags)) return strdup("{\"error\":\"import failed\"}");
    // 返回新插入的记录
    sqlite3_stmt *st;
    long long fid = 0;
    if (sqlite3_prepare_v2(g_db, "SELECT id FROM files ORDER BY id DESC LIMIT 1", -1, &st, nullptr) == SQLITE_OK) {
        if (sqlite3_step(st) == SQLITE_ROW) fid = sqlite3_column_int64(st, 0);
        sqlite3_finalize(st);
    }
    char sql[256];
    snprintf(sql, sizeof(sql), "SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted FROM files WHERE id=%lld", fid);
    return query_files_json(sql, 0, 0);
}

// 批量导入文件夹（递归）中的文件
char *db_import_dir(const char *dir, const char *default_tags) {
    if (!dir || !*dir) return strdup("{\"error\":\"no dir\"}");
    int imported = 0, failed = 0;
    try {
        fs::recursive_directory_iterator it(dir, fs::directory_options::skip_permission_denied), end;
        for (; it != end; ++it) {
            if (it->is_regular_file()) {
                if (import_one(it->path().string().c_str(), default_tags)) imported++; else failed++;
            }
        }
    } catch (...) {
        return strdup("{\"error\":\"walk failed\"}");
    }
    char buf[128];
    snprintf(buf, sizeof(buf), "{\"error\":\"\",\"imported\":%d,\"failed\":%d}", imported, failed);
    return strdup(buf);
}

// 库内统计
char *db_stats(void) {
    long long files = 0, dirs = 0, size = 0;
    long long img = 0, vid = 0, aud = 0, doc = 0, other = 0;
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db, "SELECT is_dir,size,ext FROM files WHERE deleted=0", -1, &st, nullptr) == SQLITE_OK) {
        while (sqlite3_step(st) == SQLITE_ROW) {
            int isdir = sqlite3_column_int(st, 0);
            long long sz = sqlite3_column_int64(st, 1);
            const char *extc = (const char*)sqlite3_column_text(st, 2);
            std::string e = extc ? extc : "";
            if (isdir) { dirs++; continue; }
            files++; size += sz;
            const char *t = default_tag_for_ext(e);
            if (t == std::string("图片")) img++;
            else if (t == std::string("视频")) vid++;
            else if (t == std::string("音频")) aud++;
            else if (t == std::string("文档") || t == std::string("电子书")) doc++;
            else other++;
        }
        sqlite3_finalize(st);
    }
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"files\":"); jb_append_int(&jb, files);
    jb_append_str(&jb, ",\"dirs\":"); jb_append_int(&jb, dirs);
    jb_append_str(&jb, ",\"size\":"); jb_append_int(&jb, size);
    jb_append_str(&jb, ",\"byType\":{\"image\":"); jb_append_int(&jb, img);
    jb_append_str(&jb, ",\"video\":"); jb_append_int(&jb, vid);
    jb_append_str(&jb, ",\"audio\":"); jb_append_int(&jb, aud);
    jb_append_str(&jb, ",\"doc\":"); jb_append_int(&jb, doc);
    jb_append_str(&jb, ",\"other\":"); jb_append_int(&jb, other);
    jb_append_str(&jb, "},\"byTag\":[");
    // tag counts
    sqlite3_stmt *ts = nullptr;
    if (sqlite3_prepare_v2(g_db,
        "SELECT t.name,COUNT(ft.file_id) FROM tags t LEFT JOIN file_tags ft ON ft.tag_id=t.id GROUP BY t.id ORDER BY t.name",
        -1, &ts, nullptr) == SQLITE_OK) {
        bool first = true;
        while (sqlite3_step(ts) == SQLITE_ROW) {
            if (!first) jb_append_str(&jb, ",");
            first = false;
            jb_append_str(&jb, "{\"name\":"); jb_append_esc(&jb, (const char*)sqlite3_column_text(ts, 0));
            jb_append_str(&jb, ",\"count\":"); jb_append_int(&jb, sqlite3_column_int64(ts, 1));
            jb_append_str(&jb, "}");
        }
        sqlite3_finalize(ts);
    }
    jb_append_str(&jb, "]}");
    return jb_finish(&jb);
}

char *db_mkdir(const char *name, int parent_id) {
    if (!name || !*name) return strdup("{\"error\":\"empty name\"}");
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db, "INSERT INTO files(uuid,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted)"
        " VALUES('dir',?, '', 'inode/directory', 0, '', '', 'internal', 1, ?, ?, 0)", -1, &st, nullptr) != SQLITE_OK)
        return strdup("{\"error\":\"mkdir\"}");
    sqlite3_bind_text(st, 1, name, -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(st, 2, parent_id);
    sqlite3_bind_int64(st, 3, now_epoch());
    if (sqlite3_step(st) != SQLITE_DONE) { sqlite3_finalize(st); return strdup("{\"error\":\"mkdir2\"}"); }
    long long id = last_insert_id();
    sqlite3_finalize(st);
    char sql[256];
    snprintf(sql, sizeof(sql), "SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted FROM files WHERE id=%lld", id);
    return query_files_json(sql, 0, 0);
}

char *db_move(int file_id, int new_parent_id) {
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db, "UPDATE files SET parent_id=? WHERE id=?", -1, &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_int(st, 1, new_parent_id);
        sqlite3_bind_int64(st, 2, file_id);
        sqlite3_step(st); sqlite3_finalize(st);
    }
    return strdup("{\"error\":\"\"}");
}

char *db_rename(int file_id, const char *name) {
    sqlite3_stmt *st;
    if (name && *name && sqlite3_prepare_v2(g_db, "UPDATE files SET name=? WHERE id=?", -1, &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(st, 1, name, -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(st, 2, file_id);
        sqlite3_step(st); sqlite3_finalize(st);
    }
    return strdup("{\"error\":\"\"}");
}

char *db_delete(int file_id) {
    // 先取内部路径，删除磁盘副本（仅文件，非目录）
    sqlite3_stmt *sel;
    std::string ipath;
    if (sqlite3_prepare_v2(g_db, "SELECT internal_path,is_dir FROM files WHERE id=?", -1, &sel, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(sel, 1, file_id);
        if (sqlite3_step(sel) == SQLITE_ROW) {
            const unsigned char *p = sqlite3_column_text(sel, 0);
            int is_dir = sqlite3_column_int(sel, 1);
            if (p && !is_dir) ipath = (const char*)p;
        }
        sqlite3_finalize(sel);
    }
    if (!ipath.empty()) {
        try { fs::remove(ipath); } catch (...) {}
    }
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db, "UPDATE files SET deleted=1 WHERE id=?", -1, &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(st, 1, file_id);
        sqlite3_step(st); sqlite3_finalize(st);
    }
    return strdup("{\"error\":\"\"}");
}

char *db_tag_rename(int tag_id, const char *name) {
    if (!name || !*name) return strdup("{\"error\":\"empty name\"}");
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db, "UPDATE tags SET name=? WHERE id=?", -1, &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(st, 1, name, -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(st, 2, tag_id);
        sqlite3_step(st); sqlite3_finalize(st);
    }
    return strdup("{\"error\":\"\"}");
}

char *db_tag_counts(void) {
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db,
            "SELECT t.id,t.name,t.color,COUNT(ft.file_id) AS cnt FROM tags t"
            " LEFT JOIN file_tags ft ON ft.tag_id=t.id GROUP BY t.id ORDER BY t.name",
            -1, &st, nullptr) == SQLITE_OK) {
        bool first = true;
        while (sqlite3_step(st) == SQLITE_ROW) {
            if (!first) jb_append_str(&jb, ",");
            first = false;
            jb_append_str(&jb, "{\"id\":"); jb_append_int(&jb, sqlite3_column_int64(st, 0));
            jb_append_str(&jb, ",\"name\":"); jb_append_esc(&jb, (const char*)sqlite3_column_text(st, 1));
            jb_append_str(&jb, ",\"color\":"); jb_append_esc(&jb, (const char*)sqlite3_column_text(st, 2));
            jb_append_str(&jb, ",\"count\":"); jb_append_int(&jb, sqlite3_column_int64(st, 3));
            jb_append_str(&jb, "}");
        }
        sqlite3_finalize(st);
    }
    jb_append_str(&jb, "]}");
    return jb_finish(&jb);
}

char *db_tag_list(void) {
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db, "SELECT id,name,color,builtin FROM tags ORDER BY name", -1, &st, nullptr) == SQLITE_OK) {
        bool first = true;
        while (sqlite3_step(st) == SQLITE_ROW) {
            if (!first) jb_append_str(&jb, ",");
            first = false;
            jb_append_str(&jb, "{\"id\":"); jb_append_int(&jb, sqlite3_column_int64(st, 0));
            jb_append_str(&jb, ",\"name\":"); jb_append_esc(&jb, (const char*)sqlite3_column_text(st, 1));
            jb_append_str(&jb, ",\"color\":"); jb_append_esc(&jb, (const char*)sqlite3_column_text(st, 2));
            jb_append_str(&jb, ",\"builtin\":"); jb_append_int(&jb, sqlite3_column_int(st, 3));
            jb_append_str(&jb, "}");
        }
        sqlite3_finalize(st);
    }
    jb_append_str(&jb, "]}");
    return jb_finish(&jb);
}

char *db_tag_create(const char *name, const char *color) {
    if (!name || !*name) return strdup("{\"error\":\"empty name\"}");
    // 已存在则返回错误
    sqlite3_stmt *ck;
    if (sqlite3_prepare_v2(g_db, "SELECT id FROM tags WHERE name=?", -1, &ck, nullptr) == SQLITE_OK) {
        sqlite3_bind_text(ck, 1, name, -1, SQLITE_TRANSIENT);
        if (sqlite3_step(ck) == SQLITE_ROW) { sqlite3_finalize(ck); return strdup("{\"error\":\"exists\"}"); }
        sqlite3_finalize(ck);
    }
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db, "INSERT INTO tags(name,color,builtin) VALUES(?,?,0)", -1, &st, nullptr) != SQLITE_OK)
        return strdup("{\"error\":\"create\"}");
    sqlite3_bind_text(st, 1, name, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(st, 2, color ? color : "", -1, SQLITE_TRANSIENT);
    if (sqlite3_step(st) != SQLITE_DONE) { sqlite3_finalize(st); return strdup("{\"error\":\"create2\"}"); }
    long long id = last_insert_id();
    sqlite3_finalize(st);
    char buf[256];
    snprintf(buf, sizeof(buf), "{\"error\":\"\",\"id\":%lld,\"name\":\"%s\"}", id, name);
    return strdup(buf);
}

char *db_tag_add_to_files(const char *file_ids, const char *tag_ids) {
    if (!file_ids || !tag_ids) return strdup("{\"error\":\"bad args\"}");
    int added = 0;
    for (auto &fid_s : split_csv(file_ids)) {
        long long fid = atoll(fid_s.c_str());
        if (fid <= 0) continue;
        for (auto &tid_s : split_csv(tag_ids)) {
            long long tid = atoll(tid_s.c_str());
            if (tid <= 0) continue;
            sqlite3_stmt *st;
            if (sqlite3_prepare_v2(g_db, "INSERT OR IGNORE INTO file_tags(file_id,tag_id) VALUES(?,?)", -1, &st, nullptr) == SQLITE_OK) {
                sqlite3_bind_int64(st, 1, fid); sqlite3_bind_int64(st, 2, tid);
                if (sqlite3_step(st) == SQLITE_DONE && sqlite3_changes(g_db) > 0) added++;
                sqlite3_finalize(st);
            }
        }
    }
    char buf[128];
    snprintf(buf, sizeof(buf), "{\"error\":\"\",\"added\":%d}", added);
    return strdup(buf);
}

char *db_tag_remove_from_file(int file_id, int tag_id) {
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db, "DELETE FROM file_tags WHERE file_id=? AND tag_id=?", -1, &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(st, 1, file_id); sqlite3_bind_int64(st, 2, tag_id);
        sqlite3_step(st); sqlite3_finalize(st);
    }
    return strdup("{\"error\":\"\"}");
}

char *db_tag_delete(int tag_id) {
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db, "DELETE FROM file_tags WHERE tag_id=?", -1, &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(st, 1, tag_id);
        sqlite3_step(st); sqlite3_finalize(st);
    }
    if (sqlite3_prepare_v2(g_db, "DELETE FROM tags WHERE id=?", -1, &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(st, 1, tag_id);
        sqlite3_step(st); sqlite3_finalize(st);
    }
    return strdup("{\"error\":\"\"}");
}

char *db_files_by_tag(int tag_id) {
    const char *sql =
        "SELECT f.id,f.name,f.ext,f.mime,f.size,f.internal_path,f.source_path,f.source_type,f.is_dir,f.parent_id,f.import_time,f.deleted"
        " FROM files f JOIN file_tags ft ON ft.file_id=f.id WHERE ft.tag_id=? AND f.deleted=0";
    return query_files_json(sql, 1, tag_id);
}

char *db_file_tags(int file_id) {
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    sqlite3_stmt *st;
    if (sqlite3_prepare_v2(g_db, "SELECT t.id,t.name FROM file_tags ft JOIN tags t ON t.id=ft.tag_id WHERE ft.file_id=?",
            -1, &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(st, 1, file_id);
        bool first = true;
        while (sqlite3_step(st) == SQLITE_ROW) {
            if (!first) jb_append_str(&jb, ",");
            first = false;
            jb_append_str(&jb, "{\"id\":"); jb_append_int(&jb, sqlite3_column_int64(st, 0));
            jb_append_str(&jb, ",\"name\":"); jb_append_esc(&jb, (const char*)sqlite3_column_text(st, 1));
            jb_append_str(&jb, "}");
        }
        sqlite3_finalize(st);
    }
    jb_append_str(&jb, "]}");
    return jb_finish(&jb);
}

void db_free_string(char *str) { if (str) free(str); }

} // extern "C"
