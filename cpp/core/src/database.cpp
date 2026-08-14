/*
 * database.cpp - database 模块实现（files/tags/file_tags 嵌入式持久化存储）
 *
 * 存储格式：data_dir/files.db，每行一条记录，字段以制表符分隔。
 *   F|<id>|<uuid>|<name>|<ext>|<mime>|<size>|<internal_path>|<source_path>|<source_type>|<is_dir>|<parent_id>|<import_time>|<deleted>
 *   T|<id>|<name>|<color>|<builtin>
 *   X|<file_id>|<tag_id>
 * 字符串字段中的 \t \n \\ 会被转义。
 *
 * 对外统一返回 JSON（使用 json_builder），供 Dart FFI 解析。
 */

#include "database.h"
#include "json_builder.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <chrono>

namespace fs = std::filesystem;

// ============================================================
// 内部数据结构
// ============================================================
struct FileRecord {
    long long id;
    std::string uuid;
    std::string name;
    std::string ext;
    std::string mime;
    long long size;
    std::string internal_path;
    std::string source_path;
    std::string source_type;
    int is_dir;
    long long parent_id;
    long long import_time;
    int deleted;
};

struct TagRecord {
    long long id;
    std::string name;
    std::string color;
    int builtin;
};

// ============================================================
// 全局状态（单数据库）
// ============================================================
static std::string g_data_dir;
static std::vector<FileRecord> g_files;
static std::vector<TagRecord> g_tags;
static std::map<long long, std::set<long long>> g_file_tags; // file_id -> {tag_id}
static long long g_next_file_id = 1;
static long long g_next_tag_id = 1;

// ============================================================
// 工具
// ============================================================
static std::string db_escape(const std::string &s) {
    std::string out;
    for (char c : s) {
        if (c == '\\') out += "\\\\";
        else if (c == '\t') out += "\\t";
        else if (c == '\n') out += "\\n";
        else out += c;
    }
    return out;
}

static std::string db_unescape(const std::string &s) {
    std::string out;
    for (size_t i = 0; i < s.size(); i++) {
        if (s[i] == '\\' && i + 1 < s.size()) {
            char n = s[i + 1];
            if (n == 't') { out += '\t'; i++; }
            else if (n == 'n') { out += '\n'; i++; }
            else if (n == '\\') { out += '\\'; i++; }
            else out += s[i];
        } else {
            out += s[i];
        }
    }
    return out;
}

static std::vector<std::string> split(const std::string &s, char delim) {
    std::vector<std::string> parts;
    std::string cur;
    for (char c : s) {
        if (c == delim) { parts.push_back(cur); cur.clear(); }
        else cur += c;
    }
    parts.push_back(cur);
    return parts;
}

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
    static const std::map<std::string, const char*> m = {
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
    auto it = m.find(ext);
    return it != m.end() ? it->second : "application/octet-stream";
}

// 默认标签：按扩展名分类
static const char *default_tags_for_ext(const std::string &ext) {
    static const std::set<std::string> img = {"png","jpg","jpeg","gif","webp","bmp","tiff","ico"};
    static const std::set<std::string> vid = {"mp4","mkv","mov","webm","avi","3gp","flv"};
    static const std::set<std::string> aud = {"mp3","wav","flac","aac","ogg","m4a","opus"};
    static const std::set<std::string> arc = {"zip","7z","rar","tar","gz","bz2"};
    static const std::set<std::string> ebo = {"epub","mobi","azw3"};
    static const std::set<std::string> doc = {"pdf","doc","docx","xls","xlsx","ppt","pptx","odt","ods","csv"};
    static const std::set<std::string> cod = {"c","cpp","h","hpp","java","py","js","ts","go","rs","dart","sh","rb","php"};
    if (img.count(ext)) return "图片";
    if (vid.count(ext)) return "视频";
    if (aud.count(ext)) return "音频";
    if (arc.count(ext)) return "压缩包";
    if (ebo.count(ext)) return "电子书";
    if (doc.count(ext)) return "文档";
    if (cod.count(ext)) return "代码";
    return "其他";
}

// ============================================================
// 持久化
// ============================================================
static std::string store_path() { return g_data_dir + "/files.db"; }

