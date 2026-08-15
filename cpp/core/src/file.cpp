/*
 * FlutterFileManager - C++ Native Core File Operations
 * Core file system operations using POSIX APIs
 */

#include "file.h"
#include "file_internal.h"
#include "system.h"

// ============================================================
// 平台层：Windows 下引入 POSIX 兼容层，其他平台使用系统 POSIX。
// 平台源文件由 platform/<platform>/ 下的 CMake 配置引入。
// ============================================================
#ifdef _WIN32
#include "platform/src/windows/file.cpp"
#else
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <dirent.h>
#include <unistd.h>
#include <fcntl.h>
#if defined(__linux__)
#include <sys/sendfile.h>
#endif
#include <pwd.h>
#include <grp.h>
#include <errno.h>
#include <strings.h>
#include <fnmatch.h>
#include <libgen.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <climits>
// 内置哈希/加密实现（MD5/SHA1/SHA256/SHA512/CRC32/AES-256-CBC），
// 替代 OpenSSL 与 zlib，实现全平台无外部依赖
#include "crypto.h"
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <functional>
#include <filesystem>

namespace fs = std::filesystem;
namespace cc = common_crypto_alias;
using namespace cc;

// ============================================================
// MIME type mapping (simple extension-based)
// ============================================================

struct MimeTypeEntry {
    const char *ext;
    const char *mime;
};

static const MimeTypeEntry mime_map[] = {
    // Text
    {".txt", "text/plain"}, {".html", "text/html"}, {".htm", "text/html"},
    {".css", "text/css"}, {".js", "text/javascript"}, {".json", "application/json"},
    {".xml", "text/xml"}, {".csv", "text/csv"}, {".md", "text/markdown"},
    {".log", "text/plain"}, {".ini", "text/plain"}, {".conf", "text/plain"},
    {".yaml", "text/yaml"}, {".yml", "text/yaml"}, {".toml", "text/plain"},
    // Images
    {".jpg", "image/jpeg"}, {".jpeg", "image/jpeg"}, {".png", "image/png"},
    {".gif", "image/gif"}, {".bmp", "image/bmp"}, {".svg", "image/svg+xml"},
    {".webp", "image/webp"}, {".ico", "image/x-icon"}, {".tiff", "image/tiff"},
    {".tif", "image/tiff"}, {".heic", "image/heic"}, {".heif", "image/heif"},
    {".avif", "image/avif"}, {".raw", "image/x-raw"},
    // Audio
    {".mp3", "audio/mpeg"}, {".wav", "audio/wav"}, {".flac", "audio/flac"},
    {".aac", "audio/aac"}, {".ogg", "audio/ogg"}, {".wma", "audio/x-ms-wma"},
    {".m4a", "audio/mp4"}, {".opus", "audio/opus"}, {".mid", "audio/midi"},
    // Video
    {".mp4", "video/mp4"}, {".avi", "video/x-msvideo"}, {".mkv", "video/x-matroska"},
    {".mov", "video/quicktime"}, {".wmv", "video/x-ms-wmv"}, {".flv", "video/x-flv"},
    {".webm", "video/webm"}, {".m4v", "video/mp4"}, {".3gp", "video/3gpp"},
    // Archives
    {".zip", "application/zip"}, {".tar", "application/x-tar"},
    {".gz", "application/gzip"}, {".bz2", "application/x-bzip2"},
    {".xz", "application/x-xz"}, {".7z", "application/x-7z-compressed"},
    {".rar", "application/vnd.rar"}, {".zst", "application/zstd"},
    {".lz4", "application/x-lz4"}, {".iso", "application/x-iso9660-image"},
    {".deb", "application/x-debian-package"}, {".rpm", "application/x-rpm"},
    // Documents
    {".pdf", "application/pdf"}, {".doc", "application/msword"},
    {".docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"},
    {".xls", "application/vnd.ms-excel"},
    {".xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"},
    {".ppt", "application/vnd.ms-powerpoint"},
    {".pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation"},
    {".odt", "application/vnd.oasis.opendocument.text"},
    {".ods", "application/vnd.oasis.opendocument.spreadsheet"},
    // Code
    {".c", "text/x-c"}, {".cpp", "text/x-c++"}, {".h", "text/x-c"},
    {".hpp", "text/x-c++"}, {".java", "text/x-java-source"},
    {".py", "text/x-python"}, {".rs", "text/x-rust"}, {".go", "text/x-go"},
    {".kt", "text/x-kotlin"}, {".swift", "text/x-swift"},
    {".dart", "text/x-dart"}, {".sh", "text/x-shellscript"},
    {".bat", "text/x-msdos-batch"}, {".ps1", "text/x-powershell"},
    // Other
    {".apk", "application/vnd.android.package-archive"},
    {".exe", "application/x-executable"}, {".so", "application/x-sharedlib"},
    {".dll", "application/x-msdownload"}, {".bin", "application/octet-stream"},
    {".db", "application/x-sqlite3"},
};

static const int mime_map_size = sizeof(mime_map) / sizeof(mime_map[0]);

// ============================================================
// Helper: get MIME type from extension
// ============================================================
static std::string get_mime_for_extension(const char *filename) {
    if (!filename) return "application/octet-stream";
    const char *dot = strrchr(filename, '.');
    if (!dot || dot == filename) return "application/octet-stream";
    for (int i = 0; i < mime_map_size; i++) {
        if (strcasecmp(dot, mime_map[i].ext) == 0) {
            return mime_map[i].mime;
        }
    }
    return "application/octet-stream";
}

