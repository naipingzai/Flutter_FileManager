/*
 * json_builder.c - 统一 JSON 字符串构建器实现
 */

#include "common/json_builder.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static void jb_ensure_capacity(JsonBuilder *jb, int extra) {
    if (jb->err) return;
    if (jb->len + extra + 1 > jb->capacity) {
        int new_cap = (jb->len + extra + 1) * 2;
        if (new_cap < 64) new_cap = 64;
        char *nd = (char *)realloc(jb->data, (size_t)new_cap);
        if (!nd) {
            jb->err = 1;
            return;
        }
        jb->data = nd;
        jb->capacity = new_cap;
    }
}

JsonBuilder jb_new(void) {
    JsonBuilder jb;
    jb.capacity = 256;
    jb.len = 0;
    jb.err = 0;
    jb.data = (char *)malloc((size_t)jb.capacity);
    if (!jb.data) {
        jb.err = 1;
        jb.capacity = 0;
        return jb;
    }
    jb.data[0] = '\0';
    return jb;
}

void jb_free(JsonBuilder *jb) {
    if (!jb) return;
    if (jb->data) {
        free(jb->data);
        jb->data = NULL;
    }
    jb->len = 0;
    jb->capacity = 0;
    jb->err = 0;
}

void jb_reset(JsonBuilder *jb) {
    if (!jb) return;
    jb->len = 0;
    jb->err = 0;
    if (jb->data && jb->capacity > 0) jb->data[0] = '\0';
}

void jb_append_str(JsonBuilder *jb, const char *s) {
    if (!jb || jb->err || !s) return;
    int slen = (int)strlen(s);
    jb_ensure_capacity(jb, slen);
    if (jb->err) return;
    memcpy(jb->data + jb->len, s, (size_t)slen);
    jb->len += slen;
    jb->data[jb->len] = '\0';
}

void jb_append_esc(JsonBuilder *jb, const char *s) {
    if (!jb) return;
    if (!s) {
        jb_append_str(jb, "null");
        return;
    }
    jb_append_str(jb, "\"");
    for (const char *p = s; *p; ++p) {
        switch (*p) {
            case '"':  jb_append_str(jb, "\\\""); break;
            case '\\': jb_append_str(jb, "\\\\"); break;
            case '\n': jb_append_str(jb, "\\n"); break;
            case '\r': jb_append_str(jb, "\\r"); break;
            case '\t': jb_append_str(jb, "\\t"); break;
            case '\b': jb_append_str(jb, "\\b"); break;
            case '\f': jb_append_str(jb, "\\f"); break;
            default: {
                if ((unsigned char)*p < 0x20) {
                    char buf[8];
                    snprintf(buf, sizeof(buf), "\\u%04x", (unsigned char)*p);
                    jb_append_str(jb, buf);
                } else {
                    jb_ensure_capacity(jb, 2);
                    if (jb->err) return;
                    jb->data[jb->len++] = *p;
                    jb->data[jb->len] = '\0';
                }
                break;
            }
        }
    }
    jb_append_str(jb, "\"");
}

void jb_append_int(JsonBuilder *jb, long long val) {
    if (!jb || jb->err) return;
    char buf[32];
    int n = snprintf(buf, sizeof(buf), "%lld", val);
    if (n > 0) jb_append_str(jb, buf);
}

void jb_append_uint(JsonBuilder *jb, unsigned long long val) {
    if (!jb || jb->err) return;
    char buf[32];
    int n = snprintf(buf, sizeof(buf), "%llu", val);
    if (n > 0) jb_append_str(jb, buf);
}

void jb_append_bool(JsonBuilder *jb, bool val) {
    jb_append_str(jb, val ? "true" : "false");
}

void jb_append_double(JsonBuilder *jb, double val) {
    if (!jb || jb->err) return;
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", val);
    jb_append_str(jb, buf);
}

void jb_append_null(JsonBuilder *jb) {
    jb_append_str(jb, "null");
}

void jb_append_raw(JsonBuilder *jb, const char *s) {
    jb_append_str(jb, s);
}

char *jb_finish(JsonBuilder *jb) {
    if (!jb) return NULL;
    if (jb->err) {
        free(jb->data);
        jb->data = NULL;
        return NULL;
    }
    char *r = jb->data;
    jb->data = NULL;
    jb->len = 0;
    jb->capacity = 0;
    return r;
}
