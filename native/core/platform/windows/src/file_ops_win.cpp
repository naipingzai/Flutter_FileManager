/*
 * FlutterFileManager - Windows POSIX Compatibility Layer
 *
 * The base core code (file_ops.cpp) uses POSIX APIs (stat, opendir, etc.).
 * On Windows these don't exist, so this platform layer provides
 * a compatibility shim implementing the needed POSIX APIs on top of
 * Win32 API. This is the "platform layer" — Windows-specific code that
 * enables the platform-agnostic base code to compile & run.
 */

#ifdef _WIN32

#include <windows.h>
#include <wchar.h>

#include <ctype.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <string>
#include <vector>

// ============================================================
// 简化 POSIX 兼容层
// 提供 base 代码 (file_ops.cpp) 所需的类型/函数
// ============================================================

// ---- 基本类型 ----
#ifndef _SSIZE_T_DEFINED
typedef long long ssize_t;
#define _SSIZE_T_DEFINED
#endif
#ifndef _OFF_T_DEFINED
typedef long long off_t;
#define _OFF_T_DEFINED
#endif

#ifndef S_IFMT
#define S_IFMT 0xF000
#endif
#ifndef S_IFREG
#define S_IFREG 0x8000
#endif
#ifndef S_IFDIR
#define S_IFDIR 0x4000
#endif
#ifndef S_IFLNK
#define S_IFLNK 0xA000
#endif
#ifndef S_IFIFO
#define S_IFIFO 0x1000
#endif
#ifndef S_IFSOCK
#define S_IFSOCK 0xC000
#endif
#ifndef S_IFBLK
#define S_IFBLK 0x6000
#endif
#ifndef S_IFCHR
#define S_IFCHR 0x2000
#endif

#define S_ISREG(m) (((m)&S_IFMT) == S_IFREG)
#define S_ISDIR(m) (((m)&S_IFMT) == S_IFDIR)
#define S_ISLNK(m) (((m)&S_IFMT) == S_IFLNK)
#define S_ISFIFO(m) (((m)&S_IFMT) == S_IFIFO)
#define S_ISSOCK(m) (((m)&S_IFMT) == S_IFSOCK)
#define S_ISBLK(m) (((m)&S_IFMT) == S_IFBLK)
#define S_ISCHR(m) (((m)&S_IFMT) == S_IFCHR)

#define R_OK 4
#define W_OK 2
#define X_OK 1
#define F_OK 0

#define PATH_MAX 32768

// ---- dirent 兼容 ----
struct dirent {
    char d_name[256];
};

struct DIR {
    HANDLE handle;
    WIN32_FIND_DATAA find_data;
    dirent entry;
    bool first;
};

static inline DIR* opendir(const char* path) {
    DIR* d = (DIR*)calloc(1, sizeof(DIR));
    if (!d) return NULL;

    std::string pattern(path);
    if (pattern.empty() || pattern.back() != '\\' && pattern.back() != '/') {
        pattern += "\\";
    }
    pattern += "*";

    d->handle = FindFirstFileA(pattern.c_str(), &d->find_data);
    if (d->handle == INVALID_HANDLE_VALUE) {
        free(d);
        return NULL;
    }
    d->first = true;
    return d;
}

static inline struct dirent* readdir(DIR* dir) {
    if (!dir) return NULL;

    if (dir->first) {
        dir->first = false;
    } else {
        if (!FindNextFileA(dir->handle, &dir->find_data)) {
            return NULL;
        }
    }
    strncpy(dir->entry.d_name, dir->find_data.cFileName,
            sizeof(dir->entry.d_name) - 1);
    return &dir->entry;
}

static inline int closedir(DIR* dir) {
    if (!dir) return 0;
    if (dir->handle != INVALID_HANDLE_VALUE) {
        FindClose(dir->handle);
    }
    free(dir);
    return 0;
}

// ---- stat 兼容 ----
struct stat {
    int st_mode;
    int64_t st_size;
    int64_t st_mtime;
    int64_t st_atime;
    int64_t st_ctime;
    uint32_t st_uid;
    uint32_t st_gid;
};

static void win_attributes_to_stat(const WIN32_FILE_ATTRIBUTE_DATA& data,
                                   struct stat* st, bool is_dir) {
    memset(st, 0, sizeof(*st));
    st->st_mode = is_dir ? S_IFDIR | 0755 : S_IFREG | 0644;
    st->st_size = ((int64_t)data.nFileSizeHigh << 32) | data.nFileSizeLow;
    // Convert FILETIME to Unix epoch seconds
    ULARGE_INTEGER ft;
    ft.LowPart = data.ftLastWriteTime.dwLowDateTime;
    ft.HighPart = data.ftLastWriteTime.dwHighDateTime;
    st->st_mtime = (int64_t)(ft.QuadPart / 10000000ULL - 11644473600ULL);
    ft.LowPart = data.ftLastAccessTime.dwLowDateTime;
    ft.HighPart = data.ftLastAccessTime.dwHighDateTime;
    st->st_atime = (int64_t)(ft.QuadPart / 10000000ULL - 11644473600ULL);
    ft.LowPart = data.ftCreationTime.dwLowDateTime;
    ft.HighPart = data.ftCreationTime.dwHighDateTime;
    st->st_ctime = (int64_t)(ft.QuadPart / 10000000ULL - 11644473600ULL);
    st->st_uid = 0;
    st->st_gid = 0;
}

