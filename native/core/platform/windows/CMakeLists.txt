# ============================================================
# core - Windows 平台配置
# ============================================================

# Windows 平台相关源码（POSIX 适配层）
# 注意：file_ops_win.cpp 为 POSIX 兼容层，已通过 file_ops.cpp
# 的 #include "../platform/windows/src/file_ops_win.cpp" 直接内联引入，
# 此处无需单独编译为独立 TU（否则会符号重复）。
set(CORE_PLATFORM_SOURCES "")

# core 为纯标准库实现（哈希/加密内置），仅需系统基础库（kernel32 默认链接）
set(CORE_PLATFORM_LIBS "")

# 平台编译定义
target_compile_definitions(core PRIVATE
    CORE_PLATFORM_WINDOWS=1
    _CRT_SECURE_NO_WARNINGS
    NOMINMAX
)
