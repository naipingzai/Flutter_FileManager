/*
 * media - Apple 平台音频输出（AudioQueue）— 平台层实现
 * 适用于 iOS / macOS，播放 media 库解码出的 S16 交错 PCM 数据
 */

#include <AudioToolbox/AudioToolbox.h>
#include <dispatch/dispatch.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "media.h"

#define AQ_BUFFER_COUNT 8
#define AQ_BUFFER_SIZE 65536

typedef struct {
    AudioQueueRef queue;
    int channels;
    int sample_rate;
    AudioQueueBufferRef buffers[AQ_BUFFER_COUNT];
    int buf_index;
    dispatch_semaphore_t free_sem; // 空闲 buffer 信号量（入队消耗、播放完归还）
    int started;
} AQOutput;

// 播放完成的 buffer 由系统归还
static void aq_buffer_done(void* user_data, AudioQueueRef queue, AudioQueueBufferRef buf) {
    (void)queue;
    (void)buf;
    AQOutput* a = (AQOutput*)user_data;
    dispatch_semaphore_signal(a->free_sem);
}

extern "C" void* media_audio_output_open(int sample_rate, int channels, int bits) {
    (void)bits;
    if (sample_rate <= 0 || channels <= 0 || channels > 8) return NULL;
    AQOutput* a = (AQOutput*)calloc(1, sizeof(AQOutput));
    if (!a) return NULL;
    a->channels = channels;
    a->sample_rate = sample_rate;
    a->free_sem = dispatch_semaphore_create(AQ_BUFFER_COUNT);
    if (!a->free_sem) { free(a); return NULL; }

    AudioStreamBasicDescription fmt;
    memset(&fmt, 0, sizeof(fmt));
    fmt.mSampleRate = sample_rate;
    fmt.mFormatID = kAudioFormatLinearPCM;
    fmt.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    fmt.mBitsPerChannel = 16;
    fmt.mChannelsPerFrame = channels;
    fmt.mFramesPerPacket = 1;
    fmt.mBytesPerFrame = channels * 2;
    fmt.mBytesPerPacket = channels * 2;

    OSStatus st = AudioQueueNewOutput(&fmt, aq_buffer_done, a, NULL, NULL, 0, &a->queue);
    if (st != noErr) {
        dispatch_release(a->free_sem);
        free(a);
        return NULL;
    }
    for (int i = 0; i < AQ_BUFFER_COUNT; i++) {
        if (AudioQueueAllocateBuffer(a->queue, AQ_BUFFER_SIZE, &a->buffers[i]) != noErr) {
            AudioQueueDispose(a->queue, true);
            dispatch_release(a->free_sem);
            free(a);
            return NULL;
        }
    }
    AudioQueueStart(a->queue, NULL);
    a->started = 1;
    return a;
}

extern "C" int media_audio_output_write(void* handle, const unsigned char* pcm, int len) {
    AQOutput* a = (AQOutput*)handle;
    if (!a || !a->queue || len <= 0) return -1;
    if (!a->started) {
        AudioQueueStart(a->queue, NULL);
        a->started = 1;
    }
    int total = 0;
    while (len > 0) {
        if (dispatch_semaphore_wait(a->free_sem, DISPATCH_TIME_FOREVER) != 0) return -1;
        AudioQueueBufferRef buf = a->buffers[a->buf_index % AQ_BUFFER_COUNT];
        a->buf_index++;
        size_t chunk = (size_t)len > AQ_BUFFER_SIZE ? AQ_BUFFER_SIZE : (size_t)len;
        memcpy(buf->mAudioData, pcm + total, chunk);
        buf->mAudioDataByteSize = (UInt32)chunk;
        if (AudioQueueEnqueueBuffer(a->queue, buf, 0, NULL) != noErr) {
            dispatch_semaphore_signal(a->free_sem);
            return -1;
        }
        total += (int)chunk;
        len -= (int)chunk;
    }
    return total;
}

extern "C" void media_audio_output_stop(void* handle) {
    AQOutput* a = (AQOutput*)handle;
    if (!a || !a->queue) return;
    AudioQueueStop(a->queue, true);
    a->started = 0;
}

extern "C" void media_audio_output_close(void* handle) {
    AQOutput* a = (AQOutput*)handle;
    if (!a) return;
    if (a->queue) {
        AudioQueueStop(a->queue, true);
        AudioQueueDispose(a->queue, true);
    }
    if (a->free_sem) dispatch_release(a->free_sem);
    free(a);
}