// ============================================================
// Helper: fill FileInfo from stat
// ============================================================
static void fill_file_info(FileInfo *info, const char *path, const char *name,
                           const struct stat *st, bool is_symlink,
                           const char *link_target) {
    memset(info, 0, sizeof(FileInfo));

    // Name and path
    strncpy(info->name, name ? name : "", sizeof(info->name) - 1);
    strncpy(info->path, path, sizeof(info->path) - 1);

    // Symlink target
    if (is_symlink && link_target) {
        strncpy(info->symlink_target, link_target, sizeof(info->symlink_target) - 1);
    }

    // File type
    if (is_symlink) {
        info->type = FILE_TYPE_SYMLINK;
    } else if (S_ISREG(st->st_mode)) {
        info->type = FILE_TYPE_REGULAR;
    } else if (S_ISDIR(st->st_mode)) {
        info->type = FILE_TYPE_DIRECTORY;
    } else if (S_ISBLK(st->st_mode)) {
        info->type = FILE_TYPE_BLOCK_DEVICE;
    } else if (S_ISCHR(st->st_mode)) {
        info->type = FILE_TYPE_CHAR_DEVICE;
    } else if (S_ISFIFO(st->st_mode)) {
        info->type = FILE_TYPE_FIFO;
    } else if (S_ISSOCK(st->st_mode)) {
        info->type = FILE_TYPE_SOCKET;
    } else {
        info->type = FILE_TYPE_UNKNOWN;
    }

    // Size, times
    info->size = (int64_t)st->st_size;
    info->modified_time = (int64_t)st->st_mtime;
    info->access_time = (int64_t)st->st_atime;
    info->created_time = (int64_t)st->st_ctime;

    // Permissions
    info->permissions = st->st_mode & 07777;
    info->uid = st->st_uid;
    info->gid = st->st_gid;

    // Owner/group names
    struct passwd *pw = getpwuid(st->st_uid);
    if (pw) strncpy(info->owner_name, pw->pw_name, sizeof(info->owner_name) - 1);
    else snprintf(info->owner_name, sizeof(info->owner_name), "%u", st->st_uid);

    struct group *gr = getgrgid(st->st_gid);
    if (gr) strncpy(info->group_name, gr->gr_name, sizeof(info->group_name) - 1);
    else snprintf(info->group_name, sizeof(info->group_name), "%u", st->st_gid);

    // MIME type
    std::string mime = get_mime_for_extension(info->name);
    strncpy(info->mime_type, mime.c_str(), sizeof(info->mime_type) - 1);

    // Access checks
    info->is_readable = (access(path, R_OK) == 0);
    info->is_writable = (access(path, W_OK) == 0);
    info->is_executable = (access(path, X_OK) == 0);

    // Hidden file
    info->is_hidden = (info->name[0] == '.');
}

// ============================================================
// List directory
// ============================================================
extern "C" DirListResult* file_ops_list_directory(const char *path, bool show_hidden) {
    DirListResult *result = (DirListResult*)calloc(1, sizeof(DirListResult));
    if (!result) return nullptr;

    DIR *dir = opendir(path);
    if (!dir) {
        snprintf(result->error, sizeof(result->error), "opendir failed: %s", strerror(errno));
        return result;
    }

    result->capacity = 256;
    result->items = (FileInfo*)calloc(result->capacity, sizeof(FileInfo));
    if (!result->items) {
        snprintf(result->error, sizeof(result->error), "memory allocation failed");
        closedir(dir);
        return result;
    }

    struct dirent *entry;
    while ((entry = readdir(dir)) != nullptr) {
        // Skip . and ..
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;

        // Skip hidden files if not requested
        if (!show_hidden && entry->d_name[0] == '.')
            continue;

        // Grow array if needed
        if (result->count >= result->capacity) {
            result->capacity *= 2;
            FileInfo *new_items = (FileInfo*)realloc(result->items,
                                                     result->capacity * sizeof(FileInfo));
            if (!new_items) {
                snprintf(result->error, sizeof(result->error), "memory realloc failed");
                break;
            }
            result->items = new_items;
        }

        // Build full path
        char fullpath[1024];
        snprintf(fullpath, sizeof(fullpath), "%s/%s", path, entry->d_name);

        // Use lstat to detect symlinks
        struct stat st;
        bool is_symlink = false;
        char link_target[1024] = {0};

        if (lstat(fullpath, &st) != 0) {
            continue; // skip inaccessible files
        }

        if (S_ISLNK(st.st_mode)) {
            is_symlink = true;
            ssize_t len = readlink(fullpath, link_target, sizeof(link_target) - 1);
            if (len > 0) link_target[len] = '\0';

            // Also stat the target for size/time
            struct stat target_st;
            if (stat(fullpath, &target_st) == 0) {
                st = target_st;
            }
        }

        fill_file_info(&result->items[result->count], fullpath, entry->d_name,
                       &st, is_symlink, link_target);
        result->count++;
    }

    closedir(dir);
    return result;
}

extern "C" void file_ops_free_dir_list(DirListResult *result) {
    if (result) {
        free(result->items);
        free(result);
    }
}

// ============================================================
// Get single file info
// ============================================================
extern "C" FileInfo* file_ops_get_file_info(const char *path) {
    FileInfo *info = (FileInfo*)calloc(1, sizeof(FileInfo));
    if (!info) return nullptr;

    struct stat st;
    if (lstat(path, &st) != 0) {
        free(info);
        return nullptr;
    }

    bool is_symlink = false;
    char link_target[1024] = {0};
    if (S_ISLNK(st.st_mode)) {
        is_symlink = true;
        ssize_t len = readlink(path, link_target, sizeof(link_target) - 1);
        if (len > 0) link_target[len] = '\0';
    }

    // Extract name from path
    const char *name = strrchr(path, '/');
    name = name ? name + 1 : path;

    fill_file_info(info, path, name, &st, is_symlink, link_target);
    return info;
}

extern "C" void file_ops_free_file_info(FileInfo *info) {
    free(info);
}

// ============================================================
// Create directory
// ============================================================
extern "C" int file_ops_create_directory(const char *path, char *error, int error_size) {
    if (mkdir(path, 0755) != 0) {
        if (error) snprintf(error, error_size, "mkdir failed: %s", strerror(errno));
        return -1;
    }
    return 0;
}

// ============================================================
// Create empty file
// ============================================================
extern "C" int file_ops_create_file(const char *path, char *error, int error_size) {
    int fd = open(path, O_CREAT | O_WRONLY | O_EXCL, 0644);
    if (fd < 0) {
        if (error) snprintf(error, error_size, "create file failed: %s", strerror(errno));
        return -1;
    }
    close(fd);
    return 0;
}

// ============================================================
// Delete file
// ============================================================
extern "C" int file_ops_delete_file(const char *path, char *error, int error_size) {
    if (unlink(path) != 0) {
        if (error) snprintf(error, error_size, "delete file failed: %s", strerror(errno));
        return -1;
    }
    return 0;
}

// ============================================================
// Delete directory (recursive)
// ============================================================
static int remove_directory_recursive(const char *path) {
    DIR *dir = opendir(path);
    if (!dir) return -1;

    struct dirent *entry;
    int ret = 0;

    while ((entry = readdir(dir)) != nullptr) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;

        char fullpath[1024];
        snprintf(fullpath, sizeof(fullpath), "%s/%s", path, entry->d_name);

        struct stat st;
        if (lstat(fullpath, &st) != 0) {
            ret = -1;
            continue;
        }

        if (S_ISDIR(st.st_mode)) {
            if (remove_directory_recursive(fullpath) != 0) {
                ret = -1;
            }
        } else {
            if (unlink(fullpath) != 0) {
                ret = -1;
            }
        }
    }

    closedir(dir);
    if (rmdir(path) != 0) ret = -1;
    return ret;
}

