/*
 * json_builder.h - 统一 JSON 字符串构建器
 *
 * 所有模块在 FFI 出口构造 JSON 响应时使用同一个 JSON Builder，
 * 避免每个模块重复实现 JSON 拼接逻辑。
 *
 * 用法：
 *   JsonBuilder jb = jb_new();
 *   jb_append_str(&jb, "key"); jb_append_str(&jb, "value");
 *   char* out = jb_finish(&jb);   // 调用方需 free()
 */

#ifndef COMMON_JSON_BUILDER_H
#define COMMON_JSON_BUILDER_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char *data;
    int len;
    int capacity;
    int err;
} JsonBuilder;

JsonBuilder jb_new(void);
void jb_free(JsonBuilder *jb);
void jb_append_str(JsonBuilder *jb, const char *s);
void jb_append_esc(JsonBuilder *jb, const char *s);
void jb_append_int(JsonBuilder *jb, long long val);
void jb_append_uint(JsonBuilder *jb, unsigned long long val);
void jb_append_bool(JsonBuilder *jb, bool val);
void jb_append_double(JsonBuilder *jb, double val);
void jb_append_null(JsonBuilder *jb);
void jb_append_raw(JsonBuilder *jb, const char *s);

// 完成并返回字符串（调用方 free）。后续 jb 不可用。
char *jb_finish(JsonBuilder *jb);

// 重置为可复用状态（保留 capacity）
void jb_reset(JsonBuilder *jb);

#ifdef __cplusplus
}
#endif

#endif // COMMON_JSON_BUILDER_H
