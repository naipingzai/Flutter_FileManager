/*
 * AdvanceFileManager - C++ Native File Operations
 * Core file system operations using POSIX APIs
 */

#include "file_ops.h"

#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/types.h>
#include <dirent.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/sendfile.h>
#include <pwd.h>
#include <grp.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <fnmatch.h>
#include <libgen.h>
#include <openssl/evp.h>
#include <zlib.h>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <functional>
#include <filesystem>

namespace fs = std::filesystem;

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
    if (!result) return NULL;

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
    while ((entry = readdir(dir)) != NULL) {
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
    if (!info) return NULL;

    struct stat st;
    if (lstat(path, &st) != 0) {
        free(info);
        return NULL;
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

    while ((entry = readdir(dir)) != NULL) {
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

    // Use sendfile for efficient copy
    off_t offset = 0;
    ssize_t remaining = st.st_size;
    int ret = 0;

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
static char g_realpath_buffer[1024];
extern "C" const char* file_ops_realpath(const char *path) {
    char *result = realpath(path, g_realpath_buffer);
    if (result) return g_realpath_buffer;
    return NULL;
}

// Function: readlink() - enhanced from Syscall.kt:212
static char g_readlink_buffer[1024];
extern "C" const char* file_ops_readlink(const char *path) {
    ssize_t len = readlink(path, g_readlink_buffer, sizeof(g_readlink_buffer) - 1);
    if (len < 0) return NULL;
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
    while ((entry = readdir(d)) != NULL && result->count < max_results) {
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
    if (!result) return NULL;
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
        sprintf(out + i * 2, "%02x", hash[i]);
    }
}

extern "C" HashResult* file_ops_compute_hash(const char *path) {
    HashResult *result = (HashResult*)calloc(1, sizeof(HashResult));
    if (!result) return NULL;

    FILE *fp = fopen(path, "rb");
    if (!fp) {
        snprintf(result->error, sizeof(result->error), "fopen failed: %s", strerror(errno));
        return result;
    }

    // Init all hash contexts
    EVP_MD_CTX *md5_ctx = EVP_MD_CTX_new();
    EVP_MD_CTX *sha1_ctx = EVP_MD_CTX_new();
    EVP_MD_CTX *sha256_ctx = EVP_MD_CTX_new();
    EVP_MD_CTX *sha512_ctx = EVP_MD_CTX_new();

    EVP_DigestInit_ex(md5_ctx, EVP_md5(), NULL);
    EVP_DigestInit_ex(sha1_ctx, EVP_sha1(), NULL);
    EVP_DigestInit_ex(sha256_ctx, EVP_sha256(), NULL);
    EVP_DigestInit_ex(sha512_ctx, EVP_sha512(), NULL);

    uLong crc = crc32(0L, Z_NULL, 0);

    unsigned char buf[65536];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), fp)) > 0) {
        EVP_DigestUpdate(md5_ctx, buf, n);
        EVP_DigestUpdate(sha1_ctx, buf, n);
        EVP_DigestUpdate(sha256_ctx, buf, n);
        EVP_DigestUpdate(sha512_ctx, buf, n);
        crc = crc32(crc, buf, (uInt)n);
    }
    fclose(fp);

    // Finalize
    unsigned char md5_hash[16], sha1_hash[20], sha256_hash[32], sha512_hash[64];
    unsigned int md5_len, sha1_len, sha256_len, sha512_len;

    EVP_DigestFinal_ex(md5_ctx, md5_hash, &md5_len);
    EVP_DigestFinal_ex(sha1_ctx, sha1_hash, &sha1_len);
    EVP_DigestFinal_ex(sha256_ctx, sha256_hash, &sha256_len);
    EVP_DigestFinal_ex(sha512_ctx, sha512_hash, &sha512_len);

    EVP_MD_CTX_free(md5_ctx);
    EVP_MD_CTX_free(sha1_ctx);
    EVP_MD_CTX_free(sha256_ctx);
    EVP_MD_CTX_free(sha512_ctx);

    // Convert to hex
    hash_to_hex(md5_hash, 16, result->md5);
    hash_to_hex(sha1_hash, 20, result->sha1);
    hash_to_hex(sha256_hash, 32, result->sha256);
    hash_to_hex(sha512_hash, 64, result->sha512);
    sprintf(result->crc32, "%08lx", crc);

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
    if (!info) return NULL;

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

extern "C" const char* file_ops_get_home_dir(void) {
    const char *home = getenv("HOME");
    if (home) {
        strncpy(g_path_buffer, home, sizeof(g_path_buffer) - 1);
    } else {
        strncpy(g_path_buffer, "/", sizeof(g_path_buffer) - 1);
    }
    g_path_buffer[sizeof(g_path_buffer) - 1] = '\0';
    return g_path_buffer;
}

extern "C" const char* file_ops_get_root_dir(void) {
    strncpy(g_path_buffer, "/", sizeof(g_path_buffer) - 1);
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
    if (!result) return NULL;
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

            uLong crc = crc32(0L, Z_NULL, 0);
            unsigned char buf[65536];
            size_t n;
            while ((n = fread(buf, 1, sizeof(buf), fp)) > 0) {
                crc = crc32(crc, buf, (uInt)n);
            }
            fclose(fp);
            hash_groups[(uint32_t)crc].push_back(p);
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
    if (!result) return NULL;
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
