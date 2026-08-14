/*
 * platform_system_posix.cpp - Linux/macOS/iOS/Android 平台 system 实现
 *
 * 共用 POSIX getenv + XDG Base Directory Specification。
 * 由 system 模块 CMake 在 Linux/Android/Apple 时引入。
 */

#include "system/system_internal.h"

#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>

static char *path_join(const char *base, const char *sub) {
    if (!base) return strdup(sub ? sub : "");
    if (!sub) return strdup(base);
    size_t bl = strlen(base);
    int needs = (bl > 0 && base[bl - 1] != '/' && sub[0] != '/' && sub[0] != '\0');
    size_t sl = strlen(sub);
    char *r = (char *)malloc(bl + (needs ? 1 : 0) + sl + 1);
    if (!r) return NULL;
    memcpy(r, base, bl);
    if (needs) r[bl++] = '/';
    memcpy(r + bl, sub, sl);
    r[bl + sl] = '\0';
    return r;
}

static char *xdg_home(const char *sub) {
    const char *home = getenv("HOME");
    if (!home) {
        struct passwd *pw = getpwuid(getuid());
        if (pw && pw->pw_dir) home = pw->pw_dir;
    }
    if (!home) home = "/";
    if (!sub) return strdup(home);
    return path_join(home, sub);
}

extern "C" {

const char *sys_get_os_name(void) {
#if defined(__ANDROID__)
    return strdup("android");
#elif defined(__APPLE__) && defined(__MACH__)
#if defined(TARGET_OS_IPHONE) || defined(__IOS__)
    return strdup("ios");
#else
    return strdup("macos");
#endif
#else
    return strdup("linux");
#endif
}

const char *sys_get_arch(void) {
    struct utsname info;
    if (uname(&info) != 0) return strdup("unknown");
    return strdup(info.machine);
}

const char *sys_get_path_separator(void) { return strdup("/"); }
const char *sys_get_newline(void)        { return strdup("\n"); }
bool        sys_is_case_sensitive(void)  { return true; }

char *sys_get_user_home(void)      { return xdg_home(NULL); }
char *sys_get_root_dir(void)       { return strdup("/"); }
char *sys_get_temp_dir(void) {
    const char *t = getenv("TMPDIR");
    if (!t) t = "/tmp";
    return strdup(t);
}
char *sys_get_downloads_dir(void)  { return xdg_home("Downloads"); }
char *sys_get_documents_dir(void)  { return xdg_home("Documents"); }
char *sys_get_desktop_dir(void)    { return xdg_home("Desktop"); }
char *sys_get_videos_dir(void)     { return xdg_home("Videos"); }
char *sys_get_music_dir(void)      { return xdg_home("Music"); }
char *sys_get_pictures_dir(void)   { return xdg_home("Pictures"); }
char *sys_get_app_data_dir(void)   { return xdg_home(".flutter_app_data"); }
char *sys_get_app_cache_dir(void)  { return path_join(sys_get_app_data_dir(), "cache"); }

char *sys_get_dir_display_name(const char *path) {
    if (!path) return strdup("");
    const char *slash = strrchr(path, '/');
    if (slash && *(slash + 1)) return strdup(slash + 1);
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
