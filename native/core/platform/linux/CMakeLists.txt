# ============================================================
# core - Linux 平台配置
# ============================================================

# 平台相关源码（如 Linux 特有的文件操作适配，目前为空）
set(CORE_PLATFORM_SOURCES "")

# core 为纯标准库实现（哈希/加密内置），无需外部库
set(CORE_PLATFORM_LIBS "")

# 平台编译定义
target_compile_definitions(core PRIVATE
    CORE_PLATFORM_LINUX=1
)