static inline int stat(const char* path, struct stat* st) {
    if (!path || !st) { errno = EINVAL; return -1; }
    WIN32_FILE_ATTRIBUTE_DATA data;
    if (!GetFileAttributesExA(path, GetFileExInfoStandard, &data)) {
        errno = ENOENT;
        return -1;
    }
    bool is_dir = (data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
    win_attributes_to_stat(data, st, is_dir);
    return 0;
}

static inline int lstat(const char* path, struct stat* st) {
    // Windows 无符号链接语义差异，lstat == stat
    return stat(path, st);
}

// ---- unistd 兼容 ----
static inline int unlink(const char* path) {
    if (DeleteFileA(path)) return 0;
    errno = ENOENT;
    return -1;
}

static inline int rmdir(const char* path) {
    if (RemoveDirectoryA(path)) return 0;
    errno = ENOENT;
    return -1;
}

static inline int mkdir(const char* path, int /*mode*/) {
    if (CreateDirectoryA(path, NULL)) return 0;
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        errno = EEXIST;
    } else {
        errno = ENOENT;
    }
    return -1;
}

static inline int access(const char* path, int mode) {
    DWORD attr = GetFileAttributesA(path);
    if (attr == INVALID_FILE_ATTRIBUTES) {
        errno = ENOENT;
        return -1;
    }
    return 0;
}

static inline int chmod(const char* path, uint32_t /*mode*/) {
    // Windows 权限模型不同，静默成功
    (void)path;
    return 0;
}

static inline int chown(const char* path, uint32_t uid, uint32_t gid) {
    // Windows 不支持属主修改
    (void)path; (void)uid; (void)gid;
    errno = EPERM;
    return -1;
}

static inline int lchown(const char* path, uint32_t uid, uint32_t gid) {
    return chown(path, uid, gid);
}

static inline int symlink(const char* target, const char* linkpath) {
    // Windows 需要管理员权限才能创建符号链接，用快捷方式简化处理
    (void)target; (void)linkpath;
    errno = EPERM;
    return -1;
}

static inline int link(const char* oldpath, const char* newpath) {
    if (CreateHardLinkA(newpath, oldpath, NULL)) return 0;
    errno = EPERM;
    return -1;
}

static inline ssize_t readlink(const char* path, char* buf, size_t bufsiz) {
    (void)path; (void)buf; (void)bufsiz;
    errno = EINVAL;
    return -1;
}

static inline int rename(const char* oldpath, const char* newpath) {
    if (MoveFileA(oldpath, newpath)) return 0;
    errno = ENOENT;
    return -1;
}

// ---- pwd / grp 兼容 ----
struct passwd {
    char pw_name[64];
    uint32_t pw_uid;
};

struct group {
    char gr_name[64];
    uint32_t gr_gid;
};

static inline struct passwd* getpwuid(uint32_t uid) {
    static struct passwd pwd;
    snprintf(pwd.pw_name, sizeof(pwd.pw_name), "user%d", uid);
    pwd.pw_uid = uid;
    return &pwd;
}

static inline struct group* getgrgid(uint32_t gid) {
    static struct group grp;
    snprintf(grp.gr_name, sizeof(grp.gr_name), "group%d", gid);
    grp.gr_gid = gid;
    return &grp;
}

// ---- strcasecmp / strncasecmp ----
static inline int strcasecmp(const char* a, const char* b) {
    return _stricmp(a, b);
}

static inline int strncasecmp(const char* a, const char* b, size_t n) {
    return _strnicmp(a, b, n);
}

// ---- fnmatch（简化 glob 匹配）----
static inline int fnmatch(const char* pattern, const char* name, int /*flags*/) {
    // * ? 简单通配
    const char* p = pattern;
    const char* n = name;
    const char* star_p = NULL;
    const char* star_n = NULL;

    while (*n) {
        if (*p == '*') {
            star_p = ++p;
            star_n = n;
            continue;
        }
        if (*p == '?' || *p == *n) {
            p++;
            n++;
            continue;
        }
        if (p == pattern) return -1;
        p = star_p;
        p++;
        n = ++star_n;
    }
    while (*p == '*') p++;
    return *p == '\0' ? 0 : -1;
}

