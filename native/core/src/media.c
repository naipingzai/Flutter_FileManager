/*
 * media_core.cpp - media 模块 core 实现
 *
 * 图片解码（stb_image）、电子书（miniz）、
 * 视频/音频解码（FFmpeg，按需启用）。
 *
 * 平台差异：
 *   - 图片解码、电子书、压缩包：跨平台统一
 *   - 视频/音频解码：FFmpeg 静态链接（预编译库，工程内提供）
 *   - 音频输出：platform/<os>/ 提供 ALSA/AAudio/AudioQueue/WASAPI
 */

#include "media.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <errno.h>

// stb_image 不再需要（图片解码/缩略图已 Dart 化）

// miniz - 仅包含声明，实现由预编译静态库 libminiz.a 提供
#include "miniz.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libavutil/channel_layout.h>
#include <libavutil/opt.h>
#include <libavutil/version.h>
#include <libavcodec/version.h>
#include <libavformat/version.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>

#if defined(LIBAVUTIL_VERSION_MAJOR) && \
    (LIBAVUTIL_VERSION_MAJOR > 57 || (LIBAVUTIL_VERSION_MAJOR == 57 && LIBAVUTIL_VERSION_MINOR >= 28))
#define MEDIA_HAS_CHLAYOUT 1
#else
#define MEDIA_HAS_CHLAYOUT 0
#endif

// ============================================================
// 内部工具
// ============================================================
static const char b64_table[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static char *base64_encode(const unsigned char *data, int len, int *out_len) {
    if (!data || len < 0) return NULL;
    int olen = 4 * ((len + 2) / 3);
    char *b64 = (char *)malloc(olen + 1);
    if (!b64) return NULL;
    int i = 0, j = 0;
    while (i < len) {
        unsigned int a = i < len ? data[i++] : 0;
        unsigned int b = i < len ? data[i++] : 0;
        unsigned int c = i < len ? data[i++] : 0;
        unsigned int triple = (a << 16) | (b << 8) | c;
        b64[j++] = b64_table[(triple >> 18) & 0x3F];
        b64[j++] = b64_table[(triple >> 12) & 0x3F];
        b64[j++] = (i > len + 1) ? '=' : b64_table[(triple >> 6) & 0x3F];
        b64[j++] = (i > len) ? '=' : b64_table[triple & 0x3F];
    }
    b64[j] = '\0';
    if (out_len) *out_len = olen;
    return b64;
}

static char *strdup_std(const char *s) {
    if (!s) return NULL;
    size_t n = strlen(s) + 1;
    char *d = (char *)malloc(n);
    if (d) memcpy(d, s, n);
    return d;
}

static unsigned char *read_file_bytes(const char *path, int *out_len) {
    if (!path) return NULL;
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 0) { fclose(f); return NULL; }
    unsigned char *buf = (unsigned char *)malloc((size_t)size);
    if (!buf) { fclose(f); return NULL; }
    size_t rd = fread(buf, 1, (size_t)size, f);
    fclose(f);
    if (rd != (size_t)size) { free(buf); return NULL; }
    if (out_len) *out_len = (int)size;
    return buf;
}

// ============================================================
// 把 RGBA 图像盒式采样缩放到 max_size 内并 base64 编码为 JSON
// ============================================================
static char *thumb_to_json(const unsigned char *img, int w, int h, int max_size) {
    if (max_size <= 0) max_size = 256;
    int m = w > h ? w : h;
    float scale = 1.0f;
    if (m > max_size) scale = (float)max_size / (float)m;
    int tw = (int)(w * scale); if (tw < 1) tw = 1;
    int th = (int)(h * scale); if (th < 1) th = 1;
    unsigned char *thumb = (unsigned char *)malloc((size_t)tw * th * 4);
    if (!thumb) return strdup_std("{\"error\":\"alloc\",\"base64\":\"\",\"width\":0,\"height\":0}");
    for (int y = 0; y < th; y++) {
        for (int x = 0; x < tw; x++) {
            int sx0 = (int)((x) / scale), sx1 = (int)((x + 1) / scale);
            int sy0 = (int)((y) / scale), sy1 = (int)((y + 1) / scale);
            if (sx1 > w) sx1 = w;
            if (sy1 > h) sy1 = h;
            int cnt = (sx1 - sx0) * (sy1 - sy0); if (cnt < 1) cnt = 1;
            unsigned int r = 0, g = 0, b = 0, a = 0;
            for (int sy = sy0; sy < sy1; sy++)
                for (int sx = sx0; sx < sx1; sx++) {
                    const unsigned char *p = img + ((size_t)sy * w + sx) * 4;
                    r += p[0]; g += p[1]; b += p[2]; a += p[3];
                }
            unsigned char *o = thumb + ((size_t)y * tw + x) * 4;
            o[0] = (unsigned char)(r / cnt); o[1] = (unsigned char)(g / cnt);
            o[2] = (unsigned char)(b / cnt); o[3] = (unsigned char)(a / cnt);
        }
    }
    int b64_len = 0;
    char *b64 = base64_encode(thumb, tw * th * 4, &b64_len);
    free(thumb);
    if (!b64) return strdup_std("{\"error\":\"alloc\",\"base64\":\"\",\"width\":0,\"height\":0}");
    size_t out_len = (size_t)b64_len + 128;
    char *out = (char *)malloc(out_len);
    if (!out) { free(b64); return strdup_std("{\"error\":\"alloc\",\"base64\":\"\",\"width\":0,\"height\":0}"); }
    snprintf(out, out_len, "{\"error\":\"\",\"base64\":\"%s\",\"width\":%d,\"height\":%d}", b64, tw, th);
    free(b64);
    return out;
}

