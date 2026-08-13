# ============================================================
# core - Apple 平台配置 (macOS / iOS)
# ============================================================

# Apple 平台相关源码（POSIX 文件操作可直接复用，无需额外源码）
set(CORE_PLATFORM_SOURCES "")

# core 为纯标准库实现（哈希/加密内置），Apple POSIX libc 已覆盖全部 API
set(CORE_PLATFORM_LIBS "")

# 平台编译定义
target_compile_definitions(core PRIVATE
    CORE_PLATFORM_APPLE=1
)
