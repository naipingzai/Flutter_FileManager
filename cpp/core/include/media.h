/*
 * media.h - media 模块对 Dart 的统一 C API
 *
 * 提供：
 *   - 图片解码（stb_image）
 *   - 电子书 EPUB（miniz）
 *   - 视频/音频解码（FFmpeg）
 *   - 音频输出（ALSA/AAudio/AudioQueue/WASAPI）
 *   - 压缩包工具（miniz）
 *
 * 所有平台差异由 media 模块 core + platform/<os>/ 处理。
 * Dart FFI 永远只调用同一套接口。
 */

#ifndef MEDIA_MEDIA_H
#define MEDIA_MEDIA_H

#include <stdint.h>
#include <stddef.h>

#ifdef _WIN32
#define MEDIA_API __declspec(dllexport)
#else
#define MEDIA_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// 图片解码（stb_image）
// ============================================================

// 解码图片文件为 RGBA。返回 JSON：{"error":"","base64":"...","width":n,"height":n}
MEDIA_API
char *media_decode_image_file(const char *path);

// 解码图片缓冲区为 RGBA。返回 JSON：{"error":"","base64":"...","width":n,"height":n}
MEDIA_API
char *media_decode_image_buffer(const unsigned char *data, int len);

// 生成图片缩略图（盒式采样缩放到 max_size 内）。返回 JSON：{"error":"","base64":"...","width":n,"height":n}
MEDIA_API
char *media_make_thumbnail(const char *path, int max_size);

// 生成视频封面（解码第一帧并缩略）。返回同上。
MEDIA_API
char *media_make_video_thumbnail(const char *path, int max_size);

// ============================================================
// 电子书 EPUB（miniz）
// ============================================================

// 提取 EPUB 正文文本。返回 JSON：{"error":"","text":"..."}
MEDIA_API
char *media_epub_extract_text(const char *path);

// 列出 EPUB 内部文件。返回 JSON：{"error":"","files":[{"name":"..."}]}
MEDIA_API
char *media_epub_list_files(const char *path);

// ============================================================
// 视频/音频（FFmpeg）
// ============================================================

// 打开视频流（内存）。返回句柄，失败返回 nullptr。
MEDIA_API
void *media_video_open(const unsigned char *data, int len);

// 读取下一帧为紧凑 RGBA（w*h*4），直接写入调用方缓冲区（无 base64/JSON，供高频渲染）。
// out_cap 需 >= w*h*4。返回 1=有帧, 0=EOF, -1=错误, -2=缓冲区过小。
MEDIA_API
int media_video_next_frame_rgba(void *handle, unsigned char *out, int out_cap,
                                int *out_w, int *out_h, double *out_ts);

// 跳转到指定时间（秒）。返回 1=成功, 0=失败。
MEDIA_API
int media_video_seek(void *handle, double timestamp);

// 获取视频信息。返回 JSON：{"error":"","width":n,"height":n,"duration":f,"fps":f}
MEDIA_API
char *media_video_get_info(void *handle);

// 关闭视频流
MEDIA_API
void media_video_close(void *handle);

// 解码音频为 PCM（完整解码，S16 交错）。返回 JSON：
// {"error":"","base64":"...","sample_rate":n,"channels":n,"bits":n,"length":n}
MEDIA_API
char *media_decode_audio(const unsigned char *data, int len);

// ============================================================
// 音频输出（平台层实现，代码层仅声明接口）
// 播放 media 库解码出的 PCM 数据（S16 交错，little-endian）
// ============================================================

// 打开音频输出设备。返回句柄，失败返回 nullptr。
MEDIA_API
void *media_audio_output_open(int sample_rate, int channels, int bits);

// 播放 PCM 数据（阻塞直到播放完成）。返回实际写入字节数，失败返回 -1。
MEDIA_API
int media_audio_output_write(void *handle, const unsigned char *pcm, int len);

// 停止播放并清空未播放的缓冲。
MEDIA_API
void media_audio_output_stop(void *handle);

// 关闭音频输出设备。
MEDIA_API
void media_audio_output_close(void *handle);

// ============================================================
// 压缩包工具（miniz，全平台、无系统依赖）
// ============================================================

// 列出压缩包内容。返回 JSON：{"error":"","items":[{"name":"...","size":n,"isDir":[]}]}
MEDIA_API
char *media_archive_list(const char *path);

// 解压压缩包到指定目录（含路径穿越防护）。返回 int (0=成功)
MEDIA_API
int media_archive_extract(const char *zip_path, const char *out_dir, char *error, int error_size);

// 将文件或目录（递归）压缩为 zip。返回 int (0=成功)
MEDIA_API
int media_archive_create(const char *src_path, const char *zip_path, char *error, int error_size);

// 释放 JSON 字符串
MEDIA_API
void media_free_string(char *str);

#ifdef __cplusplus
}
#endif

#endif // MEDIA_MEDIA_H