// 生成视频封面：解码第一帧并缩略
char *media_make_video_thumbnail(const char *path, int max_size) {
    int flen = 0;
    unsigned char *fdata = read_file_bytes(path, &flen);
    if (!fdata) return strdup_std("{\"error\":\"read\",\"base64\":\"\",\"width\":0,\"height\":0}");
    void *h = media_video_open(fdata, flen);
    free(fdata);
    if (!h) return strdup_std("{\"error\":\"open\",\"base64\":\"\",\"width\":0,\"height\":0}");
    char *info = media_video_get_info(h);
    int w = 0, hgt = 0;
    const char *p = strstr(info, "\"width\":");
    if (p) w = atoi(p + 8);
    p = strstr(info, "\"height\":");
    if (p) hgt = atoi(p + 9);
    media_free_string(info);
    char *result = strdup_std("{\"error\":\"no frame\",\"base64\":\"\",\"width\":0,\"height\":0}");
    if (w > 0 && hgt > 0) {
        unsigned char *rgba = (unsigned char *)malloc((size_t)w * hgt * 4);
        int cw = 0, chh = 0;
        double ts = 0;
        int r = media_video_next_frame_rgba(h, rgba, w * hgt * 4, &cw, &chh, &ts);
        if (r == 1 && cw > 0 && chh > 0 && cw <= w && chh <= hgt) {
            result = thumb_to_json(rgba, cw, chh, max_size);
        }
        free(rgba);
    }
    media_video_close(h);
    return result;
}

// ============================================================
// 电子书 EPUB（miniz）
// ============================================================

char *media_epub_list_files(const char *path) {
    int len = 0;
    unsigned char *data = read_file_bytes(path, &len);
    if (!data) return strdup_std("{\"error\":\"read failed\",\"files\":[]}");
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_reader_init_mem(&zip, data, len, 0)) {
        free(data);
        return strdup_std("{\"error\":\"not a valid epub/zip\",\"files\":[]}");
    }
    mz_uint n = mz_zip_reader_get_num_files(&zip);
    size_t cap = 64 + n * 256;
    char *json = (char *)malloc(cap);
    if (!json) { mz_zip_reader_end(&zip); free(data); return strdup_std("{\"error\":\"alloc\",\"files\":[]}"); }
    size_t pos = 0;
    pos += (size_t)snprintf(json + pos, cap - pos, "{\"error\":\"\",\"files\":[");
    for (mz_uint i = 0; i < n; i++) {
        mz_zip_archive_file_stat st;
        if (!mz_zip_reader_file_stat(&zip, i, &st)) continue;
        if (i > 0) pos += (size_t)snprintf(json + pos, cap - pos, ",");
        size_t need = 16 + strlen(st.m_filename) * 2;
        if (pos + need >= cap) {
            cap *= 2;
            char *nj = (char *)realloc(json, cap);
            if (!nj) break;
            json = nj;
        }
        pos += (size_t)snprintf(json + pos, cap - pos, "{\"name\":\"%s\"}", st.m_filename);
    }
    pos += (size_t)snprintf(json + pos, cap - pos, "]}");
    mz_zip_reader_end(&zip);
    free(data);
    return json;
}

char *media_epub_extract_text(const char *path) {
    int len = 0;
    unsigned char *data = read_file_bytes(path, &len);
    if (!data) return strdup_std("{\"error\":\"read failed\",\"text\":\"\"}");
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_reader_init_mem(&zip, data, len, 0)) {
        free(data);
        return strdup_std("{\"error\":\"not a valid epub/zip\",\"text\":\"\"}");
    }
    size_t csize = 0;
    void *cdata = mz_zip_reader_extract_file_to_heap(&zip, "META-INF/container.xml", &csize, 0);
    char *content_path = NULL;
    if (cdata) {
        char *xml = (char *)malloc(csize + 1);
        if (xml) {
            memcpy(xml, cdata, csize);
            xml[csize] = '\0';
            const char *mark = strstr(xml, "full-path=");
            if (mark) {
                mark = strchr(mark, '"');
                if (mark) {
                    mark++;
                    const char *end = strchr(mark, '"');
                    if (end) {
                        size_t plen = end - mark;
                        content_path = (char *)malloc(plen + 1);
                        if (content_path) {
                            memcpy(content_path, mark, plen);
                            content_path[plen] = '\0';
                        }
                    }
                }
            }
            free(xml);
        }
        free(cdata);
    }
    char *result = NULL;
    if (content_path) {
        size_t size = 0;
        void *cdata2 = mz_zip_reader_extract_file_to_heap(&zip, content_path, &size, 0);
        if (cdata2) {
            result = (char *)malloc(size + 64);
            if (result) {
                snprintf(result, size + 64, "{\"error\":\"\",\"text\":\"");
                const unsigned char *p = (const unsigned char *)cdata2;
                size_t pos = strlen(result);
                for (size_t i = 0; i < size && pos < size + 32; i++) {
                    unsigned char c = p[i];
                    if (c == '"' || c == '\\') { result[pos++] = '\\'; }
                    result[pos++] = (char)c;
                }
                result[pos++] = '"';
                result[pos++] = '}';
                result[pos] = '\0';
            }
            free(cdata2);
        }
        free(content_path);
    }
    mz_zip_reader_end(&zip);
    free(data);
    if (!result) return strdup_std("{\"error\":\"no content found\",\"text\":\"\"}");
    return result;
}