extern "C" int file_ops_delete_directory(const char *path, bool recursive,
                                         char *error, int error_size) {
    if (recursive) {
        if (remove_directory_recursive(path) != 0) {
            if (error) snprintf(error, error_size, "recursive delete failed: %s", strerror(errno));
            return -1;
        }
    } else {
        if (rmdir(path) != 0) {
            if (error) snprintf(error, error_size, "rmdir failed: %s", strerror(errno));
            return -1;
        }
    }
    return 0;
}

// ============================================================
// Rename
// ============================================================
extern "C" int file_ops_rename(const char *old_path, const char *new_path,
                               char *error, int error_size) {
    if (rename(old_path, new_path) != 0) {
        if (error) snprintf(error, error_size, "rename failed: %s", strerror(errno));
        return -1;
    }
    return 0;
}

// ============================================================
// Copy file
// ============================================================
extern "C" int file_ops_copy_file(const char *src, const char *dst,
                                  char *error, int error_size) {
    int fd_src = open(src, O_RDONLY);
    if (fd_src < 0) {
        if (error) snprintf(error, error_size, "open source failed: %s", strerror(errno));
        return -1;
    }

    struct stat st;
    if (fstat(fd_src, &st) != 0) {
        if (error) snprintf(error, error_size, "fstat failed: %s", strerror(errno));
        close(fd_src);
        return -1;
    }

    int fd_dst = open(dst, O_WRONLY | O_CREAT | O_TRUNC, st.st_mode);
    if (fd_dst < 0) {
        if (error) snprintf(error, error_size, "open dest failed: %s", strerror(errno));
        close(fd_src);
        return -1;
    }

    // 跨平台拷贝：Linux 用 sendfile 零拷贝，其他平台用 read/write 循环。
    int ret = 0;
#if defined(__linux__)
    off_t offset = 0;
    ssize_t remaining = st.st_size;

    while (remaining > 0) {
        ssize_t sent = sendfile(fd_dst, fd_src, &offset, remaining > 0 ? remaining : 65536);
        if (sent <= 0) {
            if (sent < 0 && errno == EINTR) continue;
            if (error) snprintf(error, error_size, "sendfile failed: %s", strerror(errno));
            ret = -1;
            break;
        }
        remaining -= sent;
    }
#else
    char buf[65536];
    ssize_t n;
    while ((n = read(fd_src, buf, sizeof(buf))) > 0) {
        char *p = buf;
        while (n > 0) {
            ssize_t w = write(fd_dst, p, (size_t)n);
            if (w <= 0) {
                if (w < 0 && errno == EINTR) continue;
                if (error) snprintf(error, error_size, "write failed: %s", strerror(errno));
                ret = -1;
                break;
            }
            p += w;
            n -= w;
        }
        if (ret != 0) break;
    }
    if (n < 0 && ret == 0) {
        if (error) snprintf(error, error_size, "read failed: %s", strerror(errno));
        ret = -1;
    }
#endif

    close(fd_src);
    close(fd_dst);
    return ret;
}

// ============================================================
// Move file (rename or copy+delete)
// ============================================================
extern "C" int file_ops_move_file(const char *src, const char *dst,
                                  char *error, int error_size) {
    if (rename(src, dst) == 0) {
        return 0;
    }
    // Cross-device move: copy then delete
    if (file_ops_copy_file(src, dst, error, error_size) != 0) {
        return -1;
    }
    if (unlink(src) != 0) {
        if (error) snprintf(error, error_size, "unlink after copy failed: %s", strerror(errno));
        return -1;
    }
    return 0;
}

// ============================================================
// Existence check
// ============================================================
extern "C" int file_ops_exists(const char *path) {
    struct stat st;
    if (lstat(path, &st) == 0) return 1;
    return 0;
}

extern "C" int file_ops_is_directory(const char *path) {
    struct stat st;
    if (stat(path, &st) == 0 && S_ISDIR(st.st_mode)) return 1;
    return 0;
}

// ============================================================
// Chmod
// ============================================================
extern "C" int file_ops_chmod(const char *path, uint32_t mode,
                              char *error, int error_size) {
    if (chmod(path, mode) != 0) {
        if (error) snprintf(error, error_size, "chmod failed: %s", strerror(errno));
        return -1;
    }
    return 0;
}

// Function: access() - from Syscall.kt:28
extern "C" int file_ops_access(const char *path, int mode) {
    return access(path, mode) == 0 ? 1 : 0;
}

// Function: chown() - from Syscall.kt:34
extern "C" int file_ops_chown(const char *path, uint32_t uid, uint32_t gid,
                              char *error, int error_size) {
    if (chown(path, uid, gid) != 0) {
        if (error) snprintf(error, error_size, "chown failed: %s", strerror(errno));
        return -1;
    }
    return 0;
}

// Function: lchown() - from Syscall.kt:128
extern "C" int file_ops_lchown(const char *path, uint32_t uid, uint32_t gid,
                               char *error, int error_size) {
    if (lchown(path, uid, gid) != 0) {
        if (error) snprintf(error, error_size, "lchown failed: %s", strerror(errno));
        return -1;
    }
    return 0;
}

// Function: symlink() - from Syscall.kt:293
extern "C" int file_ops_symlink(const char *target, const char *linkpath,
                                char *error, int error_size) {
    if (symlink(target, linkpath) != 0) {
        if (error) snprintf(error, error_size, "symlink failed: %s", strerror(errno));
        return -1;
    }
    return 0;
}

// Function: link() - from Syscall.kt:151
extern "C" int file_ops_link(const char *oldpath, const char *newpath,
                             char *error, int error_size) {
    if (link(oldpath, newpath) != 0) {
        if (error) snprintf(error, error_size, "link failed: %s", strerror(errno));
        return -1;
    }
    return 0;
}

// Function: realpath() - from Syscall.kt:215
static char g_realpath_buffer[PATH_MAX];
extern "C" const char* file_ops_realpath(const char *path) {
    char *result = realpath(path, g_realpath_buffer);
    if (result) return g_realpath_buffer;
    return nullptr;
}

// Function: readlink() - enhanced from Syscall.kt:212
static char g_readlink_buffer[1024];
extern "C" const char* file_ops_readlink(const char *path) {
    ssize_t len = readlink(path, g_readlink_buffer, sizeof(g_readlink_buffer) - 1);
    if (len < 0) return nullptr;
    g_readlink_buffer[len] = '\0';
    return g_readlink_buffer;
}

