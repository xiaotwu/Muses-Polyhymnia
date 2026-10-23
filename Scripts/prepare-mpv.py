#!/usr/bin/env python3
"""Build the pinned LGPL audio-only libmpv closure without a global install."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import urllib.request

REPO = Path(__file__).resolve().parents[1]
LOCKS = REPO / 'Dependencies/mpv'


def digest(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()


def fetch(item, downloads):
    path = downloads / item['archive']
    if not path.exists():
        temporary = path.with_suffix(path.suffix + '.download')
        with urllib.request.urlopen(item['url'], timeout=120) as response, temporary.open('wb') as out:
            shutil.copyfileobj(response, out)
        temporary.rename(path)
    if digest(path) != item['sha256']:
        raise RuntimeError(f'Checksum mismatch: {path}')
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work-dir', type=Path, required=True)
    parser.add_argument('--jobs', type=int, default=4)
    args = parser.parse_args()
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        parser.error('This recipe targets native arm64 macOS 26+')
    work = args.work_dir.resolve()
    # Never reuse the shared Swift build or mutate installed bundles.
    if (work == REPO or any(part.endswith('.app') for part in work.parts)
            or work.is_relative_to(REPO / 'build') or work.is_relative_to(REPO / '.build')
            or work.is_relative_to(Path('/Applications'))):
        parser.error('Choose a dedicated dependency work directory')
    work.mkdir(parents=True, exist_ok=True)
    # An interrupted rebuild must never retain a stale readiness stamp.
    (work / 'manifest.json').unlink(missing_ok=True)
    downloads = work / 'downloads'; downloads.mkdir(exist_ok=True)
    prefix = work / 'prefix'
    env = os.environ.copy()
    env.update(MACOSX_DEPLOYMENT_TARGET='26.0', CC='/usr/bin/clang', CXX='/usr/bin/clang++',
               CFLAGS='-arch arm64 -mmacosx-version-min=26.0',
               CXXFLAGS='-arch arm64 -mmacosx-version-min=26.0',
               LDFLAGS='-arch arm64 -mmacosx-version-min=26.0 -Wl,-headerpad_max_install_names')
    env['PATH'] = str(work / 'tools/bin') + ':' + str(prefix / 'bin') + ':/usr/bin:/bin:/usr/sbin:/sbin'
    env['PKG_CONFIG_LIBDIR'] = str(prefix / 'lib/pkgconfig')
    env['PKG_CONFIG_PATH'] = str(prefix / 'lib/pkgconfig')
    env['PKG_CONFIG_ALLOW_SYSTEM_CFLAGS'] = '1'
    env['PKG_CONFIG_ALLOW_SYSTEM_LIBS'] = '1'
    # Do not inherit a developer's SDK/library search or DYLD injection.
    for key in ('CPATH', 'CPPFLAGS', 'C_INCLUDE_PATH', 'CPLUS_INCLUDE_PATH', 'OBJC_INCLUDE_PATH', 'LIBRARY_PATH', 'DYLD_LIBRARY_PATH', 'DYLD_FRAMEWORK_PATH', 'SDKROOT'):
        env.pop(key, None)
    log = (work / 'build.log').open('a')
    def run(command, cwd=work):
        print('+', ' '.join(map(str, command)), flush=True)
        log.write('\n+ ' + ' '.join(map(str, command)) + '\n'); log.flush()
        subprocess.run(list(map(str, command)), cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    tools = json.loads((LOCKS / 'tool-lock.json').read_text())
    tool_archives = [fetch(item, downloads) for item in tools]
    wheels = [p for p in tool_archives if p.suffix == '.whl']
    if not (work / 'tools/bin/python3').exists():
        run([shutil.which('python3'), '-m', 'venv', work / 'tools'])
    run([work / 'tools/bin/python3', '-m', 'pip', 'install', '--no-index', '--no-deps', *wheels])
    # MarkupSafe's pure Python fallback avoids a Python-ABI-specific C wheel.
    purelib = Path(subprocess.check_output([str(work / 'tools/bin/python3'), '-c',
                   'import sysconfig; print(sysconfig.get_path("purelib"))'], text=True).strip())
    markup_archive = next(p for p in tool_archives if p.name.startswith('markupsafe-'))
    markup_source = work / 'tool-source'; markup_source.mkdir(exist_ok=True)
    with tarfile.open(markup_archive) as tar:
        tar.extractall(markup_source, filter='data')
    shutil.copytree(next(markup_source.glob('markupsafe-*/src/markupsafe')), purelib / 'markupsafe', dirs_exist_ok=True)
    source_items = json.loads((LOCKS / 'source-lock.json').read_text())
    sources = {}
    for item in source_items:
        archive = fetch(item, downloads)
        target = work / 'source' / item['name']
        if not target.exists():
            target.mkdir(parents=True)
            with tarfile.open(archive) as tar:
                members = tar.getmembers()
                top = members[0].name.split('/')[0]
                tar.extractall(target, filter='data')
                sources[item['name']] = target / top
        else:
            sources[item['name']] = next(target.iterdir())
    patches = json.loads((LOCKS / 'patch-lock.json').read_text())
    for item in patches:
        patch = LOCKS / 'patches' / item['file']
        if digest(patch) != item['sha256']:
            raise RuntimeError(f'Patch checksum mismatch: {patch}')
        if 'CoreAudio uses CF string helpers even in a headless libmpv build.' not in (sources['mpv'] / 'meson.build').read_text():
            run(['/usr/bin/patch', '--batch', '--forward', '-p1', '-i', patch], sources['mpv'])
    def meson(name, *options, static=False):
        build = work / ('build-' + name)
        command = ['meson', 'setup', build, sources[name], '--prefix', prefix,
                   '--libdir=lib', '--buildtype=release', '--wrap-mode=nodownload',
                   '-Dauto_features=disabled', '-Ddefault_library=' + ('static' if static else 'shared'),
                   '-Db_staticpic=true', '-Dc_args=' + env['CFLAGS'], '-Dcpp_args=' + env['CXXFLAGS'],
                   '-Dc_link_args=' + env['LDFLAGS'], '-Dcpp_link_args=' + env['LDFLAGS'], *options]
        if (build / 'build.ninja').exists():
            command.extend(['--clearcache', '--reconfigure'])
        run(command)
        run(['ninja', '-C', build, '-j', args.jobs])
        run(['ninja', '-C', build, 'install'])
    pkgbuild = work / 'build-pkgconf'; pkgbuild.mkdir(exist_ok=True)
    run([sources['pkgconf'] / 'configure', '--prefix=' + str(prefix), '--disable-shared',
         '--with-system-includedir=/usr/include', '--with-system-libdir=/usr/lib'], pkgbuild)
    # configure changes compile-time system-path macros; make alone does not
    # notice command-line changes when resuming an interrupted native build.
    run(['/usr/bin/make', 'clean'], pkgbuild)
    run(['/usr/bin/make', '-j', args.jobs], pkgbuild); run(['/usr/bin/make', 'install'], pkgbuild)
    env['PKG_CONFIG'] = str(prefix / 'bin/pkgconf')
    meson('freetype', '-Dharfbuzz=disabled', '-Dzlib=disabled', '-Dbzip2=disabled', '-Dpng=disabled', '-Dbrotli=disabled')
    meson('fribidi', '-Ddocs=false', '-Dtests=false', '-Dbin=false')
    meson('harfbuzz', '-Dtests=disabled', '-Ddocs=disabled', '-Dutilities=disabled', '-Dglib=disabled',
          '-Dgobject=disabled', '-Dcairo=disabled', '-Dfreetype=disabled', '-Dcoretext=disabled')
    meson('libass', '-Dcoretext=enabled', static=True)
    meson('libplacebo', '-Ddemos=false', '-Dtests=false', '-Dbench=false',
          '-Dc_args=' + env['CFLAGS'] + ' -I' + str(sources['vulkan-headers'] / 'include'))
    ffbuild = work / 'build-ffmpeg'; ffbuild.mkdir(exist_ok=True)
    run([sources['ffmpeg'] / 'configure', '--prefix=' + str(prefix), '--arch=arm64', '--target-os=darwin',
         '--cc=/usr/bin/clang', '--disable-autodetect', '--disable-gpl', '--disable-nonfree',
         '--disable-version3', '--enable-shared', '--disable-static', '--disable-programs', '--disable-doc',
         '--disable-everything', '--enable-avcodec', '--enable-avformat', '--enable-avfilter', '--enable-swresample',
         '--enable-swscale', '--enable-network', '--enable-securetransport',
         '--enable-protocol=file,http,https,tcp,tls,crypto',
         '--enable-demuxer=mov,matroska,mp3,aac,ogg,flac,wav,hls,mpegts',
         '--enable-decoder=aac,aac_latm,opus,vorbis,mp3,mp3float,flac,alac,pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le',
         '--enable-parser=aac,aac_latm,opus,vorbis,mpegaudio,flac',
         '--enable-filter=abuffer,abuffersink,aresample,aformat,anull,volume,equalizer,atempo,pan,asplit,astats',
         '--extra-cflags=-arch arm64 -mmacosx-version-min=26.0',
         '--extra-ldflags=-arch arm64 -mmacosx-version-min=26.0 -Wl,-headerpad_max_install_names'], ffbuild)
    run(['/usr/bin/make', '-j', args.jobs], ffbuild); run(['/usr/bin/make', 'install'], ffbuild)
    meson('mpv', '-Dgpl=false', '-Dlibmpv=true', '-Dcplayer=false', '-Dbuild-date=false',
          '-Dcoreaudio=enabled', '-Daudiounit=disabled', '-Dcocoa=disabled', '-Dswift-build=disabled',
          '-Dlua=disabled', '-Dgl=disabled', '-Db_lundef=true')
    required_defines = {work / 'build-mpv/config.h': {'HAVE_GPL': 0},
                        ffbuild / 'config.h': {'CONFIG_GPL': 0, 'CONFIG_NONFREE': 0,
                                              'CONFIG_VERSION3': 0, 'CONFIG_SECURETRANSPORT': 1}}
    import re
    for config, defines in required_defines.items():
        text = config.read_text()
        for name, value in defines.items():
            if not re.search(r'^#define ' + name + r' ' + str(value) + r'$', text, re.M):
                raise RuntimeError(f'License/TLS build guard failed: {name} in {config}')
    notices = work / 'notices'; notices.mkdir(exist_ok=True)
    for name, root in sources.items():
        for path in root.rglob('*'):
            if path.is_file() and (path.name.upper().startswith(('LICENSE', 'COPYING', 'COPYRIGHT')) or path.name.upper() == 'FTL.TXT'):
                output = notices / name / path.relative_to(root)
                output.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(path, output)
    # Complete, exact corresponding sources + recipe accompany the app. Dynamic
    # LGPL libraries can be rebuilt/replaced; no GPL/nonfree code is enabled.
    sources_out = work / 'corresponding-source'; sources_out.mkdir(exist_ok=True)
    for item in source_items:
        shutil.copy2(downloads / item['archive'], sources_out / item['archive'])
    recipe_locks = sources_out / 'Dependencies/mpv'; recipe_locks.mkdir(parents=True, exist_ok=True)
    for filename in ('source-lock.json', 'tool-lock.json', 'patch-lock.json', 'README.md'):
        shutil.copy2(LOCKS / filename, recipe_locks / filename)
    shutil.copytree(LOCKS / 'patches', recipe_locks / 'patches', dirs_exist_ok=True)
    recipe_scripts = sources_out / 'Scripts'; recipe_scripts.mkdir(exist_ok=True)
    shutil.copy2(__file__, recipe_scripts / Path(__file__).name)
    manifest = {'platform': 'macOS', 'architecture': 'arm64', 'minimumOS': '26.0',
                'sources': source_items, 'tools': tools, 'patches': patches,
                'compiler': subprocess.check_output(['/usr/bin/clang', '--version'], text=True),
                'sdk': subprocess.check_output(['/usr/bin/xcrun', '--show-sdk-version'], text=True).strip(),
                'licenseGuards': {'mpvGPL': False, 'ffmpegGPL': False, 'ffmpegNonfree': False, 'ffmpegVersion3': False},
                'libraries': {p.name: digest(p) for p in sorted((prefix / 'lib').glob('*.dylib')) if not p.is_symlink()}}
    (work / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Prepared {prefix}; log: {work / "build.log"}')

if __name__ == '__main__':
    main()