// ============================================================
// 压缩包工具（miniz）
// ============================================================

static void json_append_esc(char **json, size_t *cap, size_t *pos, const char *s) {
    if (!s) { s = ""; }
    size_t need = strlen(s) * 2 + 4;
    if (*pos + need >= *cap) {
        *cap = (*pos + need) * 2;
        char *nj = (char *)realloc(*json, *cap);
        if (!nj) return;
        *json = nj;
    }
    (*json)[(*pos)++] = '"';
    for (const char *p = s; *p; p++) {
        if (*p == '"' || *p == '\\') { (*json)[(*pos)++] = '\\'; }
        (*json)[(*pos)++] = *p;
    }
    (*json)[(*pos)++] = '"';
    (*json)[*pos] = '\0';
}

char *media_archive_list(const char *path) {
    int len = 0;
    unsigned char *data = read_file_bytes(path, &len);
    if (!data) return strdup_std("{\"error\":\"read failed\",\"items\":[]}");
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_reader_init_mem(&zip, data, len, 0)) {
        free(data);
        return strdup_std("{\"error\":\"not a valid zip\",\"items\":[]}");
    }
    mz_uint n = mz_zip_reader_get_num_files(&zip);
    size_t cap = 64 + n * 256;
    char *json = (char *)malloc(cap);
    if (!json) { mz_zip_reader_end(&zip); free(data); return strdup_std("{\"error\":\"alloc\",\"items\":[]}"); }
    size_t pos = 0;
    pos += (size_t)snprintf(json + pos, cap - pos, "{\"error\":\"\",\"items\":[");
    for (mz_uint i = 0; i < n; i++) {
        mz_zip_archive_file_stat st;
        if (!mz_zip_reader_file_stat(&zip, i, &st)) continue;
        if (i > 0) pos += (size_t)snprintf(json + pos, cap - pos, ",");
        json_append_esc(&json, &cap, &pos, "name");
        pos += (size_t)snprintf(json + pos, cap - pos, ":");
        /* 把 zip 内反斜杠规范为斜杠 */
        char name_buf[1024];
        size_t nl = strlen(st.m_filename);
        if (nl > sizeof(name_buf) - 1) nl = sizeof(name_buf) - 1;
        memcpy(name_buf, st.m_filename, nl);
        name_buf[nl] = '\0';
        for (size_t k = 0; k < nl; k++) if (name_buf[k] == '\\') name_buf[k] = '/';
        json_append_esc(&json, &cap, &pos, name_buf);
        pos += (size_t)snprintf(json + pos, cap - pos, ",\"size\":%llu,\"isDir\":%s}",
                                (unsigned long long)st.m_uncomp_size,
                                st.m_is_directory ? "true" : "false");
    }
    pos += (size_t)snprintf(json + pos, cap - pos, "]}");
    mz_zip_reader_end(&zip);
    free(data);
    return json;
}

/* 递归创建目录（等价 mkdir -p） */
static void mkdirs(const char *path) {
    char buf[1024];
    size_t n = strlen(path);
    if (n >= sizeof(buf)) return;
    memcpy(buf, path, n + 1);
    for (size_t i = 1; buf[i]; i++) {
        if (buf[i] == '/') {
            buf[i] = '\0';
            mkdir(buf, 0755);
            buf[i] = '/';
        }
    }
    mkdir(buf, 0755);
}