// ============================================================
// Search files
// ============================================================
static void search_recursive(const char *dir, const char *pattern, int max_results,
                             SearchResultList *result) {
    DIR *d = opendir(dir);
    if (!d) return;

    struct dirent *entry;
    while ((entry = readdir(d)) != nullptr && result->count < max_results) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;

        char fullpath[1024];
        snprintf(fullpath, sizeof(fullpath), "%s/%s", dir, entry->d_name);

        if (fnmatch(pattern, entry->d_name, FNM_CASEFOLD) == 0) {
            if (result->count >= result->capacity) {
                result->capacity *= 2;
                result->items = (SearchResult*)realloc(result->items,
                                                       result->capacity * sizeof(SearchResult));
            }
            SearchResult *sr = &result->items[result->count];
            strncpy(sr->path, fullpath, sizeof(sr->path) - 1);
            strncpy(sr->name, entry->d_name, sizeof(sr->name) - 1);

            struct stat st;
            if (lstat(fullpath, &st) == 0) {
                if (S_ISLNK(st.st_mode)) sr->type = FILE_TYPE_SYMLINK;
                else if (S_ISDIR(st.st_mode)) sr->type = FILE_TYPE_DIRECTORY;
                else sr->type = FILE_TYPE_REGULAR;
                sr->size = st.st_size;
                sr->modified_time = st.st_mtime;
            }
            result->count++;
        }

        // Recurse into directories
        struct stat st;
        if (lstat(fullpath, &st) == 0 && S_ISDIR(st.st_mode) && !S_ISLNK(st.st_mode)) {
            search_recursive(fullpath, pattern, max_results, result);
        }
    }
    closedir(d);
}

extern "C" SearchResultList* file_ops_search_files(const char *dir, const char *pattern,
                                                   int max_results) {
    SearchResultList *result = (SearchResultList*)calloc(1, sizeof(SearchResultList));
    if (!result) return nullptr;
    result->capacity = 256;
    result->items = (SearchResult*)calloc(result->capacity, sizeof(SearchResult));
    if (!result->items) {
        snprintf(result->error, sizeof(result->error), "memory allocation failed");
        return result;
    }
    search_recursive(dir, pattern, max_results, result);
    return result;
}

extern "C" void file_ops_free_search_results(SearchResultList *result) {
    if (result) {
        free(result->items);
        free(result);
    }
}

// ============================================================
// Hash computation (MD5, SHA1, SHA256, SHA512, CRC32)
// ============================================================
static void hash_to_hex(const unsigned char *hash, int len, char *out) {
    for (int i = 0; i < len; i++) {
        snprintf(out + i * 2, 3, "%02x", hash[i]);
    }
}

extern "C" HashResult* file_ops_compute_hash(const char *path) {
    HashResult *result = (HashResult*)calloc(1, sizeof(HashResult));
    if (!result) return nullptr;

    FILE *fp = fopen(path, "rb");
    if (!fp) {
        snprintf(result->error, sizeof(result->error), "fopen failed: %s", strerror(errno));
        return result;
    }

    // 内置流式哈希上下文（MD5/SHA1/SHA256/SHA512/CRC32）
    MD5Context md5_ctx;
    SHA1Context sha1_ctx;
    SHA256Context sha256_ctx;
    SHA512Context sha512_ctx;
    common_md5_init(&md5_ctx);
    common_sha1_init(&sha1_ctx);
    common_sha256_init(&sha256_ctx);
    common_sha512_init(&sha512_ctx);
    uint32_t crc = 0;

    unsigned char buf[65536];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), fp)) > 0) {
        common_md5_update(&md5_ctx, buf, n);
        common_sha1_update(&sha1_ctx, buf, n);
        common_sha256_update(&sha256_ctx, buf, n);
        common_sha512_update(&sha512_ctx, buf, n);
        crc = common_crc32_update(crc, buf, n);
    }
    fclose(fp);

    // Finalize
    unsigned char md5_hash[16], sha1_hash[20], sha256_hash[32], sha512_hash[64];
    common_md5_final(&md5_ctx, md5_hash);
    common_sha1_final(&sha1_ctx, sha1_hash);
    common_sha256_final(&sha256_ctx, sha256_hash);
    common_sha512_final(&sha512_ctx, sha512_hash);

    // Convert to hex
    hash_to_hex(md5_hash, 16, result->md5);
    hash_to_hex(sha1_hash, 20, result->sha1);
    hash_to_hex(sha256_hash, 32, result->sha256);
    hash_to_hex(sha512_hash, 64, result->sha512);
    snprintf(result->crc32, sizeof(result->crc32), "%08lx", (unsigned long)crc);

    return result;
}

extern "C" void file_ops_free_hash_result(HashResult *result) {
    free(result);
}

// ============================================================
// Disk usage
// ============================================================
extern "C" DiskUsageInfo* file_ops_get_disk_usage(const char *path) {
    DiskUsageInfo *info = (DiskUsageInfo*)calloc(1, sizeof(DiskUsageInfo));
    if (!info) return nullptr;

    struct statvfs vfs;
    if (statvfs(path, &vfs) != 0) {
        snprintf(info->error, sizeof(info->error), "statvfs failed: %s", strerror(errno));
        return info;
    }

    info->total_space = (int64_t)vfs.f_blocks * vfs.f_frsize;
    info->free_space = (int64_t)vfs.f_bavail * vfs.f_frsize;
    info->used_space = info->total_space - info->free_space;

    return info;
}

extern "C" void file_ops_free_disk_usage(DiskUsageInfo *info) {
    free(info);
}

// ============================================================
// MIME type
// ============================================================
static char g_mime_buffer[128];

extern "C" const char* file_ops_get_mime_type(const char *filename) {
    std::string mime = get_mime_for_extension(filename);
    strncpy(g_mime_buffer, mime.c_str(), sizeof(g_mime_buffer) - 1);
    g_mime_buffer[sizeof(g_mime_buffer) - 1] = '\0';
    return g_mime_buffer;
}

// ============================================================
// Home / Root directory
// ============================================================
static char g_path_buffer[1024];

// 标准目录统一由 system 模块提供（跨平台），file 模块不自行做平台判断。
extern "C" const char* file_ops_get_home_dir(void) {
    char *home = system_standard_dir("home");
    if (home) {
        strncpy(g_path_buffer, home, sizeof(g_path_buffer) - 1);
        system_free_string(home);
    } else {
        strncpy(g_path_buffer, "/", sizeof(g_path_buffer) - 1);
    }
    g_path_buffer[sizeof(g_path_buffer) - 1] = '\0';
    return g_path_buffer;
}

