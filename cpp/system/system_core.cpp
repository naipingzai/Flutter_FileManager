/*
 * system_info_core.cpp - system 模块跨平台 core 实现
 *
 * 调用平台层 sys_get_* 接口，使用 common JsonBuilder
 * 生成统一 JSON 返回给 Dart FFI。
 *
 * 平台差异由 platform/<os>/ 子目录下的 source 实现。
 */

#include "system/system.h"
#include "system_internal.h"
#include "common/json_builder.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void add_string(JsonBuilder *jb, const char *key, const char *value) {
    if (!value) return;
    jb_append_str(jb, ",\"");
    jb_append_str(jb, key);
    jb_append_str(jb, "\":");
    jb_append_esc(jb, value);
}

extern "C" {

char *system_info(void) {
    JsonBuilder jb = jb_new();
    if (jb.err) return NULL;

    jb_append_str(&jb, "{\"os\":");
    jb_append_esc(&jb, sys_get_os_name());
    add_string(&jb, "arch", sys_get_arch());
    add_string(&jb, "path_separator", sys_get_path_separator());
    add_string(&jb, "newline", sys_get_newline());

    jb_append_str(&jb, ",\"case_sensitive\":");
    jb_append_bool(&jb, sys_is_case_sensitive());

    add_string(&jb, "user_home", sys_get_user_home());
    add_string(&jb, "root_dir", sys_get_root_dir());
    add_string(&jb, "temp_dir", sys_get_temp_dir());
    add_string(&jb, "downloads_dir", sys_get_downloads_dir());
    add_string(&jb, "documents_dir", sys_get_documents_dir());
    add_string(&jb, "desktop_dir", sys_get_desktop_dir());
    add_string(&jb, "videos_dir", sys_get_videos_dir());
    add_string(&jb, "music_dir", sys_get_music_dir());
    add_string(&jb, "pictures_dir", sys_get_pictures_dir());
    add_string(&jb, "app_data_dir", sys_get_app_data_dir());
    add_string(&jb, "app_cache_dir", sys_get_app_cache_dir());

    jb_append_str(&jb, "}");
    return jb_finish(&jb);
}

char *system_dir_display_name(const char *path) {
    return sys_get_dir_display_name(path ? path : "");
}

char *system_standard_dir(const char *category) {
    if (!category) {
        char *empty = (char *)malloc(1);
        if (empty) empty[0] = '\0';
        return empty;
    }
    return sys_get_standard_dir(category);
}

char *system_runtime_info(void) {
    const char *version = "1.0.0";
    const char *build_date = __DATE__ " " __TIME__;
#if defined(__clang__)
    const char *compiler = "clang";
#elif defined(__GNUC__)
    const char *compiler = "gcc";
#elif defined(_MSC_VER)
    const char *compiler = "msvc";
#else
    const char *compiler = "unknown";
#endif

    JsonBuilder jb = jb_new();
    jb_append_str(&jb, "{\"version\":\"");
    jb_append_str(&jb, version);
    jb_append_str(&jb, "\",\"build_date\":\"");
    jb_append_str(&jb, build_date);
    jb_append_str(&jb, "\",\"compiler\":\"");
    jb_append_str(&jb, compiler);
    jb_append_str(&jb, "\",\"features\":[\"system\",\"file\",\"text_reader\",\"media\",\"crypto\"]}");
    return jb_finish(&jb);
}

void system_free_string(char *str) {
    if (str) free(str);
}

} // extern "C"