/* 判断路径是否为目录 */
static int is_dir(const char *path) {
    struct stat st;
    return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

int media_archive_extract(const char *zip_path, const char *out_dir, char *error, int error_size) {
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_reader_init_file(&zip, zip_path, 0)) {
        if (error) snprintf(error, error_size, "not a valid zip");
        return -1;
    }
    mkdirs(out_dir);
    char out_base[1024];
    snprintf(out_base, sizeof(out_base), "%s", out_dir);
    size_t ob = strlen(out_base);
    if (ob > 0 && out_base[ob - 1] != '/' && out_base[ob - 1] != '\\') {
        if (ob < sizeof(out_base) - 1) { out_base[ob++] = '/'; out_base[ob] = '\0'; }
    }
    mz_uint n = mz_zip_reader_get_num_files(&zip);
    int ret = 0;
    for (mz_uint i = 0; i < n; i++) {
        mz_zip_archive_file_stat st;
        if (!mz_zip_reader_file_stat(&zip, i, &st)) continue;
        char name_buf[1024];
        size_t nl = strlen(st.m_filename);
        if (nl > sizeof(name_buf) - 1) nl = sizeof(name_buf) - 1;
        memcpy(name_buf, st.m_filename, nl);
        name_buf[nl] = '\0';
        for (size_t k = 0; k < nl; k++) if (name_buf[k] == '\\') name_buf[k] = '/';
        if (name_buf[0] == '\0' || name_buf[0] == '/') continue;
        /* 路径穿越防护 */
        if (strstr(name_buf, "/../") || strncmp(name_buf, "../", 3) == 0) continue;
        char full[2048];
        snprintf(full, sizeof(full), "%s%s", out_base, name_buf);
        int is_dir_entry = st.m_is_directory || (nl > 0 && name_buf[nl - 1] == '/');
        if (is_dir_entry) {
            mkdirs(full);
            continue;
        }
        /* 创建文件的父目录 */
        {
            char parent[2048];
            snprintf(parent, sizeof(parent), "%s", full);
            size_t pl = strlen(parent);
            while (pl > 0 && parent[pl - 1] != '/') pl--;
            if (pl > 0) parent[pl] = '\0';
            mkdirs(parent);
        }
        size_t size = 0;
        void *buf = mz_zip_reader_extract_to_heap(&zip, i, &size, 0);
        if (!buf) {
            if (error) snprintf(error, error_size, "extract failed: %s", name_buf);
            ret = -1;
            break;
        }
        FILE *out = fopen(full, "wb");
        if (!out) {
            free(buf);
            if (error) snprintf(error, error_size, "cannot create: %s", name_buf);
            ret = -1;
            break;
        }
        if (size > 0 && fwrite(buf, 1, size, out) != size) {
            if (error) snprintf(error, error_size, "write failed: %s", name_buf);
            ret = -1;
        }
        fclose(out);
        free(buf);
        if (ret != 0) break;
    }
    mz_zip_reader_end(&zip);
    return ret;
}

/* 把一个文件加入 zip。rel=zip 内相对路径, abs=磁盘绝对路径。返回 0=成功 */
static int zip_add_file(mz_zip_archive *zip, const char *rel, const char *abs, char *error, int error_size) {
    FILE *f = fopen(abs, "rb");
    if (!f) {
        if (error) snprintf(error, error_size, "open %s", abs);
        return -1;
    }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    void *buf = malloc(sz > 0 ? (size_t)sz : 1);
    size_t rd = buf ? fread(buf, 1, (size_t)sz, f) : 0;
    fclose(f);
    if (!buf || rd != (size_t)sz) {
        free(buf);
        if (error) snprintf(error, error_size, "read %s", abs);
        return -1;
    }
    mz_bool ok = mz_zip_writer_add_mem(zip, rel, buf, (size_t)sz, MZ_DEFAULT_COMPRESSION);
    free(buf);
    if (!ok) {
        if (error) snprintf(error, error_size, "zip add %s", rel);
        return -1;
    }
    return 0;
}

/* 递归遍历 dir，把所有文件加入 zip（dir 下所有路径前加 base_prefix） */
static int zip_add_dir_recursive(mz_zip_archive *zip, const char *dir, const char *base_prefix,
                                 char *error, int error_size) {
    DIR *d = opendir(dir);
    if (!d) {
        if (error) snprintf(error, error_size, "open dir %s", dir);
        return -1;
    }
    struct dirent *e;
    int ret = 0;
    while ((e = readdir(d)) != NULL) {
        if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
        char abs_path[2048];
        snprintf(abs_path, sizeof(abs_path), "%s/%s", dir, e->d_name);
        char rel_path[2048];
        snprintf(rel_path, sizeof(rel_path), "%s/%s", base_prefix, e->d_name);
        struct stat st;
        if (stat(abs_path, &st) != 0) continue;
        if (S_ISDIR(st.st_mode)) {
            /* 记录空目录 + 递归 */
            char dir_rel[2048];
            snprintf(dir_rel, sizeof(dir_rel), "%s/", rel_path);
            mz_zip_writer_add_mem(zip, dir_rel, NULL, 0, 0);
            if (zip_add_dir_recursive(zip, abs_path, rel_path, error, error_size) != 0) { ret = -1; break; }
        } else if (S_ISREG(st.st_mode)) {
            if (zip_add_file(zip, rel_path, abs_path, error, error_size) != 0) { ret = -1; break; }
        }
    }
    closedir(d);
    return ret;
}