extern "C" const char* file_ops_get_root_dir(void) {
    char *root = system_standard_dir("root");
    if (root) {
        strncpy(g_path_buffer, root, sizeof(g_path_buffer) - 1);
        system_free_string(root);
    } else {
        strncpy(g_path_buffer, "/", sizeof(g_path_buffer) - 1);
    }
    g_path_buffer[sizeof(g_path_buffer) - 1] = '\0';
    return g_path_buffer;
}

extern "C" void file_ops_free_string(const char *str) {
    // For static buffers, no-op. Included for API symmetry.
    (void)str;
}

// ============================================================
// Duplicate finder: find files with same size, then same content hash
// ============================================================
extern "C" SearchResultList* file_ops_find_duplicates(const char *dir, int max_results) {
    SearchResultList *result = (SearchResultList*)calloc(1, sizeof(SearchResultList));
    if (!result) return nullptr;
    result->capacity = 256;
    result->items = (SearchResult*)calloc(result->capacity, sizeof(SearchResult));
    if (!result->items) return result;

    // Step 1: Group files by size
    std::map<int64_t, std::vector<std::string>> size_groups;

    try {
        for (const auto &entry : fs::recursive_directory_iterator(dir,
                fs::directory_options::skip_permission_denied)) {
            if (result->count >= max_results) break;
            if (entry.is_regular_file()) {
                int64_t sz = entry.file_size();
                if (sz > 0) {
                    size_groups[sz].push_back(entry.path().string());
                }
            }
        }
    } catch (...) {}

    // Step 2: For groups with >1 file, compare by CRC32
    std::map<uint32_t, std::vector<std::string>> hash_groups;

    for (auto &[sz, paths] : size_groups) {
        if (paths.size() < 2) continue;
        for (auto &p : paths) {
            FILE *fp = fopen(p.c_str(), "rb");
            if (!fp) continue;

            uint32_t crc = 0;
            unsigned char buf[65536];
            size_t n;
            while ((n = fread(buf, 1, sizeof(buf), fp)) > 0) {
                crc = common_crc32_update(crc, buf, n);
            }
            fclose(fp);
            hash_groups[crc].push_back(p);
        }
    }

    // Step 3: Report duplicates (keep first, report rest)
    for (auto &[h, paths] : hash_groups) {
        if (paths.size() < 2) continue;
        // Skip first (original), report rest as duplicates
        for (size_t i = 1; i < paths.size() && result->count < max_results; i++) {
            if (result->count >= result->capacity) {
                result->capacity *= 2;
                result->items = (SearchResult*)realloc(result->items,
                                                       result->capacity * sizeof(SearchResult));
            }
            SearchResult *sr = &result->items[result->count];
            strncpy(sr->path, paths[i].c_str(), sizeof(sr->path) - 1);

            const char *name = strrchr(paths[i].c_str(), '/');
            strncpy(sr->name, name ? name + 1 : paths[i].c_str(), sizeof(sr->name) - 1);

            struct stat st;
            if (stat(paths[i].c_str(), &st) == 0) {
                sr->type = FILE_TYPE_REGULAR;
                sr->size = st.st_size;
                sr->modified_time = st.st_mtime;
            }
            result->count++;
        }
    }

    return result;
}

// ============================================================
// Empty files finder
// ============================================================
extern "C" SearchResultList* file_ops_find_empty_files(const char *dir, int max_results) {
    SearchResultList *result = (SearchResultList*)calloc(1, sizeof(SearchResultList));
    if (!result) return nullptr;
    result->capacity = 256;
    result->items = (SearchResult*)calloc(result->capacity, sizeof(SearchResult));
    if (!result->items) return result;

    try {
        for (const auto &entry : fs::recursive_directory_iterator(dir,
                fs::directory_options::skip_permission_denied)) {
            if (result->count >= max_results) break;

            bool is_empty = false;
            if (entry.is_regular_file() && entry.file_size() == 0) {
                is_empty = true;
            } else if (entry.is_directory()) {
                // Check if directory is empty
                auto begin = fs::directory_iterator(entry.path(),
                    fs::directory_options::skip_permission_denied);
                if (begin == end(begin)) is_empty = true;
            }

            if (is_empty) {
                if (result->count >= result->capacity) {
                    result->capacity *= 2;
                    result->items = (SearchResult*)realloc(result->items,
                                                           result->capacity * sizeof(SearchResult));
                }
                SearchResult *sr = &result->items[result->count];
                strncpy(sr->path, entry.path().string().c_str(), sizeof(sr->path) - 1);

                std::string name = entry.path().filename().string();
                strncpy(sr->name, name.c_str(), sizeof(sr->name) - 1);

                sr->type = entry.is_directory() ? FILE_TYPE_DIRECTORY : FILE_TYPE_REGULAR;
                sr->size = entry.is_regular_file() ? entry.file_size() : 0;

                struct stat st;
                if (stat(entry.path().string().c_str(), &st) == 0) {
                    sr->modified_time = st.st_mtime;
                }
                result->count++;
            }
        }
    } catch (...) {}

    return result;
}

// ============================================================
// Recent files (modified within given days)
// ============================================================
extern "C" SearchResultList* file_ops_get_recent_files(const char *dir, int days, int max_results) {
    SearchResultList *result = (SearchResultList*)calloc(1, sizeof(SearchResultList));
    if (!result) return nullptr;
    result->capacity = 256;
    result->items = (SearchResult*)calloc(result->capacity, sizeof(SearchResult));
    if (!result->items) return result;

    time_t now = time(nullptr);
    time_t cutoff = now - (time_t)days * 86400;

    try {
        for (const auto &entry : fs::recursive_directory_iterator(dir,
                fs::directory_options::skip_permission_denied)) {
            if (result->count >= max_results) break;
            if (!entry.is_regular_file()) continue;

            struct stat st;
            if (stat(entry.path().string().c_str(), &st) != 0) continue;
            if (st.st_mtime < cutoff) continue;

            if (result->count >= result->capacity) {
                result->capacity *= 2;
                result->items = (SearchResult*)realloc(result->items,
                                                       result->capacity * sizeof(SearchResult));
            }
            SearchResult *sr = &result->items[result->count];
            strncpy(sr->path, entry.path().string().c_str(), sizeof(sr->path) - 1);
            std::string name = entry.path().filename().string();
            strncpy(sr->name, name.c_str(), sizeof(sr->name) - 1);
            sr->type = FILE_TYPE_REGULAR;
            sr->size = st.st_size;
            sr->modified_time = st.st_mtime;
            result->count++;
        }
    } catch (...) {}

    return result;
}

