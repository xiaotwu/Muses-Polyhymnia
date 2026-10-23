#!/usr/bin/env python3
"""Refuse to replace an app whose own executable or helper is still running."""
import argparse
import ctypes
import errno
import os
from pathlib import Path
import sys


def executable_paths():
    """Read executable paths only; never inspect command-line arguments or kill."""
    if sys.platform != 'darwin':
        raise RuntimeError('The application process guard requires macOS')
    library = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
    library.proc_listallpids.argtypes = (ctypes.c_void_p, ctypes.c_int)
    library.proc_listallpids.restype = ctypes.c_int
    library.proc_listpids.argtypes = (ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_int)
    library.proc_listpids.restype = ctypes.c_int
    library.proc_pidpath.argtypes = (ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32)
    library.proc_pidpath.restype = ctypes.c_int
    capacity = library.proc_listallpids(None, 0)
    if capacity <= 0:
        raise RuntimeError('Cannot inspect running applications safely')
    for _ in range(3):
        capacity += 128
        pids = (ctypes.c_int * capacity)()
        count = library.proc_listallpids(pids, ctypes.sizeof(pids))
        if count < 0:
            raise RuntimeError('Cannot inspect running applications safely')
        if count < capacity:
            break
        capacity = count
    else:
        raise RuntimeError('Running process inventory changed; retry packaging')
    # PROC_UID_ONLY is defined as 4 in macOS sys/proc_info.h. Unlike the
    # proc_listallpids wrapper, proc_listpids returns a byte count.
    owned_buffer = (ctypes.c_int * capacity)()
    owned_bytes = library.proc_listpids(4, os.getuid(), owned_buffer, ctypes.sizeof(owned_buffer))
    if owned_bytes < 0 or owned_bytes >= ctypes.sizeof(owned_buffer):
        raise RuntimeError('Cannot inspect application ownership safely; retry packaging')
    owned = set(owned_buffer[:owned_bytes // ctypes.sizeof(ctypes.c_int)])
    for pid in pids[:count]:
        if pid <= 0:
            continue
        buffer = ctypes.create_string_buffer(4096)
        ctypes.set_errno(0)
        if library.proc_pidpath(pid, buffer, len(buffer)) > 0:
            yield pid, Path(buffer.value.decode('utf-8', errors='surrogateescape'))
        elif pid in owned and ctypes.get_errno() not in (errno.ESRCH, errno.ENOENT):
            raise RuntimeError('Cannot inspect an application executable safely; retry packaging')
        # Ignore vanished processes and foreign protected executables. Fail
        # closed if an executable owned by the packaging user is inaccessible.


def matching_processes(app, processes):
    destination = app.resolve()
    matches = []
    for pid, executable in processes:
        try:
            executable.resolve().relative_to(destination)
        except ValueError:
            continue
        matches.append(pid)
    return matches


def check(app):
    matches = matching_processes(app, executable_paths())
    if matches:
        raise RuntimeError('Refusing to replace a running application bundle '
                           f'(PID {", ".join(map(str, matches))}). Quit that bundle and retry.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    arguments = parser.parse_args()
    try:
        check(arguments.app)
    except (OSError, RuntimeError) as error:
        parser.exit(1, f'{error}\n')


if __name__ == '__main__':
    main()