int media_archive_create(const char *src_path, const char *zip_path, char *error, int error_size) {
    if (access(src_path, F_OK) != 0) {
        if (error) snprintf(error, error_size, "source not found");
        return -1;
    }
    unlink(zip_path);
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_writer_init_file(&zip, zip_path, 0)) {
        if (error) snprintf(error, error_size, "cannot create zip");
        return -1;
    }
    /* 取 basename 作为 zip 内顶层目录名 */
    char base[1024];
    snprintf(base, sizeof(base), "%s", src_path);
    size_t bl = strlen(base);
    while (bl > 0 && base[bl - 1] == '/') base[--bl] = '\0';
    char *slash = strrchr(base, '/');
    const char *name = slash ? slash + 1 : base;

    int ret = 0;
    if (is_dir(src_path)) {
        char top[1024];
        snprintf(top, sizeof(top), "%s/", name);
        mz_zip_writer_add_mem(&zip, top, NULL, 0, 0);
        if (zip_add_dir_recursive(&zip, src_path, name, error, error_size) != 0) ret = -1;
    } else {
        if (zip_add_file(&zip, name, src_path, error, error_size) != 0) ret = -1;
    }

    mz_zip_writer_finalize_archive(&zip);
    mz_zip_writer_end(&zip);
    if (ret != 0) {
        unlink(zip_path);
        return -1;
    }
    return 0;
}

void media_free_string(char *str) { if (str) free(str); }

// ============================================================
// 视频/音频（FFmpeg）
// ============================================================

typedef struct {
    const unsigned char *data;
    int len;
    int pos;
} MemCtx;

static int64_t mem_seek(void *opaque, int64_t offset, int whence) {
    MemCtx *ctx = (MemCtx *)opaque;
    int64_t new_pos;
    if (whence == SEEK_SET) new_pos = offset;
    else if (whence == SEEK_CUR) new_pos = ctx->pos + offset;
    else if (whence == SEEK_END) new_pos = ctx->len + offset;
    else return -1;
    if (new_pos < 0) new_pos = 0;
    if (new_pos > ctx->len) new_pos = ctx->len;
    ctx->pos = (int)new_pos;
    return new_pos;
}

static int mem_read_packet(void *opaque, uint8_t *buf, int buf_size) {
    MemCtx *ctx = (MemCtx *)opaque;
    int avail = ctx->len - ctx->pos;
    if (avail <= 0) return AVERROR_EOF;
    int n = avail < buf_size ? avail : buf_size;
    memcpy(buf, ctx->data + ctx->pos, n);
    ctx->pos += n;
    return n;
}

typedef struct {
    MemCtx mem;
    AVFormatContext *fmt_ctx;
    AVIOContext *avio;
    AVCodecContext *codec_ctx;
    struct SwsContext *sws_ctx;
    int video_stream;
    int audio_stream;
    double duration;
    double fps;
    AVRational video_time_base; // 视频流时间基（PTS 转换用）
} MediaCtx;

static MediaCtx *media_open_mem(const unsigned char *data, int len) {
    if (!data || len <= 0) return NULL;
    MediaCtx *m = (MediaCtx *)calloc(1, sizeof(MediaCtx));
    if (!m) return NULL;
    m->mem.data = data;
    m->mem.len = len;
    m->mem.pos = 0;
    m->video_stream = -1;
    m->audio_stream = -1;
    const int avio_buf_size = 256 * 1024;
    m->avio = avio_alloc_context((unsigned char *)av_malloc(avio_buf_size), avio_buf_size, 0, &m->mem,
                                 mem_read_packet, NULL, mem_seek);
    if (!m->avio) { free(m); return NULL; }
    m->avio->seekable = AVIO_SEEKABLE_NORMAL;
#if !defined(LIBAVFORMAT_VERSION_MAJOR) || LIBAVFORMAT_VERSION_MAJOR < 61
    m->avio->maxsize = m->mem.len;
#endif
    m->fmt_ctx = avformat_alloc_context();
    m->fmt_ctx->pb = m->avio;
    m->fmt_ctx->flags |= AVFMT_FLAG_CUSTOM_IO;
    m->fmt_ctx->probesize = 50 * 1024 * 1024;
    m->fmt_ctx->max_analyze_duration = 30 * AV_TIME_BASE;
    if (avformat_open_input(&m->fmt_ctx, NULL, NULL, NULL) != 0) {
        avio_context_free(&m->avio);
        free(m);
        return NULL;
    }
    if (avformat_find_stream_info(m->fmt_ctx, NULL) < 0) {
        avformat_close_input(&m->fmt_ctx);
        avio_context_free(&m->avio);
        free(m);
        return NULL;
    }
    for (unsigned int i = 0; i < m->fmt_ctx->nb_streams; i++) {
        AVStream *st = m->fmt_ctx->streams[i];
        if (st->codecpar->codec_type == AVMEDIA_TYPE_VIDEO && m->video_stream < 0)
            m->video_stream = i;
        else if (st->codecpar->codec_type == AVMEDIA_TYPE_AUDIO && m->audio_stream < 0)
            m->audio_stream = i;
    }
    m->duration = m->fmt_ctx->duration > 0 ? m->fmt_ctx->duration / (double)AV_TIME_BASE : 0;
    return m;
}

