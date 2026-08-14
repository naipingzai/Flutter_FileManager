/*
 * common.h - 公共基础类型与工具
 *
 * 本头文件定义跨模块共享的基础类型：
 *   - FileType: 文件类型枚举
 *   - FileInfo: 文件信息结构
 *   - DirListResult: 目录列表结果
 *   - SearchResult / SearchResultList: 搜索结果
 *   - HashResult: 哈希计算结果
 *   - DiskUsageInfo: 磁盘用量
 *   - StandardDir: 标准目录枚举
 *
 * 任何业务模块都可以 #include "common/common.h"。
 */

#ifndef COMMON_COMMON_H
#define COMMON_COMMON_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// 文件类型枚举（统一表示）
// ============================================================
typedef enum {
    FILE_TYPE_UNKNOWN = 0,
    FILE_TYPE_REGULAR = 1,
    FILE_TYPE_DIRECTORY = 2,
    FILE_TYPE_SYMLINK = 3,
    FILE_TYPE_SOCKET = 4,
    FILE_TYPE_FIFO = 5,
    FILE_TYPE_BLOCK_DEVICE = 6,
    FILE_TYPE_CHAR_DEVICE = 7,
} FileType;

// ============================================================
// 文件信息（统一结构，所有平台一致）
// ============================================================
typedef struct {
    char name[256];
    char path[1024];
    char symlink_target[1024];
    FileType type;
    int64_t size;
    int64_t modified_time;
    int64_t access_time;
    int64_t created_time;
    uint32_t permissions;
    uint32_t uid;
    uint32_t gid;
    char owner_name[64];
    char group_name[64];
    char mime_type[128];
    bool is_readable;
    bool is_writable;
    bool is_executable;
    bool is_hidden;
} FileInfo;

// ============================================================
// 目录列表结果
// ============================================================
typedef struct {
    FileInfo *items;
    int count;
    int capacity;
    char error[256];
} DirListResult;

// ============================================================
// 搜索结果
// ============================================================
typedef struct {
    char path[1024];
    char name[256];
    FileType type;
    int64_t size;
    int64_t modified_time;
} SearchResult;

typedef struct {
    SearchResult *items;
    int count;
    int capacity;
    char error[256];
} SearchResultList;

// ============================================================
// 哈希计算结果
// ============================================================
typedef struct {
    char md5[65];
    char sha1[65];
    char sha256[65];
    char sha512[129];
    char crc32[17];
    char error[256];
} HashResult;

// ============================================================
// 磁盘用量
// ============================================================
typedef struct {
    int64_t total_space;
    int64_t free_space;
    int64_t used_space;
    char error[256];
} DiskUsageInfo;

// ============================================================
// 标准目录类别（与 system 模块对应）
// ============================================================
typedef enum {
    STD_DIR_HOME = 0,
    STD_DIR_ROOT = 1,
    STD_DIR_TEMP = 2,
    STD_DIR_DOWNLOADS = 3,
    STD_DIR_DOCUMENTS = 4,
    STD_DIR_DESKTOP = 5,
    STD_DIR_VIDEOS = 6,
    STD_DIR_MUSIC = 7,
    STD_DIR_PICTURES = 8,
    STD_DIR_APP_DATA = 9,
    STD_DIR_APP_CACHE = 10,
} StandardDir;

#ifdef __cplusplus
}
#endif

#endif // COMMON_COMMON_H
