#include "CMpv.h"
#include "vendor/client.h"
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

struct muses_mpv {
    void *library;
    mpv_handle *handle;
    unsigned long (*client_api_version)(void);
    mpv_handle *(*create)(void);
    int (*initialize)(mpv_handle *);
    void (*terminate_destroy)(mpv_handle *);
    int (*set_option_string)(mpv_handle *, const char *, const char *);
    int (*set_property_string)(mpv_handle *, const char *, const char *);
    int (*set_property)(mpv_handle *, const char *, mpv_format, void *);
    int (*command)(mpv_handle *, const char **);
    int (*observe_property)(mpv_handle *, uint64_t, const char *, mpv_format);
    mpv_event *(*wait_event)(mpv_handle *, double);
};

void muses_mpv_close(muses_mpv *c) {
    if (!c) return;
    if (c->handle && c->terminate_destroy) c->terminate_destroy(c->handle);
    if (c->library) dlclose(c->library);
    free(c);
}

#define SYMBOL(name) do { *(void **)(&c->name) = dlsym(c->library, "mpv_" #name); if (!c->name) goto fail; } while (0)
// Disabling a compile-time-absent script feature is already satisfied.
#define DISABLE(name) do { int r = c->set_option_string(c->handle, name, "no"); if (r < 0 && r != MPV_ERROR_OPTION_NOT_FOUND) { *error = -1004; goto fail; } } while (0)
#define OPTION(name, value) do { if (c->set_option_string(c->handle, name, value) < 0) { *error = -1004; goto fail; } } while (0)
muses_mpv *muses_mpv_open(const char *path, int *error) {
    *error = -1001;
    if (!path || path[0] != '/') return NULL;
    muses_mpv *c = calloc(1, sizeof(*c));
    if (!c) return NULL;
    c->library = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!c->library) goto fail;
    *error = -1002;
    SYMBOL(client_api_version); SYMBOL(create); SYMBOL(initialize); SYMBOL(terminate_destroy);
    SYMBOL(set_option_string); SYMBOL(set_property_string); SYMBOL(set_property);
    SYMBOL(command); SYMBOL(observe_property); SYMBOL(wait_event);
    // Client header v0.41.0 uses API 2.5. Reject incompatible major and older minor.
    unsigned long version = c->client_api_version();
    *error = -1003;
    if ((version >> 16) != (MPV_CLIENT_API_VERSION >> 16) || version < MPV_CLIENT_API_VERSION) goto fail;
    c->handle = c->create();
    if (!c->handle) goto fail;
    // Never inherit a developer's mpv config, scripts, input bindings or yt-dlp hook.
    OPTION("config", "no"); DISABLE("load-scripts"); DISABLE("ytdl");
    OPTION("terminal", "no"); OPTION("msg-level", "all=no");
    OPTION("input-default-bindings", "no"); OPTION("input-vo-keyboard", "no");
    DISABLE("osc"); OPTION("media-controls", "no"); OPTION("vid", "no"); OPTION("sid", "no");
    OPTION("idle", "yes"); OPTION("pause", "yes"); OPTION("keep-open", "no");
    OPTION("loop-file", "no"); OPTION("loop-playlist", "no");
    OPTION("cookies", "no"); OPTION("tls-verify", "yes");
    OPTION("save-position-on-quit", "no"); OPTION("resume-playback", "no");
    OPTION("cache", "yes"); OPTION("cache-on-disk", "no");
    OPTION("demuxer-max-bytes", "16777216"); OPTION("demuxer-max-back-bytes", "4194304");
    OPTION("network-timeout", "20"); OPTION("audio-fallback-to-null", "no");
    *error = c->initialize(c->handle);
    if (*error < 0) goto fail;
    const char *names[] = {"time-pos", "duration", "pause", "paused-for-cache", "seeking",
                          "cache-buffering-state", "audio-codec-name", "audio-params/samplerate"};
    mpv_format formats[] = {MPV_FORMAT_DOUBLE, MPV_FORMAT_DOUBLE, MPV_FORMAT_FLAG,
        MPV_FORMAT_FLAG, MPV_FORMAT_FLAG, MPV_FORMAT_INT64, MPV_FORMAT_STRING, MPV_FORMAT_INT64};
    for (uint64_t i = 0; i < 8; ++i) {
        *error = c->observe_property(c->handle, i + 1, names[i], formats[i]);
        if (*error < 0) goto fail;
    }
    *error = 0;
    return c;
fail:
    muses_mpv_close(c);
    return NULL;
}
unsigned long muses_mpv_version(muses_mpv *c) { return c->client_api_version(); }
int muses_mpv_set_string(muses_mpv *c, const char *name, const char *value) {
    return c->set_property_string(c->handle, name, value);
}
int muses_mpv_load(muses_mpv *c, const char *url, const char *const *headers, size_t count) {
    if (count > 32) return MPV_ERROR_INVALID_PARAMETER;
    mpv_node values[32] = {0};
    for (size_t i = 0; i < count; ++i) {
        values[i].format = MPV_FORMAT_STRING;
        values[i].u.string = (char *)headers[i];
    }
    mpv_node_list list = {.num = (int)count, .values = values, .keys = NULL};
    mpv_node node = {.u.list = &list, .format = MPV_FORMAT_NODE_ARRAY};
    int result = c->set_property(c->handle, "http-header-fields", MPV_FORMAT_NODE, &node);
    if (result < 0) return result;
    const char *args[] = {"loadfile", url, "replace", NULL};
    return c->command(c->handle, args);
}
int muses_mpv_seek(muses_mpv *c, double seconds) {
    if (!isfinite(seconds) || seconds < 0) return MPV_ERROR_INVALID_PARAMETER;
    char value[64];
    snprintf(value, sizeof(value), "%.6f", seconds);
    const char *args[] = {"seek", value, "absolute+exact", NULL};
    return c->command(c->handle, args);
}
muses_mpv_event muses_mpv_poll(muses_mpv *c) {
    muses_mpv_event result = {0};
    mpv_event *event = c->wait_event(c->handle, 0);
    if (!event) return result;
    switch (event->event_id) {
        case MPV_EVENT_NONE: break;
        case MPV_EVENT_FILE_LOADED: result.kind = 1; break;
        case MPV_EVENT_PLAYBACK_RESTART: result.kind = 2; break;
        case MPV_EVENT_END_FILE: {
            result.kind = 3;
            mpv_event_end_file *end = event->data;
            if (end) { result.reason = end->reason; result.error = end->error; }
            break;
        }
        case MPV_EVENT_SHUTDOWN: result.kind = 4; break;
        case MPV_EVENT_QUEUE_OVERFLOW: result.kind = 6; break;
        case MPV_EVENT_PROPERTY_CHANGE: {
            result.kind = 5; result.property = event->reply_userdata;
            mpv_event_property *p = event->data;
            if (!p || !p->data || p->format == MPV_FORMAT_NONE) break;
            result.valid = 1;
            switch (p->format) {
                case MPV_FORMAT_DOUBLE: result.number = *(double *)p->data; break;
                case MPV_FORMAT_FLAG: result.number = *(int *)p->data; break;
                case MPV_FORMAT_INT64: result.number = (double)*(int64_t *)p->data; break;
                case MPV_FORMAT_STRING: {
                    const char *text = *(char **)p->data;
                    if (text) snprintf(result.text, sizeof(result.text), "%s", text);
                    break;
                }
                default: result.valid = 0; break;
            }
            break;
        }
        default: result.kind = 7; break; // Consumed, but not a UI-facing event.
    }
    // All borrowed mpv data is copied before the next wait_event call.
    return result;
}