static void store_save() {
    if (g_data_dir.empty()) return;
    std::ofstream f(store_path(), std::ios::trunc);
    if (!f) return;
    for (auto &r : g_files) {
        f << "F\t" << r.id << "\t" << db_escape(r.uuid) << "\t" << db_escape(r.name)
          << "\t" << db_escape(r.ext) << "\t" << db_escape(r.mime) << "\t" << r.size
          << "\t" << db_escape(r.internal_path) << "\t" << db_escape(r.source_path)
          << "\t" << db_escape(r.source_type) << "\t" << r.is_dir << "\t" << r.parent_id
          << "\t" << r.import_time << "\t" << r.deleted << "\n";
    }
    for (auto &t : g_tags) {
        f << "T\t" << t.id << "\t" << db_escape(t.name) << "\t" << db_escape(t.color)
          << "\t" << t.builtin << "\n";
    }
    for (auto &kv : g_file_tags) {
        for (long long tid : kv.second) {
            f << "X\t" << kv.first << "\t" << tid << "\n";
        }
    }
    f.close();
}

static void store_load() {
    g_files.clear(); g_tags.clear(); g_file_tags.clear();
    if (g_data_dir.empty()) return;
    std::ifstream f(store_path());
    if (!f) return;
    std::string line;
    while (std::getline(f, line)) {
        if (line.empty()) continue;
        auto p = split(line, '\t');
        if (p.empty()) continue;
        if (p[0] == "F" && p.size() >= 14) {
            FileRecord r;
            r.id = atoll(p[1].c_str());
            r.uuid = db_unescape(p[2]);
            r.name = db_unescape(p[3]);
            r.ext = db_unescape(p[4]);
            r.mime = db_unescape(p[5]);
            r.size = atoll(p[6].c_str());
            r.internal_path = db_unescape(p[7]);
            r.source_path = db_unescape(p[8]);
            r.source_type = db_unescape(p[9]);
            r.is_dir = atoi(p[10].c_str());
            r.parent_id = atoll(p[11].c_str());
            r.import_time = atoll(p[12].c_str());
            r.deleted = atoi(p[13].c_str());
            if (r.id >= g_next_file_id) g_next_file_id = r.id + 1;
            g_files.push_back(r);
        } else if (p[0] == "T" && p.size() >= 5) {
            TagRecord t;
            t.id = atoll(p[1].c_str());
            t.name = db_unescape(p[2]);
            t.color = db_unescape(p[3]);
            t.builtin = atoi(p[4].c_str());
            if (t.id >= g_next_tag_id) g_next_tag_id = t.id + 1;
            g_tags.push_back(t);
        } else if (p[0] == "X" && p.size() >= 3) {
            long long fid = atoll(p[1].c_str());
            long long tid = atoll(p[2].c_str());
            g_file_tags[fid].insert(tid);
        }
    }
    f.close();
}

// ============================================================
// JSON 输出
// ============================================================
static void file_to_json(JsonBuilder *jb, const FileRecord &r) {
    jb_append_str(jb, "{\"id\":");    jb_append_int(jb, r.id);
    jb_append_str(jb, ",\"name\":");  jb_append_esc(jb, r.name.c_str());
    jb_append_str(jb, ",\"ext\":");   jb_append_esc(jb, r.ext.c_str());
    jb_append_str(jb, ",\"mime\":");  jb_append_esc(jb, r.mime.c_str());
    jb_append_str(jb, ",\"size\":");  jb_append_int(jb, r.size);
    jb_append_str(jb, ",\"path\":");  jb_append_esc(jb, r.internal_path.c_str());
    jb_append_str(jb, ",\"source\":"); jb_append_esc(jb, r.source_path.c_str());
    jb_append_str(jb, ",\"sourceType\":"); jb_append_esc(jb, r.source_type.c_str());
    jb_append_str(jb, ",\"isDir\":"); jb_append_int(jb, r.is_dir);
    jb_append_str(jb, ",\"parentId\":"); jb_append_int(jb, r.parent_id);
    jb_append_str(jb, ",\"importTime\":"); jb_append_int(jb, r.import_time);
    jb_append_str(jb, ",\"deleted\":"); jb_append_int(jb, r.deleted);
    jb_append_str(jb, ",\"tags\":[");
    bool first = true;
    auto it = g_file_tags.find(r.id);
    if (it != g_file_tags.end()) {
        for (long long tid : it->second) {
            for (auto &t : g_tags) {
                if (t.id == tid) {
                    if (!first) jb_append_str(jb, ",");
                    first = false;
                    jb_append_str(jb, "{\"id\":"); jb_append_int(jb, t.id);
                    jb_append_str(jb, ",\"name\":"); jb_append_esc(jb, t.name.c_str());
                    jb_append_str(jb, ",\"color\":"); jb_append_esc(jb, t.color.c_str());
                    jb_append_str(jb, "}");
                    break;
                }
            }
        }
    }
    jb_append_str(jb, "]}");
}

