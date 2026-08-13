/*
 * media - Linux 音频输出（ALSA）— 平台层实现
 * 播放 media 库解码出的 S16 交错 PCM 数据
 */

#include <alsa/asoundlib.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "media.h"

typedef struct {
    snd_pcm_t* pcm;
    unsigned int rate;
    int channels;
    snd_pcm_uframes_t period_size;
} AlsaOutput;

extern "C" void* media_audio_output_open(int sample_rate, int channels, int bits) {
    (void)bits;
    if (sample_rate <= 0 || channels <= 0 || channels > 8) return NULL;
    AlsaOutput* a = (AlsaOutput*)calloc(1, sizeof(AlsaOutput));
    if (!a) return NULL;
    a->rate = (unsigned int)sample_rate;
    a->channels = channels;

    int err = snd_pcm_open(&a->pcm, "default", SND_PCM_STREAM_PLAYBACK, 0);
    if (err < 0) { free(a); return NULL; }

    snd_pcm_hw_params_t* hw;
    snd_pcm_hw_params_alloca(&hw);
    snd_pcm_hw_params_any(a->pcm, hw);
    snd_pcm_hw_params_set_access(a->pcm, hw, SND_PCM_ACCESS_RW_INTERLEAVED);
    snd_pcm_hw_params_set_format(a->pcm, hw, SND_PCM_FORMAT_S16_LE);
    snd_pcm_hw_params_set_channels(a->pcm, hw, (unsigned int)channels);
    unsigned int rate = (unsigned int)sample_rate;
    int dir = 0;
    snd_pcm_hw_params_set_rate_near(a->pcm, hw, &rate, &dir);
    snd_pcm_uframes_t period = (snd_pcm_uframes_t)(rate / 10); // 100ms
    snd_pcm_hw_params_set_period_size_near(a->pcm, hw, &period, &dir);
    snd_pcm_uframes_t buffer = period * 4;
    snd_pcm_hw_params_set_buffer_size_near(a->pcm, hw, &buffer);
    if (snd_pcm_hw_params(a->pcm, hw) < 0) {
        snd_pcm_close(a->pcm);
        free(a);
        return NULL;
    }
    a->period_size = period;
    snd_pcm_prepare(a->pcm);
    return a;
}

extern "C" int media_audio_output_write(void* handle, const unsigned char* pcm, int len) {
    AlsaOutput* a = (AlsaOutput*)handle;
    if (!a || !a->pcm || len <= 0) return -1;
    const int frame_size = a->channels * 2; // S16_LE
    const int frames = len / frame_size;
    if (frames <= 0) return 0;
    int written = 0;
    const char* buf = (const char*)pcm;
    while (written < frames) {
        int w = snd_pcm_writei(a->pcm, buf + (size_t)written * frame_size, (snd_pcm_uframes_t)(frames - written));
        if (w < 0) {
            w = snd_pcm_recover(a->pcm, w, 1);
            if (w < 0) return -1;
            continue;
        }
        written += w;
    }
    return written * frame_size;
}

extern "C" void media_audio_output_stop(void* handle) {
    AlsaOutput* a = (AlsaOutput*)handle;
    if (!a || !a->pcm) return;
    snd_pcm_drop(a->pcm);
    snd_pcm_prepare(a->pcm);
}

extern "C" void media_audio_output_close(void* handle) {
    AlsaOutput* a = (AlsaOutput*)handle;
    if (!a) return;
    if (a->pcm) {
        snd_pcm_drain(a->pcm);
        snd_pcm_close(a->pcm);
    }
    free(a);
}