// ============================================================
// Encryption / Decryption (AES-256-CBC)
// 内置 AES 实现。Key = SHA256(password), IV = first 16 bytes written to file.
// 文件格式： [16B IV][AES-256-CBC 密文 + PKCS7 padding]
// ============================================================

static int derive_key_iv(const char *password, unsigned char *key, unsigned char *iv) {
    // key = SHA256(password) => 32 bytes (AES-256)
    common_sha256_once((const unsigned char*)password, strlen(password), key);
    // iv: first 16 bytes of SHA256(key) for deterministic IV (matching Dart encrypt impl)
    unsigned char tmp[32];
    common_sha256_once(key, 32, tmp);
    memcpy(iv, tmp, 16);
    return 0;
}

extern "C" int file_ops_encrypt_file(const char *src, const char *dst, const char *password,
                                     char *error, int error_size) {
    if (!password || !password[0]) {
        if (error) snprintf(error, error_size, "password is empty");
        return -1;
    }

    unsigned char key[32], full_iv[32];
    derive_key_iv(password, key, full_iv);

    FILE *fp_in = fopen(src, "rb");
    if (!fp_in) {
        if (error) snprintf(error, error_size, "open source failed: %s", strerror(errno));
        return -1;
    }

    FILE *fp_out = fopen(dst, "wb");
    if (!fp_out) {
        if (error) snprintf(error, error_size, "open dest failed: %s", strerror(errno));
        fclose(fp_in);
        return -1;
    }

    // Write 16-byte IV prefix (matching Dart: iv.bytes + encrypted.bytes)
    fwrite(full_iv, 1, 16, fp_out);

    AES256Key ks;
    common_aes256_key_expand(&ks, key);

    unsigned char chain[16];
    memcpy(chain, full_iv, 16);
    unsigned char pending[16];
    size_t pending_len = 0;
    unsigned char inbuf[65536], outbuf[65536];
    size_t n;
    int ret = 0;

    while ((n = fread(inbuf, 1, sizeof(inbuf), fp_in)) > 0) {
        size_t off = 0;
        if (pending_len > 0) {
            size_t need = 16 - pending_len;
            if (need > n) need = n;
            memcpy(pending + pending_len, inbuf, need);
            pending_len += need;
            off = need;
            if (pending_len == 16) {
                for (int i = 0; i < 16; i++) pending[i] ^= chain[i];
                common_aes256_encrypt_block(&ks, pending, outbuf);
                memcpy(chain, outbuf, 16);
                fwrite(outbuf, 1, 16, fp_out);
                pending_len = 0;
            }
        }
        size_t blocks = (n - off) / 16;
        size_t out_pos = 0;
        for (size_t b = 0; b < blocks; b++) {
            size_t idx = off + b * 16;
            for (int i = 0; i < 16; i++) inbuf[idx + i] ^= chain[i];
            common_aes256_encrypt_block(&ks, inbuf + idx, outbuf + out_pos);
            memcpy(chain, outbuf + out_pos, 16);
            out_pos += 16;
        }
        if (out_pos > 0) fwrite(outbuf, 1, out_pos, fp_out);
        size_t rem_start = off + blocks * 16;
        if (rem_start < n) {
            pending_len = n - rem_start;
            memcpy(pending, inbuf + rem_start, pending_len);
        }
    }

    // PKCS7 补全最后一块
    unsigned char pad = (unsigned char)(16 - pending_len);
    unsigned char last[16];
    memcpy(last, pending, pending_len);
    for (size_t i = pending_len; i < 16; i++) last[i] = pad;
    for (int i = 0; i < 16; i++) last[i] ^= chain[i];
    common_aes256_encrypt_block(&ks, last, outbuf);
    fwrite(outbuf, 1, 16, fp_out);

    fclose(fp_in);
    fclose(fp_out);

    if (ret != 0 && error) {
        snprintf(error, error_size, "encryption failed");
    }
    return ret;
}

extern "C" int file_ops_decrypt_file(const char *src, const char *dst, const char *password,
                                     char *error, int error_size) {
    if (!password || !password[0]) {
        if (error) snprintf(error, error_size, "password is empty");
        return -1;
    }

    unsigned char key[32], full_iv[32];
    derive_key_iv(password, key, full_iv);

    FILE *fp_in = fopen(src, "rb");
    if (!fp_in) {
        if (error) snprintf(error, error_size, "open source failed: %s", strerror(errno));
        return -1;
    }

    // Read 16-byte IV prefix
    unsigned char file_iv[16];
    if (fread(file_iv, 1, 16, fp_in) != 16) {
        if (error) snprintf(error, error_size, "invalid encrypted file (too short)");
        fclose(fp_in);
        return -1;
    }

    // Use the IV from the file for decryption
    FILE *fp_out = fopen(dst, "wb");
    if (!fp_out) {
        if (error) snprintf(error, error_size, "open dest failed: %s", strerror(errno));
        fclose(fp_in);
        return -1;
    }

    AES256Key ks;
    common_aes256_key_expand(&ks, key);

    unsigned char prev[16];
    memcpy(prev, file_iv, 16);
    unsigned char lastbuf[16];
    size_t lastcnt = 0;
    unsigned char inbuf[65536], outbuf[16];
    size_t n;
    int ret = 0;

    while ((n = fread(inbuf, 1, sizeof(inbuf), fp_in)) > 0) {
        size_t off = 0;
        if (lastcnt == 16) {
            common_aes256_decrypt_block(&ks, lastbuf, outbuf);
            for (int i = 0; i < 16; i++) outbuf[i] ^= prev[i];
            fwrite(outbuf, 1, 16, fp_out);
            memcpy(prev, lastbuf, 16);
            lastcnt = 0;
        }
        while (off + 32 <= n) {
            common_aes256_decrypt_block(&ks, inbuf + off, outbuf);
            for (int i = 0; i < 16; i++) outbuf[i] ^= prev[i];
            fwrite(outbuf, 1, 16, fp_out);
            memcpy(prev, inbuf + off, 16);
            off += 16;
        }
        if (off < n) {
            memcpy(lastbuf, inbuf + off, n - off);
            lastcnt = n - off;
        }
    }

    if (ret == 0) {
        if (lastcnt != 16) {
            ret = -1; // 密文长度非法
        } else {
            common_aes256_decrypt_block(&ks, lastbuf, outbuf);
            for (int i = 0; i < 16; i++) outbuf[i] ^= prev[i];
            unsigned char pad = outbuf[15];
            if (pad < 1 || pad > 16) {
                ret = -1;
            } else {
                for (int i = 16 - pad; i < 16; i++) {
                    if (outbuf[i] != pad) { ret = -1; break; }
                }
                if (ret == 0) fwrite(outbuf, 1, 16 - pad, fp_out);
            }
        }
    }

    fclose(fp_in);
    fclose(fp_out);

    if (ret != 0 && error) {
        snprintf(error, error_size, "decryption failed (wrong password or corrupted file)");
    }
    return ret;
}

