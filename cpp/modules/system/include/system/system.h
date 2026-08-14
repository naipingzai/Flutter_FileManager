/*
 * system.h - system 模块对 Dart 的统一 C API
 *
 * system 模块负责：
 *   - 平台信息（OS、Arch、Path 规则）
 *   - 标准目录（Home / Root / Temp / Downloads / Documents / ...）
 *   - 运行时信息（版本、编译日期、特性）
 *
 * 所有函数通过 FFI 暴露给 Dart，Dart 不直接调用 Platform.isXxx。
 * 平台差异在 core/platform/<os>/ 实现中处理。
 */

#ifndef SYSTEM_SYSTEM_H
#define SYSTEM_SYSTEM_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// 获取平台信息 JSON：
// {
//   "os": "linux"|"macos"|"ios"|"windows"|"android",
//   "arch": "x86_64"|"arm64"|...,
//   "path_separator": "/"|"\\",
//   "newline": "\n"|"\r\n",
//   "case_sensitive": true|false,
//   "user_home": "/home/xxx",
//   "root_dir": "/"|"C:\\",
//   "temp_dir": "/tmp",
//   "downloads_dir": "...",
//   "documents_dir": "...",
//   "desktop_dir": "...",
//   "videos_dir": "...",
//   "music_dir": "...",
//   "pictures_dir": "...",
//   "app_data_dir": "...",
//   "app_cache_dir": "..."
// }
// 返回 malloc 的字符串，调用方负责 free。
char *system_info(void);

// 获取目录的显示名（如 "Downloads" / "下载"）。
char *system_dir_display_name(const char *path);

// 获取某个标准目录的绝对路径。
// category: "home" | "root" | "temp" | "downloads" | "documents"
//         | "desktop" | "videos" | "music" | "pictures"
//         | "app_data" | "app_cache"
// 返回 malloc 的字符串，调用方负责 free。
char *system_standard_dir(const char *category);

// 获取运行时信息 JSON：
// {
//   "version": "1.0.0",
//   "build_date": "2026-08-14",
//   "compiler": "gcc-15.2.0",
//   "features": ["system", "file", "text_reader", "media", "crypto"]
// }
char *system_runtime_info(void);

// 释放 system_* 返回的字符串。
void system_free_string(char *str);

#ifdef __cplusplus
}
#endif

#endif // SYSTEM_SYSTEM_H