void *media_video_open(const unsigned char *data, int len) {
    MediaCtx *m = media_open_mem(data, len);
    if (!m || m->video_stream < 0) {
        if (m) media_video_close(m);
        return NULL;
    }
    AVStream *st = m->fmt_ctx->streams[m->video_stream];
    const AVCodec *codec = avcodec_find_decoder(st->codecpar->codec_id);
    if (!codec) { media_video_close(m); return NULL; }
    m->codec_ctx = avcodec_alloc_context3(codec);
    if (!m->codec_ctx) { media_video_close(m); return NULL; }
    if (avcodec_parameters_to_context(m->codec_ctx, st->codecpar) < 0) {
        media_video_close(m);
        return NULL;
    }
    m->codec_ctx->pkt_timebase = st->time_base;
    if (avcodec_open2(m->codec_ctx, codec, NULL) < 0) {
        media_video_close(m);
        return NULL;
    }
    enum AVPixelFormat src_fmt = m->codec_ctx->pix_fmt;
    if (src_fmt == AV_PIX_FMT_NONE) src_fmt = AV_PIX_FMT_YUV420P;
    m->sws_ctx = sws_getContext(m->codec_ctx->width, m->codec_ctx->height, src_fmt,
                                m->codec_ctx->width, m->codec_ctx->height,
                                AV_PIX_FMT_RGBA, SWS_BILINEAR, NULL, NULL, NULL);
    if (!m->sws_ctx) { media_video_close(m); return NULL; }
    double fps = st->avg_frame_rate.num && st->avg_frame_rate.den
                 ? av_q2d(st->avg_frame_rate) : 25.0;
    m->fps = fps > 0 ? fps : 25.0;
    m->video_time_base = st->time_base;
    return m;
}

// 解码一帧，把紧凑 RGBA（w*h*4）写入 out。返回 1=有帧, 0=EOF, -1=错误, -2=缓冲区过小。
// sws_scale 需要对齐行距：先用 av_image_alloc 分配对齐缓冲，再打包成紧凑 RGBA 写入 out，
// 避免 SIMD 行尾越界写坏堆块。
static int media_video_next_frame_rgba_internal(MediaCtx *m,
        unsigned char *out, int out_cap, int *out_w, int *out_h, double *out_ts) {
    if (!m || !m->codec_ctx || !out) return -1;
    AVFrame *frame_out = av_frame_alloc();
    if (!frame_out) return -1;
    int ret = -1;
    AVPacket pkt;
    memset(&pkt, 0, sizeof(pkt));
    while (av_read_frame(m->fmt_ctx, &pkt) >= 0) {
        if (pkt.size <= 0) { av_packet_unref(&pkt); continue; }
        if (pkt.stream_index == m->video_stream) {
            int send_ret = avcodec_send_packet(m->codec_ctx, &pkt);
            av_packet_unref(&pkt);
            if (send_ret < 0 && send_ret != AVERROR(EAGAIN) && send_ret != AVERROR_EOF) {
                ret = -1;
                goto cleanup;
            }
            int recv_ret = avcodec_receive_frame(m->codec_ctx, frame_out);
            while (recv_ret >= 0) {
                int w = m->codec_ctx->width, h = m->codec_ctx->height;
                if (!frame_out->data[0] || w <= 0 || h <= 0) {
                    recv_ret = avcodec_receive_frame(m->codec_ctx, frame_out);
                    continue;
                }
                int need = w * h * 4;
                if (out_cap < need) { ret = -2; goto cleanup; }
                uint8_t *dst_data[4] = { NULL, NULL, NULL, NULL };
                int dst_linesize[4] = { 0, 0, 0, 0 };
                int av_ret = av_image_alloc(dst_data, dst_linesize, w, h, AV_PIX_FMT_RGBA, 32);
                if (av_ret < 0 || !dst_data[0]) {
                    recv_ret = avcodec_receive_frame(m->codec_ctx, frame_out);
                    continue;
                }
                int scaled = sws_scale(m->sws_ctx,
                              (const uint8_t *const *)frame_out->data,
                              frame_out->linesize,
                              0, h,
                              (uint8_t *const *)dst_data,
                              dst_linesize);
                if (scaled <= 0) {
                    av_freep(&dst_data[0]);
                    recv_ret = avcodec_receive_frame(m->codec_ctx, frame_out);
                    continue;
                }
                for (int y = 0; y < h; y++) {
                    memcpy(out + (size_t)y * (size_t)w * 4,
                           dst_data[0] + (size_t)y * (size_t)dst_linesize[0],
                           (size_t)w * 4);
                }
                av_freep(&dst_data[0]);
                int64_t pts = frame_out->best_effort_timestamp;
                if (pts == AV_NOPTS_VALUE) pts = frame_out->pts;
                double ts = pts != AV_NOPTS_VALUE
                            ? pts * av_q2d(m->video_time_base) : 0.0;
                if (out_w) *out_w = w;
                if (out_h) *out_h = h;
                if (out_ts) *out_ts = ts;
                ret = 1;
                goto cleanup;
            }
            if (recv_ret == AVERROR_EOF) { ret = 0; goto cleanup; }
        } else {
            av_packet_unref(&pkt);
        }
    }
    ret = 0;
cleanup:
    av_frame_free(&frame_out);
    return ret;
}