static char *file_list_json(const std::vector<FileRecord> &files, const char *err) {
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":");
    jb_append_esc(&jb, err ? err : "");
    jb_append_str(&jb, ",\"items\":[");
    bool first = true;
    for (auto &r : files) {
        if (!first) jb_append_str(&jb, ",");
        first = false;
        file_to_json(&jb, r);
    }
    jb_append_str(&jb, "]}");
    return jb_finish(&jb);
}

// ============================================================
// FFI 实现
// ============================================================
static FileRecord *find_file(long long id) {
    for (auto &r : g_files) if (r.id == id) return &r;
    return nullptr;
}

static long long ensure_tag(const std::string &name) {
    for (auto &t : g_tags) if (t.name == name) return t.id;
    TagRecord t; t.id = g_next_tag_id++; t.name = name; t.color = ""; t.builtin = 0;
    g_tags.push_back(t);
    return t.id;
}

extern "C" {

char *db_init(const char *data_dir) {
    g_data_dir = data_dir ? data_dir : "";
    if (!g_data_dir.empty()) {
        try { fs::create_directories(g_data_dir + "/files"); } catch (...) {}
    }
    store_load();
    return strdup("{\"error\":\"\"}");
}

char *db_import_file(const char *src, const char *default_tags) {
    if (!src || !*src) return strdup("{\"error\":\"no source\"}");
    fs::path src_path(src);
    std::string name = src_path.filename().string();
    std::string ext = file_ext(name);
    std::string uuid = std::to_string(now_epoch()) + "_" + std::to_string(g_next_file_id);
    std::string dest_dir = g_data_dir + "/files";
    std::string dest = dest_dir + "/" + uuid + "_" + name;
    try {
        fs::create_directories(dest_dir);
        fs::copy_file(src_path, dest, fs::copy_options::overwrite_existing);
    } catch (...) {
        return strdup("{\"error\":\"copy failed\"}");
    }

    FileRecord r;
    r.id = g_next_file_id++;
    r.uuid = uuid;
    r.name = name;
    r.ext = ext;
    r.mime = ext_mime(ext);
    r.size = (long long)fs::file_size(src_path);
    r.internal_path = dest;
    r.source_path = src;
    r.source_type = "filesystem";
    r.is_dir = 0;
    r.parent_id = 0;
    r.import_time = now_epoch();
    r.deleted = 0;
    g_files.push_back(r);

    // 打默认标签（内置 + 传入）
    long long def = ensure_tag(default_tags_for_ext(ext));
    g_file_tags[r.id].insert(def);
    if (default_tags && *default_tags) {
        for (auto &name_part : split(default_tags, ',')) {
            std::string tn = name_part;
            if (!tn.empty()) g_file_tags[r.id].insert(ensure_tag(tn));
        }
    }
    store_save();

    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"item\":");
    file_to_json(&jb, r);
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

char *db_list_files(int parent_id) {
    std::vector<FileRecord> out;
    for (auto &r : g_files) {
        if (r.deleted) continue;
        if (parent_id < 0 || r.parent_id == parent_id) out.push_back(r);
    }
    return file_list_json(out, "");
}

char *db_list_all(void) {
    std::vector<FileRecord> out;
    for (auto &r : g_files) if (!r.deleted) out.push_back(r);
    return file_list_json(out, "");
}

char *db_mkdir(const char *name, int parent_id) {
    if (!name || !*name) return strdup("{\"error\":\"empty name\"}");
    FileRecord r;
    r.id = g_next_file_id++;
    r.uuid = "dir_" + std::to_string(r.id);
    r.name = name;
    r.ext = "";
    r.mime = "inode/directory";
    r.size = 0;
    r.internal_path = "";
    r.source_path = "";
    r.source_type = "internal";
    r.is_dir = 1;
    r.parent_id = parent_id;
    r.import_time = now_epoch();
    r.deleted = 0;
    g_files.push_back(r);
    store_save();
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"item\":");
    file_to_json(&jb, r);
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

char *db_move(int file_id, int new_parent_id) {
    FileRecord *r = find_file(file_id);
    if (!r) return strdup("{\"error\":\"not found\"}");
    r->parent_id = new_parent_id;
    store_save();
    return strdup("{\"error\":\"\"}");
}

char *db_rename(int file_id, const char *name) {
    FileRecord *r = find_file(file_id);
    if (!r) return strdup("{\"error\":\"not found\"}");
    if (name && *name) r->name = name;
    store_save();
    return strdup("{\"error\":\"\"}");
}

char *db_delete(int file_id) {
    FileRecord *r = find_file(file_id);
    if (!r) return strdup("{\"error\":\"not found\"}");
    r->deleted = 1;
    store_save();
    return strdup("{\"error\":\"\"}");
}

char *db_tag_list(void) {
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    bool first = true;
    for (auto &t : g_tags) {
        if (!first) jb_append_str(&jb, ",");
        first = false;
        jb_append_str(&jb, "{\"id\":"); jb_append_int(&jb, t.id);
        jb_append_str(&jb, ",\"name\":"); jb_append_esc(&jb, t.name.c_str());
        jb_append_str(&jb, ",\"color\":"); jb_append_esc(&jb, t.color.c_str());
        jb_append_str(&jb, ",\"builtin\":"); jb_append_int(&jb, t.builtin);
        jb_append_str(&jb, "}");
    }
    jb_append_str(&jb, "]}");
    return jb_finish(&jb);
}

char *db_tag_create(const char *name, const char *color) {
    if (!name || !*name) return strdup("{\"error\":\"empty name\"}");
    for (auto &t : g_tags) if (t.name == name) return strdup("{\"error\":\"exists\"}");
    TagRecord t;
    t.id = g_next_tag_id++;
    t.name = name;
    t.color = color ? color : "";
    t.builtin = 0;
    g_tags.push_back(t);
    store_save();
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"id\":"); jb_append_int(&jb, t.id);
    jb_append_str(&jb, ",\"name\":"); jb_append_esc(&jb, t.name.c_str());
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

char *db_tag_add_to_files(const char *file_ids, const char *tag_ids) {
    if (!file_ids || !tag_ids) return strdup("{\"error\":\"bad args\"}");
    int added = 0;
    for (auto &fs : split(file_ids, ',')) {
        long long fid = atoll(fs.c_str());
        if (fid <= 0 || !find_file(fid)) continue;
        for (auto &ts : split(tag_ids, ',')) {
            long long tid = atoll(ts.c_str());
            if (tid <= 0) continue;
            bool exists = false;
            for (auto &t : g_tags) if (t.id == tid) { exists = true; break; }
            if (!exists) continue;
            if (g_file_tags[fid].insert(tid).second) added++;
        }
    }
    store_save();
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"added\":"); jb_append_int(&jb, added);
    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

char *db_tag_remove_from_file(int file_id, int tag_id) {
    auto it = g_file_tags.find(file_id);
    if (it != g_file_tags.end()) it->second.erase(tag_id);
    store_save();
    return strdup("{\"error\":\"\"}");
}

char *db_files_by_tag(int tag_id) {
    std::vector<FileRecord> out;
    for (auto &kv : g_file_tags) {
        if (kv.second.count(tag_id)) {
            FileRecord *r = find_file(kv.first);
            if (r && !r->deleted) out.push_back(*r);
        }
    }
    return file_list_json(out, "");
}

char *db_file_tags(int file_id) {
    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"error\":\"\",\"items\":[");
    bool first = true;
    auto it = g_file_tags.find(file_id);
    if (it != g_file_tags.end()) {
        for (long long tid : it->second) {
            for (auto &t : g_tags) {
                if (t.id == tid) {
                    if (!first) jb_append_str(&jb, ",");
                    first = false;
                    jb_append_str(&jb, "{\"id\":"); jb_append_int(&jb, t.id);
                    jb_append_str(&jb, ",\"name\":"); jb_append_esc(&jb, t.name.c_str());
                    jb_append_str(&jb, "}");
                    break;
                }
            }
        }
    }
    jb_append_str(&jb, "]}");
    return jb_finish(&jb);
}

void db_free_string(char *str) { if (str) free(str); }

} // extern "C"
