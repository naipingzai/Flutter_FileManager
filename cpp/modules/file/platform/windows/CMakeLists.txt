# core - Windows 平台配置

# platform_info 由 Win32 Known Folders API 实现
set(CORE_PLATFORM_SOURCES
    src/platform_info_windows.cpp
)

# 平台编译定义
target_compile_definitions(core PRIVATE
    CORE_PLATFORM_WINDOWS=1
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX
)

# Windows 依赖：shell32 (SHGetKnownFolderPath), ole32 (CoTaskMemFree)
set(CORE_PLATFORM_LIBS
    shell32
    ole32
)