int media_video_next_frame_rgba(void *handle, unsigned char *out, int out_cap,
                                int *out_w, int *out_h, double *out_ts) {
    return media_video_next_frame_rgba_internal((MediaCtx *)handle,
                                                out, out_cap, out_w, out_h, out_ts);
}

int media_video_seek(void *handle, double timestamp) {
    MediaCtx *m = (MediaCtx *)handle;
    if (!m || !m->fmt_ctx) return 0;
    int64_t ts = (int64_t)(timestamp * AV_TIME_BASE);
    int ret = avformat_seek_file(m->fmt_ctx, -1, INT64_MIN, ts, INT64_MAX, 0);
    if (ret >= 0 && m->codec_ctx) {
        avcodec_flush_buffers(m->codec_ctx);
        return 1;
    }
    return 0;
}

char *media_video_get_info(void *handle) {
    MediaCtx *m = (MediaCtx *)handle;
    if (!m || !m->codec_ctx)
        return strdup_std("{\"error\":\"invalid handle\",\"width\":0,\"height\":0,\"duration\":0,\"fps\":0}");
    char *out = (char *)malloc(128);
    snprintf(out, 128, "{\"error\":\"\",\"width\":%d,\"height\":%d,\"duration\":%f,\"fps\":%f}",
             m->codec_ctx->width, m->codec_ctx->height, m->duration, m->fps);
    return out;
}

void media_video_close(void *handle) {
    MediaCtx *m = (MediaCtx *)handle;
    if (!m) return;
    if (m->sws_ctx) sws_freeContext(m->sws_ctx);
    if (m->codec_ctx) avcodec_free_context(&m->codec_ctx);
    if (m->fmt_ctx) {
        m->fmt_ctx->pb = NULL;
        avformat_close_input(&m->fmt_ctx);
    }
    if (m->avio) avio_context_free(&m->avio);
    free(m);
}

typedef struct {
    unsigned char *data;
    size_t len;
    size_t cap;
} ByteBuf;

static int bytebuf_append(ByteBuf *b, const void *src, size_t add) {
    if (b->len + add > b->cap) {
        size_t ncap = b->cap ? b->cap * 2 : 65536;
        while (ncap < b->len + add) ncap *= 2;
        unsigned char *nd = (unsigned char *)realloc(b->data, ncap);
        if (!nd) return -1;
        b->data = nd;
        b->cap = ncap;
    }
    memcpy(b->data + b->len, src, add);
    b->len += add;
    return 0;
}

