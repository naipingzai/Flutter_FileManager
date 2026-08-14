/*
 * system_internal.h - system 模块内部平台抽象接口
 *
 * 被 system_core.cpp 与 platform_posix/platform_windows 共享。
 * platform/<os>/ 实现 sys_get_* 函数，core 层统一调用。
 */

#ifndef SYSTEM_PLATFORM_INFO_INTERNAL_H
#define SYSTEM_PLATFORM_INFO_INTERNAL_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// 平台基本信息
const char *sys_get_os_name(void);
const char *sys_get_arch(void);
const char *sys_get_path_separator(void);
const char *sys_get_newline(void);
bool        sys_is_case_sensitive(void);

// 标准目录（返回 malloc 字符串，调用方负责 free）
char *sys_get_user_home(void);
char *sys_get_root_dir(void);
char *sys_get_temp_dir(void);
char *sys_get_downloads_dir(void);
char *sys_get_documents_dir(void);
char *sys_get_desktop_dir(void);
char *sys_get_videos_dir(void);
char *sys_get_music_dir(void);
char *sys_get_pictures_dir(void);
char *sys_get_app_data_dir(void);
char *sys_get_app_cache_dir(void);

// 获取目录显示名（返回 malloc 字符串）
char *sys_get_dir_display_name(const char *path);

// 获取标准目录（category 字符串）
char *sys_get_standard_dir(const char *category);

#ifdef __cplusplus
}
#endif

#endif // SYSTEM_PLATFORM_INFO_INTERNAL_H