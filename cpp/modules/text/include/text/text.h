/*
 * text.h - text 模块对 Dart 的统一 C API
 *
 * 大文本文件高效读取：
 *   - 打开时建立行索引（O(1) 按行读取）
 *   - 按字节偏移分块读取
 *   - 句柄式 API（create/destroy/open/close/read/read_line）
 *
 * 不需要 FFI 双向结构体。所有方法都使用 void* Handle。
 */

#ifndef TEXT_TEXT_H
#define TEXT_TEXT_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Text reader 句柄（不透明指针）
typedef void *TextReaderHandle;

// 创建 / 销毁读取器
TextReaderHandle text_create(void);
void text_destroy(TextReaderHandle handle);

// 打开文件并建立行索引。成功返回 0，失败返回 -1。
int text_open(TextReaderHandle handle, const char *path);
void text_close(TextReaderHandle handle);

// 状态查询
int text_is_open(TextReaderHandle handle);
size_t text_size(TextReaderHandle handle);
const char *text_path(TextReaderHandle handle);
size_t text_line_count(TextReaderHandle handle);

// 按字节偏移读取 [offset, offset+length)，返回实际读取字节数
size_t text_read(TextReaderHandle handle, size_t offset, size_t length,
                 unsigned char *buffer, size_t buffer_size);

// 读取指定行（0-based，不含换行符），返回实际字节数
size_t text_read_line(TextReaderHandle handle, size_t line,
                      unsigned char *buffer, size_t buffer_size);

// 最近一次错误信息
const char *text_error(TextReaderHandle handle);

#ifdef __cplusplus
}
#endif

#endif // TEXT_TEXT_H
