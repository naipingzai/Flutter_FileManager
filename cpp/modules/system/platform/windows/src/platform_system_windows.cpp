/*
 * platform_system_windows.cpp - Windows 平台 system 实现
 *
 * 由 system 模块 CMake 在 WIN32 时引入。
 * 使用 Win32 Known Folders API (SHGetKnownFolderPath) 获取标准目录。
 */

#ifdef _WIN32

#include "platform_info_internal.h"

#include <windows.h>
#include <shlobj.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *wstr_to_utf8(const wchar_t *ws) {
    if (!ws) {
        char *empty = (char *)malloc(1);
        if (empty) empty[0] = '\0';
        return empty;
    }
    int len = WideCharToMultiByte(CP_UTF8, 0, ws, -1, NULL, 0, NULL, NULL);
    if (len <= 0) {
        char *empty = (char *)malloc(1);
        if (empty) empty[0] = '\0';
        return empty;
    }
    char *buf = (char *)malloc((size_t)len);
    if (!buf) return NULL;
    WideCharToMultiByte(CP_UTF8, 0, ws, -1, buf, len, NULL, NULL);
    return buf;
}

static char *known_folder(REFKNOWNFOLDERID id) {
    PWSTR path = NULL;
    if (SHGetKnownFolderPath(id, 0, NULL, &path) != S_OK || !path) {
        if (path) CoTaskMemFree(path);
        char *empty = (char *)malloc(1);
        if (empty) empty[0] = '\0';
        return empty;
    }
    char *r = wstr_to_utf8(path);
    CoTaskMemFree(path);
    return r;
}

extern "C" {

const char *sys_get_os_name(void)        { return strdup("windows"); }
const char *sys_get_path_separator(void) { return strdup("\\"); }
const char *sys_get_newline(void)        { return strdup("\r\n"); }
bool        sys_is_case_sensitive(void)  { return false; }

const char *sys_get_arch(void) {
    SYSTEM_INFO si;
    GetNativeSystemInfo(&si);
    switch (si.wProcessorArchitecture) {
        case PROCESSOR_ARCHITECTURE_AMD64: return strdup("x86_64");
        case PROCESSOR_ARCHITECTURE_ARM64: return strdup("arm64");
        case PROCESSOR_ARCHITECTURE_INTEL: return strdup("x86");
        default: return strdup("unknown");
    }
}

char *sys_get_user_home(void) {
    const char *up = getenv("USERPROFILE");
    if (up) return strdup(up);
    const char *hd = getenv("HOMEDRIVE");
    const char *hp = getenv("HOMEPATH");
    if (hd && hp) {
        size_t n = strlen(hd) + strlen(hp) + 1;
        char *r = (char *)malloc(n);
        if (r) snprintf(r, n, "%s%s", hd, hp);
        return r;
    }
    return strdup("C:\\");
}

char *sys_get_root_dir(void)       { return strdup("C:\\"); }
char *sys_get_temp_dir(void) {
    char buf[MAX_PATH];
    DWORD len = GetTempPathA(sizeof(buf), buf);
    if (len > 0) {
        char *r = (char *)malloc(len + 1);
        if (r) { memcpy(r, buf, len); r[len] = '\0'; }
        return r;
    }
    return strdup("C:\\Windows\\Temp");
}
char *sys_get_downloads_dir(void)  { return known_folder(FOLDERID_Downloads); }
char *sys_get_documents_dir(void)  { return known_folder(FOLDERID_Documents); }
char *sys_get_desktop_dir(void)    { return known_folder(FOLDERID_Desktop); }
char *sys_get_videos_dir(void)     { return known_folder(FOLDERID_Videos); }
char *sys_get_music_dir(void)      { return known_folder(FOLDERID_Music); }
char *sys_get_pictures_dir(void)   { return known_folder(FOLDERID_Pictures); }
char *sys_get_app_data_dir(void) {
    return known_folder(FOLDERID_RoamingAppData);
}
char *sys_get_app_cache_dir(void) {
    return known_folder(FOLDERID_LocalAppData);
}

char *sys_get_dir_display_name(const char *path) {
    if (!path) return strdup("");
    const char *slash1 = strrchr(path, '\\');
    const char *slash2 = strrchr(path, '/');
    const char *sep = slash1 && (!slash2 || slash1 > slash2) ? slash1 : slash2;
    if (sep && *(sep + 1)) return strdup(sep + 1);
    return strdup(path);
}

char *sys_get_standard_dir(const char *category) {
    if (!category) return strdup("");
    if      (!strcmp(category, "home"))      return sys_get_user_home();
    else if (!strcmp(category, "root"))      return sys_get_root_dir();
    else if (!strcmp(category, "temp"))      return sys_get_temp_dir();
    else if (!strcmp(category, "downloads")) return sys_get_downloads_dir();
    else if (!strcmp(category, "documents")) return sys_get_documents_dir();
    else if (!strcmp(category, "desktop"))   return sys_get_desktop_dir();
    else if (!strcmp(category, "videos"))    return sys_get_videos_dir();
    else if (!strcmp(category, "music"))     return sys_get_music_dir();
    else if (!strcmp(category, "pictures"))  return sys_get_pictures_dir();
    else if (!strcmp(category, "app_data"))  return sys_get_app_data_dir();
    else if (!strcmp(category, "app_cache")) return sys_get_app_cache_dir();
    return strdup("");
}

} // extern "C"

#endif // _WIN32
