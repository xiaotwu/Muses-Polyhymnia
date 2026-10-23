"""macOS loader-lifetime regression through the real C shim; no audio or network."""
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SHIM = ROOT / 'Sources/CMpv'

# Plain C deliberately avoids Objective-C classes/global destructors, which can
# independently make dyld retain an image and hide the missing NODELETE flag.
FAKE = r'''
#include "client.h"
#include <dispatch/dispatch.h>
#include <stdlib.h>
#include <string.h>
struct mpv_handle { int loaded; };
static int live, loads, destroyed;
static void (*notification)(int);
static dispatch_semaphore_t completion_gate;
struct delayed { void (*notify)(int); dispatch_semaphore_t gate; };
void test_register(void (*notify)(int), dispatch_semaphore_t gate) {
    notification = notify; completion_gate = gate;
}
void test_stats(int *l, int *n, int *d) { *l = live; *n = loads; *d = destroyed; }
static void delayed_completion(void *raw) {
    struct delayed *work = raw;
    // The host opens this gate only after every shim close and post-close stats call.
    long timed_out = dispatch_semaphore_wait(work->gate,
        dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
    void (*notify)(int) = work->notify;
    dispatch_release(work->gate);
    free(work);
    notify(timed_out != 0);
}
unsigned long mpv_client_api_version(void) { return MPV_CLIENT_API_VERSION; }
mpv_handle *mpv_create(void) {
    mpv_handle *h = calloc(1, sizeof(*h)); if (h) ++live; return h;
}
int mpv_initialize(mpv_handle *h) { return h ? 0 : -3; }
void mpv_terminate_destroy(mpv_handle *h) {
    if (!h) return;
    --live; ++destroyed; free(h);
    struct delayed *work = malloc(sizeof(*work));
    if (!work) abort();
    work->notify = notification; work->gate = completion_gate;
    dispatch_retain(work->gate);
    // libdispatch retains a function pointer into this image after handle teardown.
    dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC),
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), work, delayed_completion);
}
int mpv_set_option_string(mpv_handle *h, const char *n, const char *v) {
    (void)h; (void)n; (void)v; return 0;
}
int mpv_set_property_string(mpv_handle *h, const char *n, const char *v) {
    (void)h; (void)n; (void)v; return 0;
}
int mpv_set_property(mpv_handle *h, const char *n, mpv_format f, void *v) {
    (void)h; (void)n; (void)f; (void)v; return 0;
}
int mpv_observe_property(mpv_handle *h, uint64_t u, const char *n, mpv_format f) {
    (void)h; (void)u; (void)n; (void)f; return 0;
}
int mpv_command(mpv_handle *h, const char **args) {
    if (!strcmp(args[0], "loadfile")) { h->loaded = 1; ++loads; }
    return 0;
}
mpv_event *mpv_wait_event(mpv_handle *h, double timeout) {
    (void)h; (void)timeout; static mpv_event none; return &none;
}
'''

