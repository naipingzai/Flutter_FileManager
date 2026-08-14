# core - Linux 平台配置（同时供 macOS / iOS / Android 通过 POSIX 通用）

# platform_info 由 POSIX getenv + XDG 标准实现
set(CORE_PLATFORM_SOURCES
    src/platform_info_linux.cpp
)

# core 为纯标准库实现（哈希/加密内置），无需外部库
set(CORE_PLATFORM_LIBS "")

# 平台编译定义
target_compile_definitions(core PRIVATE
    CORE_PLATFORM_LINUX=1
)
