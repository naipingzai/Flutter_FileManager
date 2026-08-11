#pragma once

#include <stddef.h>

#ifdef _WIN32
#define TEXT_OPS_API __declspec(dllexport)
#else
#define TEXT_OPS_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void* TextOpsHandle;

/* 创建 */
TEXT_OPS_API
TextOpsHandle text_ops_create(void);

/* 销毁 */
TEXT_OPS_API
void text_ops_destroy(TextOpsHandle handle);

/* 打开 UTF-8 文本文件 */
TEXT_OPS_API
int text_ops_open(
    TextOpsHandle handle,
    const char* path
);

/* 关闭 */
TEXT_OPS_API
void text_ops_close(TextOpsHandle handle);

/* 是否已打开 */
TEXT_OPS_API
int text_ops_is_open(TextOpsHandle handle);

/* 文件大小，单位：字节 */
TEXT_OPS_API
size_t text_ops_size(TextOpsHandle handle);

/* 获取文件路径 */
TEXT_OPS_API
const char* text_ops_path(TextOpsHandle handle);

/*
 * 读取指定范围。
 *
 * offset / length 都是字节偏移。
 *
 * 返回实际读取的字节数。
 */
TEXT_OPS_API
size_t text_ops_read(
    TextOpsHandle handle,
    size_t offset,
    size_t length,
    char* buffer,
    size_t buffer_size
);

/* 获取行数 */
TEXT_OPS_API
size_t text_ops_line_count(TextOpsHandle handle);

/*
 * 获取指定行。
 *
 * line 从 0 开始。
 */
TEXT_OPS_API
size_t text_ops_read_line(
    TextOpsHandle handle,
    size_t line,
    char* buffer,
    size_t buffer_size
);

/* 获取最后一次错误 */
TEXT_OPS_API
const char* text_ops_error(TextOpsHandle handle);

#ifdef __cplusplus
}
#endif