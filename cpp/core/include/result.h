/*
 * result.h - 统一错误处理 Result<T>
 *
 * 跨模块统一错误处理（C ABI）。所有模块对外暴露的 C API
 * 一律返回 Result<T>，包含 success/error_code/error_message。
 *
 * 错误码定义（统一）：
 *   - RESULT_OK                = 0
 *   - RESULT_ERR_INVALID_ARG   = 1
 *   - RESULT_ERR_IO            = 2
 *   - RESULT_ERR_NOT_FOUND     = 3
 *   - RESULT_ERR_EXISTS        = 4
 *   - RESULT_ERR_NO_MEMORY     = 5
 *   - RESULT_ERR_PERMISSION    = 6
 *   - RESULT_ERR_PLATFORM      = 7   // 平台层返回的原生错误
 *   - RESULT_ERR_UNSUPPORTED   = 8
 *   - RESULT_ERR_OTHER         = 99
 *
 * 业务模块的实现细节内部仍可用 errno/GetLastError/HRESULT 等。
 * 在 Result 上抛错前必须把原生错误转换为错误码 + 可读消息。
 */

#ifndef COMMON_RESULT_H
#define COMMON_RESULT_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    RESULT_OK = 0,
    RESULT_ERR_INVALID_ARG = 1,
    RESULT_ERR_IO = 2,
    RESULT_ERR_NOT_FOUND = 3,
    RESULT_ERR_EXISTS = 4,
    RESULT_ERR_NO_MEMORY = 5,
    RESULT_ERR_PERMISSION = 6,
    RESULT_ERR_PLATFORM = 7,
    RESULT_ERR_UNSUPPORTED = 8,
    RESULT_ERR_OTHER = 99,
} ResultCode;

#define RESULT_MSG_MAX 512

typedef struct {
    ResultCode code;
    char message[RESULT_MSG_MAX];
} CommonStatus;

// Result<T> 模板在 C 中用结构体模拟（避免暴露 std::expected 给 C ABI）
// 模块需要返回复杂数据时，定义自己的 ResultWith<T> 结构体。

static inline CommonStatus common_status_ok(void) {
    CommonStatus s = { RESULT_OK, {0} };
    return s;
}

static inline CommonStatus common_status_make(ResultCode code, const char *msg) {
    CommonStatus s;
    s.code = code;
    if (msg) {
        size_t i = 0;
        for (; i + 1 < RESULT_MSG_MAX && msg[i]; ++i) s.message[i] = msg[i];
        s.message[i] = '\0';
    } else {
        s.message[0] = '\0';
    }
    return s;
}

// Dart FFI 友好的字符串视图（释放由调用方负责）
static inline void common_status_to_json(const CommonStatus *st, char *buf, int buf_size) {
    if (!st || !buf || buf_size <= 0) return;
    int n = snprintf(buf, (size_t)buf_size,
        "{\"code\":%d,\"message\":\"%s\"}",
        (int)st->code,
        st->message[0] ? st->message : "");
    (void)n;
}

#ifdef __cplusplus
}
#endif

#endif // COMMON_RESULT_H
