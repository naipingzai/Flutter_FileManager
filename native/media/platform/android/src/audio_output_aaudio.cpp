/*
 * media - Android 音频输出（AAudio）— 平台层实现
 * 播放 media 库解码出的 S16 交错 PCM 数据
 */

#include <aaudio/AAudio.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "media.h"

typedef struct {
    AAudioStream* stream;
    int32_t channels;
    int32_t sample_rate;
} AAudioOutput;

extern "C" void* media_audio_output_open(int sample_rate, int channels, int bits) {
    (void)bits;
    if (sample_rate <= 0 || channels <= 0 || channels > 8) return NULL;
    AAudioOutput* a = (AAudioOutput*)calloc(1, sizeof(AAudioOutput));
    if (!a) return NULL;
    a->channels = channels;
    a->sample_rate = sample_rate;

    AAudioStreamBuilder* builder = NULL;
    if (AAudio_createStreamBuilder(&builder) != AAUDIO_OK) { free(a); return NULL; }
    AAudioStreamBuilder_setFormat(builder, AAUDIO_FORMAT_PCM_I16);
    AAudioStreamBuilder_setSampleRate(builder, sample_rate);
    AAudioStreamBuilder_setChannelCount(builder, channels);
    AAudioStreamBuilder_setPerformanceMode(builder, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
    aaudio_result_t res = AAudioStreamBuilder_openStream(builder, &a->stream);
    AAudioStreamBuilder_delete(builder);
    if (res != AAUDIO_OK || !a->stream) {
        free(a);
        return NULL;
    }
    return a;
}

extern "C" int media_audio_output_write(void* handle, const unsigned char* pcm, int len) {
    AAudioOutput* a = (AAudioOutput*)handle;
    if (!a || !a->stream || len <= 0) return -1;
    const int32_t frame_size = a->channels * 2; // S16 交错
    const int32_t frames = len / frame_size;
    if (frames <= 0) return 0;
    int32_t written = 0;
    while (written < frames) {
        int32_t w = AAudioStream_write(a->stream, pcm + (size_t)written * frame_size,
                                       frames - written, 5000000000LL); // 5s 超时
        if (w <= 0) return -1;
        written += w;
    }
    return written * frame_size;
}

extern "C" void media_audio_output_stop(void* handle) {
    AAudioOutput* a = (AAudioOutput*)handle;
    if (!a || !a->stream) return;
    AAudioStream_requestStop(a->stream);
}

extern "C" void media_audio_output_close(void* handle) {
    AAudioOutput* a = (AAudioOutput*)handle;
    if (!a) return;
    if (a->stream) {
        AAudioStream_requestStop(a->stream);
        AAudioStream_close(a->stream);
    }
    free(a);
}