// ============================================================
// File content I/O (for viewers)
// ============================================================

extern "C" char* file_ops_read_file_text(const char *path) {
    FILE *fp = fopen(path, "rb");
    if (!fp) return nullptr;

    fseek(fp, 0, SEEK_END);
    long size = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    if (size < 0) { fclose(fp); return nullptr; }

    char *buf = (char*)malloc(size + 1);
    if (!buf) { fclose(fp); return nullptr; }

    size_t read = fread(buf, 1, size, fp);
    fclose(fp);
    buf[read] = '\0';
    return buf;
}

extern "C" int file_ops_write_file_text(const char *path, const char *content,
                                         char *error, int error_size) {
    FILE *fp = fopen(path, "wb");
    if (!fp) {
        if (error) snprintf(error, error_size, "open for write failed: %s", strerror(errno));
        return -1;
    }
    size_t len = strlen(content);
    size_t written = fwrite(content, 1, len, fp);
    fclose(fp);
    if (written != len) {
        if (error) snprintf(error, error_size, "short write");
        return -1;
    }
    return 0;
}

extern "C" unsigned char* file_ops_read_file_chunk(const char *path, int64_t offset,
                                                    int length, int *out_len) {
    FILE *fp = fopen(path, "rb");
    if (!fp) { if (out_len) *out_len = 0; return nullptr; }

    fseek(fp, 0, SEEK_END);
    int64_t file_size = ftell(fp);

    if (offset >= file_size) { fclose(fp); if (out_len) *out_len = 0; return nullptr; }

    int64_t actual = length;
    if (offset + actual > file_size) actual = file_size - offset;

    unsigned char *buf = (unsigned char*)malloc(actual);
    if (!buf) { fclose(fp); if (out_len) *out_len = 0; return nullptr; }

    fseek(fp, offset, SEEK_SET);
    size_t read = fread(buf, 1, (size_t)actual, fp);
    fclose(fp);

    if (out_len) *out_len = (int)read;
    return buf;
}

extern "C" unsigned char* file_ops_read_file_bytes(const char *path, int *out_len) {
    FILE *fp = fopen(path, "rb");
    if (!fp) { if (out_len) *out_len = 0; return nullptr; }

    fseek(fp, 0, SEEK_END);
    long size = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    if (size < 0) { fclose(fp); if (out_len) *out_len = 0; return nullptr; }

    unsigned char *buf = (unsigned char*)malloc(size);
    if (!buf) { fclose(fp); if (out_len) *out_len = 0; return nullptr; }

    size_t read = fread(buf, 1, size, fp);
    fclose(fp);

    if (out_len) *out_len = (int)read;
    return buf;
}

// ============================================================
// ====================  FILE TOOLS  ==========================
// 编码检测 / 文本统计 / 文件比较 / 分割 / 合并
// 纯标准库实现，无系统依赖，全平台可用
// ============================================================

// 校验单个 UTF-8 序列，返回 1=合法并输出消耗字节数，0=非法
static int utf8_sequence_ok(const unsigned char *s, size_t len, size_t *consumed) {
    if (len == 0) return 0;
    unsigned char c = s[0];
    if (c < 0x80) { *consumed = 1; return 1; }
    if ((c & 0xE0) == 0xC0) {
        if (len < 2 || (s[1] & 0xC0) != 0x80) return 0;
        *consumed = 2; return 1;
    }
    if ((c & 0xF0) == 0xE0) {
        if (len < 3 || (s[1] & 0xC0) != 0x80 || (s[2] & 0xC0) != 0x80) return 0;
        *consumed = 3; return 1;
    }
    if ((c & 0xF8) == 0xF0) {
        if (len < 4 || (s[1] & 0xC0) != 0x80 || (s[2] & 0xC0) != 0x80 || (s[3] & 0xC0) != 0x80) return 0;
        *consumed = 4; return 1;
    }
    return 0;
}

static char g_encoding_buffer[32];

extern "C" const char* file_ops_detect_encoding(const char *path) {
    unsigned char buf[8192];
    FILE *fp = fopen(path, "rb");
    if (!fp) { snprintf(g_encoding_buffer, sizeof(g_encoding_buffer), "unknown"); return g_encoding_buffer; }
    size_t n = fread(buf, 1, sizeof(buf), fp);
    fclose(fp);
    if (n == 0) { snprintf(g_encoding_buffer, sizeof(g_encoding_buffer), "ascii"); return g_encoding_buffer; }

    // BOM 检测
    if (n >= 4 && buf[0] == 0xFF && buf[1] == 0xFE && buf[2] == 0x00 && buf[3] == 0x00) { snprintf(g_encoding_buffer, sizeof(g_encoding_buffer), "utf-32le"); return g_encoding_buffer; }
    if (n >= 4 && buf[0] == 0x00 && buf[1] == 0x00 && buf[2] == 0xFE && buf[3] == 0xFF) { snprintf(g_encoding_buffer, sizeof(g_encoding_buffer), "utf-32be"); return g_encoding_buffer; }
    if (n >= 3 && buf[0] == 0xEF && buf[1] == 0xBB && buf[2] == 0xBF) { snprintf(g_encoding_buffer, sizeof(g_encoding_buffer), "utf-8"); return g_encoding_buffer; }
    if (n >= 2 && buf[0] == 0xFF && buf[1] == 0xFE) { snprintf(g_encoding_buffer, sizeof(g_encoding_buffer), "utf-16le"); return g_encoding_buffer; }
    if (n >= 2 && buf[0] == 0xFE && buf[1] == 0xFF) { snprintf(g_encoding_buffer, sizeof(g_encoding_buffer), "utf-16be"); return g_encoding_buffer; }

    // 无 BOM：0x00 字节占比高 → UTF-16/32
    size_t zeros = 0;
    for (size_t i = 0; i < n; i++) if (buf[i] == 0x00) zeros++;
    if (zeros > n / 4) {
        size_t even_zero = 0, odd_zero = 0;
        for (size_t i = 0; i + 1 < n; i += 2) {
            if (buf[i] == 0) even_zero++;
            if (buf[i + 1] == 0) odd_zero++;
        }
        snprintf(g_encoding_buffer, sizeof(g_encoding_buffer),
                 even_zero > odd_zero ? "utf-16be" : "utf-16le");
        return g_encoding_buffer;
    }

    // UTF-8 严格校验
    size_t pos = 0, non_ascii = 0;
    int utf8_ok = 1;
    while (pos < n) {
        size_t consumed = 0;
        if (!utf8_sequence_ok(buf, n - pos, &consumed)) { utf8_ok = 0; break; }
        if (buf[pos] >= 0x80) non_ascii++;
        pos += consumed;
    }
    if (utf8_ok) {
        snprintf(g_encoding_buffer, sizeof(g_encoding_buffer), non_ascii > 0 ? "utf-8" : "ascii");
        return g_encoding_buffer;
    }

    // 高字节占比高 → GBK 候选，否则视为二进制
    size_t high = 0;
    for (size_t i = 0; i < n; i++) if (buf[i] >= 0x80) high++;
    snprintf(g_encoding_buffer, sizeof(g_encoding_buffer), high > n / 8 ? "gbk" : "binary");
    return g_encoding_buffer;
}