// ---- realpath 兼容 ----
static inline char* realpath(const char* path, char* resolved) {
    DWORD len = GetFullPathNameA(path, PATH_MAX, resolved ? resolved : (char*)malloc(PATH_MAX), NULL);
    if (resolved) {
        if (len == 0) { errno = ENOENT; return NULL; }
        return resolved;
    }
    return NULL;
}

// ---- sendfile（复制用，基于句柄的 ReadFile/WriteFile 实现）----
#define O_RDONLY 0
#define O_WRONLY 1
#define O_RDWR 2
#define O_CREAT 0x0100
#define O_TRUNC 0x0200
#define O_EXCL 0x0400

static inline int open(const char* path, int flags, ...) {
    DWORD access = 0;
    DWORD share = FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
    DWORD disp = OPEN_EXISTING;
    switch (flags & 3) {
        case O_RDONLY: access = GENERIC_READ; break;
        case O_WRONLY: access = GENERIC_WRITE; break;
        default: access = GENERIC_READ | GENERIC_WRITE; break;
    }
    if (flags & O_CREAT) {
        disp = (flags & O_EXCL) ? CREATE_NEW
             : (flags & O_TRUNC) ? CREATE_ALWAYS : OPEN_ALWAYS;
    } else if (flags & O_TRUNC) {
        disp = TRUNCATE_EXISTING;
    }
    HANDLE h = CreateFileA(path, access, share, NULL, disp, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE) { errno = ENOENT; return -1; }
    return (int)(intptr_t)h;
}

static inline int close(int fd) {
    return CloseHandle((HANDLE)(intptr_t)fd) ? 0 : -1;
}

static inline int fstat(int fd, struct stat* st) {
    BY_HANDLE_FILE_INFORMATION fi;
    if (!GetFileInformationByHandle((HANDLE)(intptr_t)fd, &fi)) {
        errno = ENOENT;
        return -1;
    }
    WIN32_FILE_ATTRIBUTE_DATA data;
    memset(&data, 0, sizeof(data));
    data.dwFileAttributes = fi.dwFileAttributes;
    data.nFileSizeHigh = fi.nFileSizeHigh;
    data.nFileSizeLow = fi.nFileSizeLow;
    data.ftLastWriteTime = fi.ftLastWriteTime;
    data.ftLastAccessTime = fi.ftLastAccessTime;
    data.ftCreationTime = fi.ftCreationTime;
    bool is_dir = (fi.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
    win_attributes_to_stat(data, st, is_dir);
    return 0;
}

static inline ssize_t sendfile(int out_fd, int in_fd, off_t* offset, size_t count) {
    HANDLE hin = (HANDLE)(intptr_t)in_fd;
    HANDLE hout = (HANDLE)(intptr_t)out_fd;
    LARGE_INTEGER li;
    li.QuadPart = *offset;
    if (!SetFilePointerEx(hin, li, NULL, FILE_BEGIN)) return -1;
    size_t total = 0;
    unsigned char buf[65536];
    while (count > 0) {
        DWORD to_read = (DWORD)(count > sizeof(buf) ? sizeof(buf) : count);
        DWORD got = 0;
        if (!ReadFile(hin, buf, to_read, &got, NULL) || got == 0) break;
        DWORD written = 0;
        if (!WriteFile(hout, buf, got, &written, NULL)) break;
        total += written;
        *offset += written;
        count -= written;
    }
    return (ssize_t)total;
}

// ---- statvfs 兼容（磁盘用量，基于 GetDiskFreeSpaceExA）----
typedef unsigned long long fsblkcnt_t;

struct statvfs {
    unsigned long f_bsize;
    unsigned long f_frsize;
    fsblkcnt_t f_blocks;
    fsblkcnt_t f_bfree;
    fsblkcnt_t f_bavail;
};

static inline int statvfs(const char* path, struct statvfs* vfs) {
    ULARGE_INTEGER avail, total, free_total;
    if (!GetDiskFreeSpaceExA(path, &avail, &total, &free_total)) {
        errno = ENOENT;
        return -1;
    }
    memset(vfs, 0, sizeof(*vfs));
    vfs->f_frsize = 1;
    vfs->f_bsize = 1;
    vfs->f_blocks = total.QuadPart;
    vfs->f_bavail = avail.QuadPart;
    vfs->f_bfree = free_total.QuadPart;
    return 0;
}

// ---- getpwuid 的用户主目录 ----
static inline char* getenv_home() {
    static char buf[PATH_MAX] = {0};
    if (!buf[0]) {
        DWORD len = GetEnvironmentVariableA("USERPROFILE", buf, PATH_MAX - 1);
        if (len == 0 || len >= PATH_MAX) {
            snprintf(buf, sizeof(buf), "C:\\");
        }
    }
    return buf;
}

#endif // _WIN32