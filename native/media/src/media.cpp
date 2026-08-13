// media - 多媒体解码功能（base 代码，跨平台）
// 图片：stb_image (单头文件)
// 电子书：miniz (单文件 zip)
// 视频/音频：FFmpeg (源码集成)

#include "media.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <algorithm>
#include <filesystem>
#include <string>
#include <system_error>

// stb_image - 单头文件实现
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

// miniz - 实现由 miniz.c 单独编译提供
// miniz.h 无 extern "C" 保护，C++ 包含必须用 extern "C" 包裹避免 name-mangle
extern "C" {
#include "miniz.h"
}

#ifdef HAVE_FFMPEG
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libavutil/channel_layout.h>
#include <libavutil/opt.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
}
#endif

// ============================================================
// 内部工具
// ============================================================
static const char b64_table[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static char* base64_encode(const unsigned char* data, int len, int* out_len) {
    if (!data || len < 0) return NULL;
    int olen = 4 * ((len + 2) / 3);
    char* b64 = (char*)malloc(olen + 1);
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

static char* strdup_std(const char* s) {
    if (!s) return NULL;
    size_t n = strlen(s) + 1;
    char* d = (char*)malloc(n);
    if (d) memcpy(d, s, n);
    return d;
}

static unsigned char* read_file_bytes(const char* path, int* out_len) {
    if (!path) return NULL;
    FILE* f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size <= 0) { fclose(f); return NULL; }
    unsigned char* buf = (unsigned char*)malloc(size);
    if (!buf) { fclose(f); return NULL; }
    size_t rd = fread(buf, 1, size, f);
    fclose(f);
    if (rd != (size_t)size) { free(buf); return NULL; }
    if (out_len) *out_len = (int)size;
    return buf;
}

// ============================================================
// 图片解码（stb_image）
// ============================================================

static char* decode_image_bytes(const unsigned char* data, int len) {
    int w, h, comp;
    unsigned char* img = stbi_load_from_memory(data, len, &w, &h, &comp, 4);
    if (!img) {
        char* err = (char*)malloc(256);
        snprintf(err, 256, "{\"error\":\"%s\",\"base64\":\"\",\"width\":0,\"height\":0}",
                 stbi_failure_reason());
        return err;
    }
    int img_len = w * h * 4;
    int b64_len = 0;
    char* b64 = base64_encode(img, img_len, &b64_len);
    stbi_image_free(img);
    if (!b64) return strdup_std("{\"error\":\"alloc\",\"base64\":\"\",\"width\":0,\"height\":0}");
    char* out = (char*)malloc(b64_len + 128);
    if (!out) { free(b64); return strdup_std("{\"error\":\"alloc\",\"base64\":\"\",\"width\":0,\"height\":0}"); }
    snprintf(out, b64_len + 128, "{\"error\":\"\",\"base64\":\"%s\",\"width\":%d,\"height\":%d}",
             b64, w, h);
    free(b64);
    return out;
}

char* media_decode_image_file(const char* path) {
    int len = 0;
    unsigned char* data = read_file_bytes(path, &len);
    if (!data) return strdup_std("{\"error\":\"read failed\",\"base64\":\"\",\"width\":0,\"height\":0}");
    char* result = decode_image_bytes(data, len);
    free(data);
    return result;
}

char* media_decode_image_buffer(const unsigned char* data, int len) {
    if (!data || len <= 0) return strdup_std("{\"error\":\"invalid buffer\",\"base64\":\"\",\"width\":0,\"height\":0}");
    return decode_image_bytes(data, len);
}

// ============================================================
// 电子书 EPUB（miniz）
// ============================================================

char* media_epub_list_files(const char* path) {
    int len = 0;
    unsigned char* data = read_file_bytes(path, &len);
    if (!data) return strdup_std("{\"error\":\"read failed\",\"files\":[]}");
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_reader_init_mem(&zip, data, len, 0)) {
        free(data);
        return strdup_std("{\"error\":\"not a valid epub/zip\",\"files\":[]}");
    }
    mz_uint n = mz_zip_reader_get_num_files(&zip);
    size_t cap = 64 + n * 256;
    char* json = (char*)malloc(cap);
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
            char* nj = (char*)realloc(json, cap);
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

char* media_epub_extract_text(const char* path) {
    int len = 0;
    unsigned char* data = read_file_bytes(path, &len);
    if (!data) return strdup_std("{\"error\":\"read failed\",\"text\":\"\"}");
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_reader_init_mem(&zip, data, len, 0)) {
        free(data);
        return strdup_std("{\"error\":\"not a valid epub/zip\",\"text\":\"\"}");
    }
    size_t csize = 0;
    void* cdata = mz_zip_reader_extract_file_to_heap(&zip, "META-INF/container.xml", &csize, 0);
    char* content_path = NULL;
    if (cdata) {
        char* xml = (char*)malloc(csize + 1);
        if (xml) {
            memcpy(xml, cdata, csize);
            xml[csize] = '\0';
            const char* mark = strstr(xml, "full-path=");
            if (mark) {
                mark = strchr(mark, '"');
                if (mark) {
                    mark++;
                    const char* end = strchr(mark, '"');
                    if (end) {
                        size_t plen = end - mark;
                        content_path = (char*)malloc(plen + 1);
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
    char* result = NULL;
    if (content_path) {
        size_t size = 0;
        void* cdata2 = mz_zip_reader_extract_file_to_heap(&zip, content_path, &size, 0);
        if (cdata2) {
            result = (char*)malloc(size + 64);
            if (result) {
                snprintf(result, size + 64, "{\"error\":\"\",\"text\":\"");
                const unsigned char* p = (const unsigned char*)cdata2;
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

// 往动态 JSON 缓冲追加转义后的字符串
static void json_append_esc(char** json, size_t* cap, size_t* pos, const char* s) {
    if (!s) { s = ""; }
    size_t need = strlen(s) * 2 + 4;
    if (*pos + need >= *cap) {
        *cap = (*pos + need) * 2;
        char* nj = (char*)realloc(*json, *cap);
        if (!nj) return;
        *json = nj;
    }
    (*json)[(*pos)++] = '"';
    for (const char* p = s; *p; p++) {
        if (*p == '"' || *p == '\\') { (*json)[(*pos)++] = '\\'; }
        (*json)[(*pos)++] = *p;
    }
    (*json)[(*pos)++] = '"';
    (*json)[*pos] = '\0';
}

char* media_archive_list(const char* path) {
    int len = 0;
    unsigned char* data = read_file_bytes(path, &len);
    if (!data) return strdup_std("{\"error\":\"read failed\",\"items\":[]}");
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_reader_init_mem(&zip, data, len, 0)) {
        free(data);
        return strdup_std("{\"error\":\"not a valid zip\",\"items\":[]}");
    }
    mz_uint n = mz_zip_reader_get_num_files(&zip);
    size_t cap = 64 + n * 256;
    char* json = (char*)malloc(cap);
    if (!json) { mz_zip_reader_end(&zip); free(data); return strdup_std("{\"error\":\"alloc\",\"items\":[]}"); }
    size_t pos = 0;
    pos += (size_t)snprintf(json + pos, cap - pos, "{\"error\":\"\",\"items\":[");
    for (mz_uint i = 0; i < n; i++) {
        mz_zip_archive_file_stat st;
        if (!mz_zip_reader_file_stat(&zip, i, &st)) continue;
        if (i > 0) pos += (size_t)snprintf(json + pos, cap - pos, ",");
        json_append_esc(&json, &cap, &pos, "name");
        pos += (size_t)snprintf(json + pos, cap - pos, ":");
        // 转义文件名（可能含引号/反斜杠）
        std::string name = st.m_filename;
        std::replace(name.begin(), name.end(), '\\', '/');
        json_append_esc(&json, &cap, &pos, name.c_str());
        pos += (size_t)snprintf(json + pos, cap - pos, ",\"size\":%llu,\"isDir\":%s}",
                                (unsigned long long)st.m_uncomp_size,
                                st.m_is_directory ? "true" : "false");
    }
    pos += (size_t)snprintf(json + pos, cap - pos, "]}");
    mz_zip_reader_end(&zip);
    free(data);
    return json;
}

int media_archive_extract(const char* zip_path, const char* out_dir, char* error, int error_size) {
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_reader_init_file(&zip, zip_path, 0)) {
        if (error) snprintf(error, error_size, "not a valid zip");
        return -1;
    }
    std::error_code ec;
    std::filesystem::create_directories(out_dir, ec);
    std::string out_base = out_dir;
    if (!out_base.empty() && out_base.back() != '/' && out_base.back() != '\\') out_base += '/';
    mz_uint n = mz_zip_reader_get_num_files(&zip);
    int ret = 0;
    for (mz_uint i = 0; i < n; i++) {
        mz_zip_archive_file_stat st;
        if (!mz_zip_reader_file_stat(&zip, i, &st)) continue;
        std::string name = st.m_filename;
        std::replace(name.begin(), name.end(), '\\', '/');
        // 路径穿越防护：拒绝绝对路径与 .. 段
        if (name.empty() || name[0] == '/') continue;
        if (name.find("/../") != std::string::npos ||
            name.compare(0, 3, "../") == 0 ||
            name.compare(name.size() >= 3 ? name.size() - 3 : 0, 3, "/..") == 0)
            continue;
        std::string full = out_base + name;
        if (st.m_is_directory || (!name.empty() && name.back() == '/')) {
            std::filesystem::create_directories(full, ec);
            continue;
        }
        std::filesystem::create_directories(std::filesystem::path(full).parent_path(), ec);
        size_t size = 0;
        void* buf = mz_zip_reader_extract_to_heap(&zip, i, &size, 0);
        if (!buf) {
            if (error) snprintf(error, error_size, "extract failed: %s", name.c_str());
            ret = -1;
            break;
        }
        FILE* out = fopen(full.c_str(), "wb");
        if (!out) {
            free(buf);
            if (error) snprintf(error, error_size, "cannot create: %s", full.c_str());
            ret = -1;
            break;
        }
        if (size > 0 && fwrite(buf, 1, size, out) != size) {
            if (error) snprintf(error, error_size, "write failed: %s", full.c_str());
            ret = -1;
        }
        fclose(out);
        free(buf);
        if (ret != 0) break;
    }
    mz_zip_reader_end(&zip);
    return ret;
}

int media_archive_create(const char* src_path, const char* zip_path, char* error, int error_size) {
    std::error_code ec;
    if (!std::filesystem::exists(src_path, ec)) {
        if (error) snprintf(error, error_size, "source not found");
        return -1;
    }
    std::filesystem::remove(zip_path, ec);
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_writer_init_file(&zip, zip_path, 0)) {
        if (error) snprintf(error, error_size, "cannot create zip");
        return -1;
    }
    std::string base = std::filesystem::path(src_path).filename().string();
    std::string err;
    int ret = 0;

    auto add_file_entry = [&](const std::string& rel, const std::string& abs) -> bool {
        FILE* f = fopen(abs.c_str(), "rb");
        if (!f) { err = "open " + abs; return false; }
        fseek(f, 0, SEEK_END);
        long sz = ftell(f);
        fseek(f, 0, SEEK_SET);
        void* buf = malloc(sz > 0 ? (size_t)sz : 1);
        size_t rd = buf ? fread(buf, 1, (size_t)sz, f) : 0;
        fclose(f);
        if (!buf || rd != (size_t)sz) {
            free(buf);
            err = "read " + abs;
            return false;
        }
        mz_bool ok = mz_zip_writer_add_mem(&zip, rel.c_str(), buf, (size_t)sz, MZ_DEFAULT_COMPRESSION);
        free(buf);
        if (!ok) { err = "zip add " + rel; return false; }
        return true;
    };

    if (std::filesystem::is_directory(src_path)) {
        std::string top = base + "/";
        mz_zip_writer_add_mem(&zip, top.c_str(), NULL, 0, 0);
        std::string src_prefix = std::string(src_path);
        for (auto it = std::filesystem::recursive_directory_iterator(
                 src_path, std::filesystem::directory_options::skip_permission_denied, ec);
             it != std::filesystem::recursive_directory_iterator(); it.increment(ec)) {
            if (ec) break;
            std::string rel = it->path().string();
            if (rel.compare(0, src_prefix.size(), src_prefix) == 0)
                rel = rel.substr(src_prefix.size());
            while (!rel.empty() && (rel[0] == '/' || rel[0] == '\\')) rel = rel.substr(1);
            rel = base + "/" + rel;
            std::replace(rel.begin(), rel.end(), '\\', '/');
            if (it->is_directory(ec)) {
                if (!rel.empty() && rel.back() != '/') rel += '/';
                mz_zip_writer_add_mem(&zip, rel.c_str(), NULL, 0, 0);
            } else if (it->is_regular_file(ec)) {
                if (!add_file_entry(rel, it->path().string())) { ret = -1; break; }
            }
        }
    } else {
        if (!add_file_entry(base, src_path)) ret = -1;
    }

    mz_zip_writer_finalize_archive(&zip);
    mz_zip_writer_end(&zip);
    if (ret != 0) {
        std::filesystem::remove(zip_path, ec);
        if (error && !err.empty()) snprintf(error, error_size, "%s", err.c_str());
        return -1;
    }
    return 0;
}

// 释放 JSON 字符串（不依赖 FFmpeg，始终导出）
void media_free_string(char* str) { if (str) free(str); }

// ============================================================
// 视频/音频（FFmpeg）
// ============================================================

#ifdef HAVE_FFMPEG

typedef struct {
    const unsigned char* data;
    int len;
    int pos;
} MemCtx;

// 写入回调（不提供）
// seek 回调：让 FFmpeg 知道整个缓冲在内存、可以跳转
static int64_t mem_seek(void* opaque, int64_t offset, int whence) {
    MemCtx* ctx = (MemCtx*)opaque;
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

static int mem_read_packet(void* opaque, uint8_t* buf, int buf_size) {
    MemCtx* ctx = (MemCtx*)opaque;
    int avail = ctx->len - ctx->pos;
    if (avail <= 0) return AVERROR_EOF;
    int n = avail < buf_size ? avail : buf_size;
    memcpy(buf, ctx->data + ctx->pos, n);
    ctx->pos += n;
    return n;
}

typedef struct {
    MemCtx mem;
    AVFormatContext* fmt_ctx;
    AVIOContext* avio;
    AVCodecContext* codec_ctx;
    SwsContext* sws_ctx;
    int video_stream;
    int audio_stream;
    double duration;
    double fps;
} MediaCtx;

static MediaCtx* media_open_mem(const unsigned char* data, int len) {
    if (!data || len <= 0) return NULL;
    MediaCtx* m = (MediaCtx*)calloc(1, sizeof(MediaCtx));
    if (!m) return NULL;
    m->mem.data = data;
    m->mem.len = len;
    m->mem.pos = 0;
    m->video_stream = -1;
    m->audio_stream = -1;
    // avio buffer 要足够大才能容纳 MP4 moov atom、ts 头等探测块
    const int avio_buf_size = 256 * 1024; // 256KB
    m->avio = avio_alloc_context((unsigned char*)av_malloc(avio_buf_size), avio_buf_size, 0, &m->mem,
                                 mem_read_packet, NULL, mem_seek);
    if (!m->avio) { free(m); return NULL; }
    // 标记为可跳转，让 FFmpeg 正确处理 EOF/size 信息
    m->avio->seekable = AVIO_SEEKABLE_NORMAL;
    m->avio->maxsize = m->mem.len;
    m->fmt_ctx = avformat_alloc_context();
    m->fmt_ctx->pb = m->avio;
    m->fmt_ctx->flags |= AVFMT_FLAG_CUSTOM_IO;
    // 增大探测参数，确保 H.264/HEVC 等流的 pixel format 被完整探测
    m->fmt_ctx->probesize = 50 * 1024 * 1024;         // 50MB
    m->fmt_ctx->max_analyze_duration = 30 * AV_TIME_BASE; // 30s
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
        AVStream* st = m->fmt_ctx->streams[i];
        if (st->codecpar->codec_type == AVMEDIA_TYPE_VIDEO && m->video_stream < 0)
            m->video_stream = i;
        else if (st->codecpar->codec_type == AVMEDIA_TYPE_AUDIO && m->audio_stream < 0)
            m->audio_stream = i;
    }
    m->duration = m->fmt_ctx->duration > 0 ? m->fmt_ctx->duration / (double)AV_TIME_BASE : 0;
    return m;
}

void* media_video_open(const unsigned char* data, int len) {
    MediaCtx* m = media_open_mem(data, len);
    if (!m || m->video_stream < 0) {
        if (m) media_video_close(m);
        return NULL;
    }
    AVStream* st = m->fmt_ctx->streams[m->video_stream];
    const AVCodec* codec = avcodec_find_decoder(st->codecpar->codec_id);
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
    // 像素格式安全检查：如果探测失败（NONE），默认 YUV420P
    enum AVPixelFormat src_fmt = m->codec_ctx->pix_fmt;
    if (src_fmt == AV_PIX_FMT_NONE) {
        src_fmt = AV_PIX_FMT_YUV420P;
    }
    m->sws_ctx = sws_getContext(m->codec_ctx->width, m->codec_ctx->height,
                                src_fmt,
                                m->codec_ctx->width, m->codec_ctx->height,
                                AV_PIX_FMT_RGBA, SWS_BILINEAR, NULL, NULL, NULL);
    if (!m->sws_ctx) { media_video_close(m); return NULL; }
    double fps = st->avg_frame_rate.num && st->avg_frame_rate.den
                 ? av_q2d(st->avg_frame_rate) : 25.0;
    m->fps = fps > 0 ? fps : 25.0;
    return m;
}

int media_video_next_frame(void* handle, char** out_json) {
    MediaCtx* m = (MediaCtx*)handle;
    if (!m || !m->codec_ctx || !out_json) return -1;
    *out_json = NULL;

    AVFrame* frame_out = av_frame_alloc();
    if (!frame_out) return -1;

    int decode_ret = -1; // 最终结果
    AVPacket pkt;
    memset(&pkt, 0, sizeof(pkt)); // 兼容新版 FFmpeg

    // 循环读包直到拿到一帧 OR 真 EOF
    while (av_read_frame(m->fmt_ctx, &pkt) >= 0) {
        // 跳过 size=0 的包（可能是 flush packet 或其他特殊情况）
        if (pkt.size <= 0) {
            av_packet_unref(&pkt);
            continue;
        }
        if (pkt.stream_index == m->video_stream) {
            int send_ret = avcodec_send_packet(m->codec_ctx, &pkt);
            av_packet_unref(&pkt);
            if (send_ret < 0 && send_ret != AVERROR(EAGAIN) && send_ret != AVERROR_EOF) {
                // 真正的发送错误，直接跳到 cleanup（不能 break，否则会被下面的 decode_ret = 0 覆盖）
                decode_ret = -1;
                goto cleanup;
            }

            // 循环接收已解码帧（一个包可能产生多帧）
            int recv_ret = avcodec_receive_frame(m->codec_ctx, frame_out);
            while (recv_ret >= 0) {
                // 成功拿到一帧
                int w = m->codec_ctx->width, h = m->codec_ctx->height;
                // 检查 frame 的 plane 指针是否有效（如 B 帧无 plane 的特例）
                if (!frame_out->data[0] || w <= 0 || h <= 0) {
                    recv_ret = avcodec_receive_frame(m->codec_ctx, frame_out);
                    continue;
                }
                int buf_size = av_image_get_buffer_size(AV_PIX_FMT_RGBA, w, h, 1);
                if (buf_size <= 0) { recv_ret = avcodec_receive_frame(m->codec_ctx, frame_out); continue; }

                unsigned char* rgba = (unsigned char*)av_malloc(buf_size);
                if (!rgba) {
                    av_frame_free(&frame_out);
                    decode_ret = -1;
                    goto cleanup;
                }
                uint8_t* dst_data[4] = { rgba, NULL, NULL, NULL };
                int dst_linesize[4] = { w * 4, 0, 0, 0 };
                int scaled = sws_scale(m->sws_ctx, frame_out->data, frame_out->linesize,
                              0, h, dst_data, dst_linesize);
                if (scaled <= 0) {
                    av_free(rgba);
                    // 跳过这一帧，继续收下一帧
                    recv_ret = avcodec_receive_frame(m->codec_ctx, frame_out);
                    continue;
                }

                // 使用 best_effort_timestamp（FFmpeg 会以 DTS 重设 PTS 确保单调递增）
                // 而不是 frame_out->pts（解码顺序，DTS，可能跳变）
                int64_t pts = frame_out->best_effort_timestamp;
                if (pts == AV_NOPTS_VALUE) pts = frame_out->pts;
                double ts = pts != AV_NOPTS_VALUE
                            ? pts * av_q2d(m->codec_ctx->time_base) : 0.0;
                int b64_len = 0;
                char* b64 = base64_encode(rgba, buf_size, &b64_len);
                av_free(rgba);
                if (!b64) {
                    decode_ret = -1;
                    goto cleanup;
                }
                size_t out_len = (size_t)b64_len + 128;
                char* out = (char*)malloc(out_len);
                if (!out) {
                    free(b64);
                    decode_ret = -1;
                    goto cleanup;
                }
                snprintf(out, out_len, "{\"error\":\"\",\"base64\":\"%s\",\"width\":%d,\"height\":%d,\"timestamp\":%f}",
                         b64, w, h, ts);
                free(b64);
                *out_json = out;
                decode_ret = 1; // 成功
                goto cleanup;
            }

            if (recv_ret == AVERROR_EOF) {
                // 解码器已涳，不应发生，但安全退出
                decode_ret = 0;
                goto cleanup;
            }
            // recv_ret == AVERROR(EAGAIN) 表示需要更多包，继续外层循环读下一个包
        } else {
            av_packet_unref(&pkt);
        }
    }

    // av_read_frame 返回 < 0 = AVERROR_EOF = 真 EOF
    decode_ret = 0;

cleanup:
    av_frame_free(&frame_out);
    return decode_ret;
}

int media_video_seek(void* handle, double timestamp) {
    MediaCtx* m = (MediaCtx*)handle;
    if (!m || !m->fmt_ctx) return 0;
    int64_t ts = (int64_t)(timestamp * AV_TIME_BASE);
    int ret = avformat_seek_file(m->fmt_ctx, -1, INT64_MIN, ts, INT64_MAX, 0);
    if (ret >= 0 && m->codec_ctx) {
        avcodec_flush_buffers(m->codec_ctx);
        return 1;
    }
    return 0;
}

char* media_video_get_info(void* handle) {
    MediaCtx* m = (MediaCtx*)handle;
    if (!m || !m->codec_ctx) return strdup_std("{\"error\":\"invalid handle\",\"width\":0,\"height\":0,\"duration\":0,\"fps\":0}");
    char* out = (char*)malloc(128);
    snprintf(out, 128, "{\"error\":\"\",\"width\":%d,\"height\":%d,\"duration\":%f,\"fps\":%f}",
             m->codec_ctx->width, m->codec_ctx->height, m->duration, m->fps);
    return out;
}

void media_video_close(void* handle) {
    MediaCtx* m = (MediaCtx*)handle;
    if (!m) return;
    if (m->sws_ctx) sws_freeContext(m->sws_ctx);
    if (m->codec_ctx) avcodec_free_context(&m->codec_ctx);
    // avformat_close_input 会调 av_freep(&s->pb) 释放 AVIOContext 结构体，
    // 但不会释放 avio->buffer。为避免 double-free，必须先解除 fmt_ctx 对 avio 的拥有关系。
    if (m->fmt_ctx) {
        m->fmt_ctx->pb = NULL;       // 断开绑定
        avformat_close_input(&m->fmt_ctx);  // 只释放 fmt_ctx 本身，不释放 avio
    }
    if (m->avio) {
        // avio_context_free 内部会 free avio->buffer
        avio_context_free(&m->avio);
    }
    free(m);
}

// 动态字节缓冲（完整 PCM 解码累积用）
typedef struct {
    unsigned char* data;
    size_t len;
    size_t cap;
} ByteBuf;

static int bytebuf_append(ByteBuf* b, const void* src, size_t add) {
    if (b->len + add > b->cap) {
        size_t ncap = b->cap ? b->cap * 2 : 65536;
        while (ncap < b->len + add) ncap *= 2;
        unsigned char* nd = (unsigned char*)realloc(b->data, ncap);
        if (!nd) return -1;
        b->data = nd;
        b->cap = ncap;
    }
    memcpy(b->data + b->len, src, add);
    b->len += add;
    return 0;
}

// 完整解码音频流为 S16 交错 PCM
char* media_decode_audio(const unsigned char* data, int len) {
    MediaCtx* m = media_open_mem(data, len);
    if (!m || m->audio_stream < 0) {
        if (m) media_video_close(m);
        return strdup_std("{\"error\":\"no audio stream\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}");
    }
    AVStream* st = m->fmt_ctx->streams[m->audio_stream];
    const AVCodec* codec = avcodec_find_decoder(st->codecpar->codec_id);
    if (!codec) { media_video_close(m); return strdup_std("{\"error\":\"audio codec not found\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}"); }
    AVCodecContext* actx = avcodec_alloc_context3(codec);
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
    int out_ch = actx->channels > 0 ? actx->channels : 2;
    int64_t in_layout = actx->channel_layout;
    if (!in_layout) in_layout = av_get_default_channel_layout(actx->channels > 0 ? actx->channels : 2);

    // swr：任意输入格式 → S16 交错
    SwrContext* swr = swr_alloc();
    if (!swr) { avcodec_free_context(&actx); media_video_close(m); return strdup_std("{\"error\":\"swr alloc\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}"); }
    av_opt_set_int(swr, "in_channel_layout", in_layout, 0);
    av_opt_set_int(swr, "in_sample_rate", out_rate, 0);
    av_opt_set_sample_fmt(swr, "in_sample_fmt", actx->sample_fmt, 0);
    av_opt_set_int(swr, "out_channel_layout", in_layout, 0);
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
    AVFrame* frm = av_frame_alloc();
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
                int ch = frm->channels > 0 ? frm->channels : out_ch;
                int out_samples = swr_get_out_samples(swr, frm->nb_samples);
                if (out_samples <= 0) continue;
                int obytes = av_samples_get_buffer_size(NULL, ch, out_samples, AV_SAMPLE_FMT_S16, 1);
                if (obytes <= 0) continue;
                unsigned char* obuf = (unsigned char*)malloc((size_t)obytes);
                if (!obuf) break;
                uint8_t* obufs[1] = { obuf };
                int got = swr_convert(swr, obufs, out_samples,
                                      (const uint8_t**)frm->extended_data, frm->nb_samples);
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
    // 冲刷解码器尾部帧
    avcodec_send_packet(actx, NULL);
    while (avcodec_receive_frame(actx, frm) >= 0) {
        int ch = frm->channels > 0 ? frm->channels : out_ch;
        int out_samples = swr_get_out_samples(swr, frm->nb_samples);
        if (out_samples <= 0) continue;
        int obytes = av_samples_get_buffer_size(NULL, ch, out_samples, AV_SAMPLE_FMT_S16, 1);
        if (obytes <= 0) continue;
        unsigned char* obuf = (unsigned char*)malloc((size_t)obytes);
        if (!obuf) break;
        uint8_t* obufs[1] = { obuf };
        int got = swr_convert(swr, obufs, out_samples,
                              (const uint8_t**)frm->extended_data, frm->nb_samples);
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
    char* b64 = base64_encode(pcm.data, (int)pcm.len, &b64_len);
    int pcm_len = (int)pcm.len;
    free(pcm.data);
    if (!b64) return strdup_std("{\"error\":\"alloc\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}");
    size_t out_len = (size_t)b64_len + 128;
    char* out = (char*)malloc(out_len);
    if (!out) { free(b64); return strdup_std("{\"error\":\"alloc\",\"base64\":\"\",\"sample_rate\":0,\"channels\":0,\"bits\":0,\"length\":0}"); }
    snprintf(out, out_len,
             "{\"error\":\"\",\"base64\":\"%s\",\"sample_rate\":%d,\"channels\":%d,\"bits\":16,\"length\":%d}",
             b64, out_rate, out_ch, pcm_len);
    free(b64);
    return out;
}

#endif // HAVE_FFMPEG