char *media_decode_audio(const unsigned char *data, int len) {
    MediaCtx *m = media_open_mem(data, len);
    if (!m || m->audio_stream < 0) {
        if (m) media_video_close(m);
        return strdup_std("{\"error\":\"no audio stream\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}");
    }
    AVStream *st = m->fmt_ctx->streams[m->audio_stream];
    const AVCodec *codec = avcodec_find_decoder(st->codecpar->codec_id);
    if (!codec) { media_video_close(m); return strdup_std("{\"error\":\"audio codec not found\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}"); }
    AVCodecContext *actx = avcodec_alloc_context3(codec);
    if (!actx) { media_video_close(m); return strdup_std("{\"error\":\"alloc\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}"); }
    if (avcodec_parameters_to_context(actx, st->codecpar) < 0) {
        avcodec_free_context(&actx);
        media_video_close(m);
        return strdup_std("{\"error\":\"params\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}");
    }
    if (avcodec_open2(actx, codec, NULL) < 0) {
        avcodec_free_context(&actx);
        media_video_close(m);
        return strdup_std("{\"error\":\"open\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}");
    }
    int out_rate = actx->sample_rate > 0 ? actx->sample_rate : 44100;
#if MEDIA_HAS_CHLAYOUT
    int out_ch = actx->ch_layout.nb_channels > 0 ? actx->ch_layout.nb_channels : 2;
#else
    int out_ch = actx->channels > 0 ? actx->channels : 2;
#endif
    SwrContext *swr = swr_alloc();
    if (!swr) { avcodec_free_context(&actx); media_video_close(m); return strdup_std("{\"error\":\"swr alloc\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}"); }
#if MEDIA_HAS_CHLAYOUT
    // FFmpeg 7.x：swr 输入/输出布局选项为 ichl/ochl（in_channel_layout 已失效），
    // 用声道数推导合法布局，避免 actx->ch_layout 无效导致 swr_init 失败
    AVChannelLayout in_layout;
    av_channel_layout_default(&in_layout, out_ch);
    av_opt_set_chlayout(swr, "ichl", &in_layout, 0);
    av_channel_layout_uninit(&in_layout);
    AVChannelLayout out_layout;
    av_channel_layout_default(&out_layout, out_ch);
    av_opt_set_chlayout(swr, "ochl", &out_layout, 0);
    av_channel_layout_uninit(&out_layout);
#else
    int64_t in_layout = actx->channel_layout;
    if (!in_layout) in_layout = av_get_default_channel_layout(out_ch);
    av_opt_set_int(swr, "in_channel_layout", in_layout, 0);
    av_opt_set_int(swr, "out_channel_layout", in_layout, 0);
#endif
    av_opt_set_int(swr, "in_sample_rate", out_rate, 0);
    av_opt_set_sample_fmt(swr, "in_sample_fmt", actx->sample_fmt, 0);
    av_opt_set_int(swr, "out_sample_rate", out_rate, 0);
    av_opt_set_sample_fmt(swr, "out_sample_fmt", AV_SAMPLE_FMT_S16, 0);
    if (swr_init(swr) < 0) {
        swr_free(&swr);
        avcodec_free_context(&actx);
        media_video_close(m);
        return strdup_std("{\"error\":\"swr init\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}");
    }
    AVPacket pkt;
    memset(&pkt, 0, sizeof(pkt));
    AVFrame *frm = av_frame_alloc();
    ByteBuf pcm = { NULL, 0, 0 };
    int decode_ok = 0;
    while (av_read_frame(m->fmt_ctx, &pkt) >= 0) {
        if (pkt.stream_index == m->audio_stream && pkt.size > 0) {
            int sret = avcodec_send_packet(actx, &pkt);
            if (sret < 0 && sret != AVERROR(EAGAIN) && sret != AVERROR_EOF) {
                av_packet_unref(&pkt);
                break;
            }
            for (;;) {
                int rret = avcodec_receive_frame(actx, frm);
                if (rret == AVERROR(EAGAIN) || rret == AVERROR_EOF) break;
                if (rret < 0) break;
#if MEDIA_HAS_CHLAYOUT
                int ch = frm->ch_layout.nb_channels > 0 ? frm->ch_layout.nb_channels : out_ch;
#else
                int ch = frm->channels > 0 ? frm->channels : out_ch;
#endif
                int out_samples = swr_get_out_samples(swr, frm->nb_samples);
                if (out_samples <= 0) continue;
                int obytes = av_samples_get_buffer_size(NULL, ch, out_samples, AV_SAMPLE_FMT_S16, 1);
                if (obytes <= 0) continue;
                unsigned char *obuf = (unsigned char *)malloc((size_t)obytes);
                if (!obuf) break;
                uint8_t *obufs[1] = { obuf };
                int got = swr_convert(swr, obufs, out_samples,
                                      (const uint8_t **)frm->extended_data, frm->nb_samples);
                int bytes = got > 0 ? av_samples_get_buffer_size(NULL, ch, got, AV_SAMPLE_FMT_S16, 1) : 0;
                if (bytes > 0 && bytebuf_append(&pcm, obuf, (size_t)bytes) != 0) {
                    free(obuf);
                    break;
                }
                free(obuf);
                decode_ok = 1;
            }
        }
        av_packet_unref(&pkt);
    }
    avcodec_send_packet(actx, NULL);
    while (avcodec_receive_frame(actx, frm) >= 0) {
#if MEDIA_HAS_CHLAYOUT
        int ch = frm->ch_layout.nb_channels > 0 ? frm->ch_layout.nb_channels : out_ch;
#else
        int ch = frm->channels > 0 ? frm->channels : out_ch;
#endif
        int out_samples = swr_get_out_samples(swr, frm->nb_samples);
        if (out_samples <= 0) continue;
        int obytes = av_samples_get_buffer_size(NULL, ch, out_samples, AV_SAMPLE_FMT_S16, 1);
        if (obytes <= 0) continue;
        unsigned char *obuf = (unsigned char *)malloc((size_t)obytes);
        if (!obuf) break;
        uint8_t *obufs[1] = { obuf };
        int got = swr_convert(swr, obufs, out_samples,
                              (const uint8_t **)frm->extended_data, frm->nb_samples);
        int bytes = got > 0 ? av_samples_get_buffer_size(NULL, ch, got, AV_SAMPLE_FMT_S16, 1) : 0;
        if (bytes > 0 && bytebuf_append(&pcm, obuf, (size_t)bytes) != 0) { free(obuf); break; }
        free(obuf);
        decode_ok = 1;
    }
    av_frame_free(&frm);
    swr_free(&swr);
    avcodec_free_context(&actx);
    media_video_close(m);
    if (!decode_ok || pcm.len == 0) {
        free(pcm.data);
        return strdup_std("{\"error\":\"no audio frame\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}");
    }
    int b64_len = 0;
    char *b64 = base64_encode(pcm.data, (int)pcm.len, &b64_len);
    int pcm_len = (int)pcm.len;
    free(pcm.data);
    if (!b64) return strdup_std("{\"error\":\"alloc\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}");
    size_t out_len = (size_t)b64_len + 128;
    char *out = (char *)malloc(out_len);
    if (!out) { free(b64); return strdup_std("{\"error\":\"alloc\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}"); }
    snprintf(out, out_len,
             "{\"error\":\"\",\"base64\":\"%s\",\"sample_rate\":%d,\"channels\":%d,\"bits\":16,\"length\":%d}",
             b64, out_rate, out_ch, pcm_len);
    free(b64);
    return out;
}