HOST = r'''
#include "CMpv.h"
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdatomic.h>
#include <stdio.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>
static atomic_int completions, failed_callbacks;
static void completed(int failed) {
    atomic_fetch_add(&failed_callbacks, failed);
    atomic_fetch_add(&completions, 1);
}
int main(int argc, char **argv) {
    struct rlimit no_core = {0, 0}; setrlimit(RLIMIT_CORE, &no_core);
    if (argc != 2) return 40;
    dispatch_semaphore_t gate = dispatch_semaphore_create(0);
    for (int i = 0; i < 3; ++i) {
        int error = 0;
        muses_mpv *client = muses_mpv_open(argv[1], &error);
        if (!client) { fprintf(stderr, "shim_open:%d\n", error); return 41; }
        void *inspection = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL | RTLD_NOLOAD);
        if (!inspection) return 41;
        void (*setup)(void (*)(int), dispatch_semaphore_t) = dlsym(inspection, "test_register");
        void (*stats)(int *, int *, int *) = dlsym(inspection, "test_stats");
        if (!setup || !stats) return 41;
        setup(completed, gate);
        // Do not let the diagnostic reference keep the fake image alive at shim close.
        dlclose(inspection);
        if (muses_mpv_load(client, "test://fixture/no-network", NULL, 0) < 0) return 44;
        muses_mpv_close(client);
        // Darwin may remove a NODELETE image from the logical NOLOAD list while
        // retaining its VM mapping. Call the saved pointer with no loader reference
        // held: both this code and its static counters must remain usable after close.
        int live = -1, loads = -1, destroyed = -1;
        stats(&live, &loads, &destroyed);
        if (live != 0 || loads != i + 1 || destroyed != i + 1) return 43;
    }
    for (int i = 0; i < 3; ++i) dispatch_semaphore_signal(gate);
    // Bounded wait, not a fixed seven-second audio timer; callbacks use no mpv handle.
    for (int i = 0; i < 300 && atomic_load(&completions) != 3; ++i) usleep(10000);
    if (atomic_load(&completions) != 3 || atomic_load(&failed_callbacks)) return 45;
    dispatch_release(gate);
    puts("closed=3 live=0 delayed_callbacks=3");
    return 0;
}
'''


@unittest.skipUnless(sys.platform == 'darwin', 'requires macOS dyld and libdispatch')
class MpvLifetimeTests(unittest.TestCase):
    def test_destroy_keeps_image_for_delayed_callbacks(self):
        if not shutil.which('xcrun'):
            self.skipTest('requires Xcode command-line tools (xcrun clang)')
        # Every native program is a child: even a loader regression cannot kill unittest.
        env = {key: value for key, value in os.environ.items() if not key.startswith('DYLD_')}

        def run(command, timeout):
            return subprocess.run(command, capture_output=True, text=True, timeout=timeout, env=env)

        def compile_c(arguments):
            result = run(['xcrun', 'clang', '-std=c11', '-Wall', '-Wextra', '-Werror', *arguments], 30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

        with tempfile.TemporaryDirectory(prefix='muses-mpv-lifetime-') as temporary:
            work = Path(temporary)
            fake = work / 'fake.c'
            host = work / 'host.c'
            library = work / 'libmpv.2.dylib'
            fake.write_text(FAKE)
            host.write_text(HOST)
            compile_c(['-dynamiclib', '-I', str(SHIM / 'vendor'), str(fake), '-o', str(library)])

            def executable(shim_source, name, extra_flags=()):
                output = work / name
                compile_c([*extra_flags, '-I', str(SHIM / 'include'), '-I', str(SHIM),
                           str(host), str(shim_source), '-o', str(output)])
                return output

            # Positive path compiles the actual workspace C implementation, not a reimplementation.
            actual = executable(SHIM / 'CMpv.c', 'actual')
            result = run([str(actual), str(library)], 8)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('closed=3 live=0 delayed_callbacks=3', result.stdout)

            # Remove both lifetime protections only in a temporary source copy.
            # Keep every live/load/destroy/callback assertion: residency must
            # preserve globals across opens, not merely keep old code callable.
            legacy_source = work / 'legacy.c'
            source = (SHIM / 'CMpv.c').read_text()
            resident_call = 'if (!retain_process_library(path)) goto fail;'
            self.assertEqual(source.count(resident_call), 1, 'expected one resident-library acquisition')
            legacy_text = source.replace(resident_call, '', 1)
            legacy_text = re.sub(r'\s*\|\s*RTLD_NODELETE\b', '', legacy_text)
            legacy_source.write_text(legacy_text)
            # The deliberately disconnected static retention helper may now be unused.
            legacy = executable(legacy_source, 'legacy', ('-Wno-unused-function',))
            result = run([str(legacy), str(library)], 8)
            self.assertEqual(result.returncode, -signal.SIGSEGV, result.stdout + result.stderr)
            # The unpinned child calls an unmapped saved function pointer (or its
            # delayed callback does); only that child crashes, never unittest.


if __name__ == '__main__':
    unittest.main()
