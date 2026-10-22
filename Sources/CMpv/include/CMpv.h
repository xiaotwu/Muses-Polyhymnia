#ifndef MUSES_CMPV_H
#define MUSES_CMPV_H
#include <stdint.h>
#include <stddef.h>
// All functions, including destruction, must run on the owner's serial queue.
typedef struct muses_mpv muses_mpv;
typedef struct {
    int kind; // 0 none, 1 loaded, 2 restart, 3 end, 4 shutdown, 5 property, 6 overflow
    int error;
    int reason; // libmpv end-file reason: EOF=0, stop=2, quit=3, error=4, redirect=5
    uint64_t property;
    double number;
    int valid;
    char text[128];
} muses_mpv_event;
// Exact absolute path only. No search path fallback. error is a safe fixed category.
muses_mpv *muses_mpv_open(const char *path, int *error);
void muses_mpv_close(muses_mpv *client);
unsigned long muses_mpv_version(muses_mpv *client);
int muses_mpv_load(muses_mpv *client, const char *url, const char *const *headers, size_t count);
int muses_mpv_set_string(muses_mpv *client, const char *name, const char *value);
int muses_mpv_seek(muses_mpv *client, double seconds);
muses_mpv_event muses_mpv_poll(muses_mpv *client);
#endif
