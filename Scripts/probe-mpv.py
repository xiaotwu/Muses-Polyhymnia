#!/usr/bin/env python3
"""Non-playing API/ABI probe: never initialize a player or audio device."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--library', type=Path, required=True)
args = parser.parse_args()
path = args.library.resolve(strict=True)
mpv = ctypes.CDLL(str(path))
mpv.mpv_client_api_version.restype = ctypes.c_ulong
version = mpv.mpv_client_api_version()
if version >> 16 != 2:
    raise RuntimeError(f'Unexpected libmpv API major: {version >> 16}')
mpv.mpv_create.restype = ctypes.c_void_p
mpv.mpv_terminate_destroy.argtypes = [ctypes.c_void_p]
handle = mpv.mpv_create()
if not handle:
    raise RuntimeError('mpv_create returned null')
mpv.mpv_terminate_destroy(handle)
ffmpeg = {}
components = {}
for name in ('avcodec', 'avformat', 'avutil'):
    library = next(path.parent.glob('lib' + name + '.*.dylib'))
    component = ctypes.CDLL(str(library))
    license_func = getattr(component, name + '_license'); license_func.restype = ctypes.c_char_p
    license_text = license_func().decode()
    if license_text != 'LGPL version 2.1 or later':
        raise RuntimeError(f'Unexpected {name} license: {license_text}')
    ffmpeg[name] = license_text
    components[name] = component
capabilities = {}
for component_name, symbol, names in [
    ('avcodec', 'avcodec_find_decoder_by_name', ['aac', 'opus', 'vorbis', 'mp3float', 'flac', 'alac']),
    ('avformat', 'av_find_input_format', ['mov', 'matroska', 'ogg', 'aac', 'mp3', 'flac', 'hls']),
]:
    function = getattr(components[component_name], symbol)
    function.argtypes = [ctypes.c_char_p]; function.restype = ctypes.c_void_p
    for name in names:
        if not function(name.encode()):
            raise RuntimeError(f'Missing required capability: {symbol}/{name}')
    capabilities[component_name] = names
filters = ctypes.CDLL(str(next(path.parent.glob('libavfilter.*.dylib'))))
filters.avfilter_get_by_name.argtypes = [ctypes.c_char_p]
filters.avfilter_get_by_name.restype = ctypes.c_void_p
capabilities['audioFilters'] = ['equalizer', 'atempo', 'aresample', 'aformat', 'volume']
for name in capabilities['audioFilters']:
    if not filters.avfilter_get_by_name(name.encode()):
        raise RuntimeError(f'Missing audio filter: {name}')
protocol = components['avformat'].avio_enum_protocols
protocol.argtypes = [ctypes.POINTER(ctypes.c_void_p), ctypes.c_int]
protocol.restype = ctypes.c_char_p
opaque = ctypes.c_void_p(); protocols = []
while value := protocol(ctypes.byref(opaque), 0):
    protocols.append(value.decode())
if not {'https', 'http', 'tcp', 'tls', 'file'} <= set(protocols):
    raise RuntimeError(f'Missing required protocols: {protocols}')
capabilities['protocols'] = protocols
with path.open('rb') as source:
    digest = hashlib.file_digest(source, 'sha256').hexdigest()
print(json.dumps({'library': str(path), 'sha256': digest, 'apiMajor': version >> 16,
                  'apiMinor': version & 0xffff, 'createDestroy': 'passed',
                  'capabilities': capabilities, 'initialized': False, 'audioOrUIStarted': False, 'ffmpegLicenses': ffmpeg}, indent=2))