extern "C" int file_ops_text_stats(const char *path, long long *bytes, long long *chars, long long *lines, long long *words) {
    if (bytes) *bytes = 0;
    if (chars) *chars = 0;
    if (lines) *lines = 0;
    if (words) *words = 0;
    FILE *fp = fopen(path, "rb");
    if (!fp) return -1;
    unsigned char buf[65536];
    long long total = 0, char_count = 0, line_count = 0, word_count = 0;
    int in_word = 0;
    unsigned char last_byte = 0;
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), fp)) > 0) {
        total += (long long)n;
        size_t i = 0;
        while (i < n) {
            unsigned char c = buf[i];
            // UTF-8 字符计数
            if (c < 0x80) { char_count++; i++; }
            else if ((c & 0xE0) == 0xC0 && i + 1 < n) { char_count++; i += 2; }
            else if ((c & 0xF0) == 0xE0 && i + 2 < n) { char_count++; i += 3; }
            else if ((c & 0xF8) == 0xF0 && i + 3 < n) { char_count++; i += 4; }
            else { char_count++; i++; }
            // 行 / 单词
            int is_space = (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == '\v');
            if (c == '\n') line_count++;
            if (is_space) in_word = 0;
            else if (!in_word) { in_word = 1; word_count++; }
            last_byte = c;
        }
    }
    fclose(fp);
    if (total > 0 && last_byte != '\n') line_count++;
    if (bytes) *bytes = total;
    if (chars) *chars = char_count;
    if (lines) *lines = line_count;
    if (words) *words = word_count;
    return 0;
}

extern "C" int file_ops_compare_files(const char *path_a, const char *path_b, int *equal, long long *first_diff) {
    if (equal) *equal = 0;
    if (first_diff) *first_diff = -1;
    FILE *fa = fopen(path_a, "rb");
    FILE *fb = fopen(path_b, "rb");
    if (!fa || !fb) {
        if (fa) fclose(fa);
        if (fb) fclose(fb);
        return -1;
    }
    unsigned char ba[65536], bb[65536];
    long long offset = 0;
    int ret = 0;
    for (;;) {
        size_t na = fread(ba, 1, sizeof(ba), fa);
        size_t nb = fread(bb, 1, sizeof(bb), fb);
        size_t mn = na < nb ? na : nb;
        for (size_t i = 0; i < mn; i++) {
            if (ba[i] != bb[i]) {
                if (first_diff) *first_diff = offset + (long long)i;
                goto done;
            }
        }
        if (na != nb) {
            if (first_diff) *first_diff = offset + (long long)mn;
            goto done;
        }
        if (na == 0) break;
        offset += (long long)mn;
    }
    if (equal) *equal = 1;
done:
    fclose(fa);
    fclose(fb);
    return ret;
}

extern "C" int file_ops_split_file(const char *path, long long part_size, const char *out_dir, char *error, int error_size) {
    if (part_size <= 0) {
        if (error) snprintf(error, error_size, "invalid part size");
        return -1;
    }
    FILE *fp = fopen(path, "rb");
    if (!fp) {
        if (error) snprintf(error, error_size, "open failed: %s", strerror(errno));
        return -1;
    }
    std::error_code ec;
    std::filesystem::create_directories(out_dir, ec);
    std::string base = std::filesystem::path(path).filename().string();
    unsigned char buf[1 << 20];
    long long remaining = 0;
    int part_index = 1;
    char part_path[2048];
    FILE *out = nullptr;
    size_t n;
    int ret = 0;
    while ((n = fread(buf, 1, sizeof(buf), fp)) > 0) {
        size_t pos = 0;
        while (pos < n) {
            if (!out) {
                snprintf(part_path, sizeof(part_path), "%s/%s.part.%04d", out_dir, base.c_str(), part_index);
                out = fopen(part_path, "wb");
                if (!out) {
                    if (error) snprintf(error, error_size, "cannot create part %d: %s", part_index, strerror(errno));
                    ret = -1;
                    goto done;
                }
                remaining = part_size;
            }
            size_t take = (size_t)(n - pos);
            if ((long long)take > remaining) take = (size_t)remaining;
            if (fwrite(buf + pos, 1, take, out) != take) {
                if (error) snprintf(error, error_size, "write failed");
                ret = -1;
                goto done;
            }
            pos += take;
            remaining -= (long long)take;
            if (remaining == 0) {
                fclose(out);
                out = nullptr;
                part_index++;
            }
        }
    }
done:
    if (out) fclose(out);
    fclose(fp);
    return ret;
}

extern "C" int file_ops_merge_files(const char *parts_dir, const char *base_name, const char *out_path, char *error, int error_size) {
    FILE *out = fopen(out_path, "wb");
    if (!out) {
        if (error) snprintf(error, error_size, "open output failed: %s", strerror(errno));
        return -1;
    }
    unsigned char buf[1 << 20];
    int part_index = 1;
    int ret = 0;
    for (;;) {
        char part_path[2048];
        snprintf(part_path, sizeof(part_path), "%s/%s.part.%04d", parts_dir, base_name, part_index);
        FILE *in = fopen(part_path, "rb");
        if (!in) break;
        size_t n;
        while ((n = fread(buf, 1, sizeof(buf), in)) > 0) {
            if (fwrite(buf, 1, n, out) != n) {
                if (error) snprintf(error, error_size, "write failed");
                ret = -1;
                fclose(in);
                goto done;
            }
        }
        fclose(in);
        part_index++;
    }
    if (part_index == 1) {
        if (error) snprintf(error, error_size, "no parts found for %s", base_name);
        ret = -1;
    }
done:
    fclose(out);
    return ret;
}
