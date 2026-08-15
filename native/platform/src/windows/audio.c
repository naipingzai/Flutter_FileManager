/*
 * media - Windows 音频输出（WASAPI，共享模式）— 平台层实现
 * 播放 media 库解码出的 S16 交错 PCM 数据
 */

#ifndef _WIN32
#error "WASAPI audio output is Windows-only"
#endif

#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "media.h"

typedef struct {
    IAudioClient* client;
    IAudioRenderClient* render;
    HANDLE event;
    UINT32 buffer_frames;
    UINT32 frame_size;
    int running;
} WasapiOutput;

static HRESULT wasapi_initialize(WasapiOutput* w, int sample_rate, int channels) {
    HRESULT hr;
    IMMDeviceEnumerator* enumerator = NULL;
    IMMDevice* device = NULL;

    hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) return hr;

    hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL,
                          IID_PPV_ARGS(&enumerator));
    if (FAILED(hr)) return hr;

    hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
    enumerator->Release();
    if (FAILED(hr)) return hr;

    hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, NULL, (void**)&w->client);
    device->Release();
    if (FAILED(hr)) return hr;

    WAVEFORMATEX fmt;
    memset(&fmt, 0, sizeof(fmt));
    fmt.wFormatTag = WAVE_FORMAT_PCM;
    fmt.nChannels = (WORD)channels;
    fmt.nSamplesPerSec = (DWORD)sample_rate;
    fmt.wBitsPerSample = 16;
    fmt.nBlockAlign = (WORD)(channels * 2);
    fmt.nAvgBytesPerSec = sample_rate * channels * 2;

    w->frame_size = fmt.nBlockAlign;
    REFERENCE_TIME duration = 5000000; // 500ms
    hr = w->client->Initialize(AUDCLNT_SHAREMODE_SHARED,
                               AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
                               duration, 0, &fmt, NULL);
    if (FAILED(hr)) return hr;

    hr = w->client->GetBufferSize(&w->buffer_frames);
    if (FAILED(hr)) return hr;

    w->event = CreateEventW(NULL, FALSE, FALSE, NULL);
    if (!w->event) return E_FAIL;
    hr = w->client->SetEventHandle(w->event);
    if (FAILED(hr)) return hr;

    hr = w->client->GetService(IID_PPV_ARGS(&w->render));
    if (FAILED(hr)) return hr;

    hr = w->client->Start();
    if (FAILED(hr)) return hr;
    w->running = 1;
    return S_OK;
}

void* media_audio_output_open(int sample_rate, int channels, int bits) {
    (void)bits;
    if (sample_rate <= 0 || channels <= 0 || channels > 8) return NULL;
    WasapiOutput* w = (WasapiOutput*)calloc(1, sizeof(WasapiOutput));
    if (!w) return NULL;
    if (FAILED(wasapi_initialize(w, sample_rate, channels))) {
        media_audio_output_close(w);
        return NULL;
    }
    return w;
}

int media_audio_output_write(void* handle, const unsigned char* pcm, int len) {
    WasapiOutput* w = (WasapiOutput*)handle;
    if (!w || !w->client || len <= 0) return -1;
    UINT32 frames_total = (UINT32)(len / w->frame_size);
    UINT32 written = 0;
    const BYTE* src = pcm;

    while (written < frames_total) {
        UINT32 pad = 0;
        if (FAILED(w->client->GetCurrentPadding(&pad))) return -1;
        UINT32 avail = w->buffer_frames - pad;
        if (avail == 0) {
            if (WaitForSingleObject(w->event, 5000) != WAIT_OBJECT_0) return -1;
            continue;
        }
        UINT32 todo = frames_total - written;
        if (todo > avail) todo = avail;
        BYTE* data = NULL;
        if (FAILED(w->render->GetBuffer(todo, &data))) return -1;
        memcpy(data, src, (size_t)todo * w->frame_size);
        if (FAILED(w->render->ReleaseBuffer(todo, 0))) return -1;
        src += (size_t)todo * w->frame_size;
        written += todo;
    }
    return (int)(written * w->frame_size);
}

void media_audio_output_stop(void* handle) {
    WasapiOutput* w = (WasapiOutput*)handle;
    if (!w || !w->client) return;
    if (w->running) {
        w->client->Stop();
        w->running = 0;
    }
}

void media_audio_output_close(void* handle) {
    WasapiOutput* w = (WasapiOutput*)handle;
    if (!w) return;
    if (w->client) {
        if (w->running) w->client->Stop();
        w->client->Release();
    }
    if (w->render) w->render->Release();
    if (w->event) CloseHandle(w->event);
    free(w);
}
