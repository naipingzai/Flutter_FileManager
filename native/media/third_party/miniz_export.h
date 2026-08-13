// miniz_export.h - minimal export macros placeholder (vendored)
#ifndef MINIZ_EXPORT_H
#define MINIZ_EXPORT_H

#if defined(_MSC_VER)
    #define MINIZ_EXPORT __declspec(dllexport)
#elif defined(__GNUC__) || defined(__clang__)
    #define MINIZ_EXPORT __attribute__((visibility("default")))
#else
    #define MINIZ_EXPORT
#endif

#endif // MINIZ_EXPORT_H
