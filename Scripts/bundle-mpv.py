#!/usr/bin/env python3
"""Copy, relocate, audit and sign libmpv only in a newly assembled app bundle."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

REPO = Path(__file__).resolve().parents[1]


def run(*args):
    return subprocess.check_output([str(a) for a in args], text=True, stderr=subprocess.STDOUT)


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def dependencies(path):
    return [line.strip().split(' (compatibility version')[0]
            for line in run('/usr/bin/otool', '-L', path).splitlines()[1:] if line.strip()]


def system_dependency(value):
    return value.startswith(('/usr/lib/', '/System/Library/'))


def audit_library(path, directory):
    if run('/usr/bin/lipo', '-archs', path).strip() != 'arm64':
        raise RuntimeError(f'Expected arm64 Mach-O: {path.name}')
    commands = run('/usr/bin/otool', '-l', path)
    versions = re.findall(r'\bminos (\d+(?:\.\d+){0,2})', commands)
    if not versions or any(tuple(map(int, v.split('.'))) > (26, 0, 0) for v in versions):
        raise RuntimeError(f'Unsupported/missing deployment target: {path.name}')
    own_id = run('/usr/bin/otool', '-D', path).splitlines()[1:]
    for value in dependencies(path):
        if value in own_id or system_dependency(value):
            continue
        candidate = directory / value.removeprefix('@loader_path/')
        if (not value.startswith('@loader_path/') or not candidate.is_file()
                or candidate.resolve().parent != directory.resolve()):
            raise RuntimeError(f'Non-bundled dependency in {path.name}: {value}')
    for rpath in re.findall(r'cmd LC_RPATH\n.*?\n\s*path (.*?) \(offset', commands):
        if rpath != '@loader_path':
            raise RuntimeError(f'Unexpected runtime search path in {path.name}: {rpath}')


def install(work, app):
    if (app / 'Contents/_CodeSignature').exists():
        raise RuntimeError('Refusing to mutate an already signed app bundle')
    prefix = work / 'prefix/lib'
    manifest = json.loads((work / 'manifest.json').read_text())
    expected_sources = json.loads((REPO / 'Dependencies/mpv/source-lock.json').read_text())
    if (manifest['sources'] != expected_sources or manifest['architecture'] != 'arm64'
            or manifest.get('tools') != json.loads((REPO / 'Dependencies/mpv/tool-lock.json').read_text())
            or manifest.get('patches') != json.loads((REPO / 'Dependencies/mpv/patch-lock.json').read_text())
            or manifest.get('licenseGuards') != {'mpvGPL': False, 'ffmpegGPL': False,
                'ffmpegNonfree': False, 'ffmpegVersion3': False}):
        raise RuntimeError('Dependency provenance does not match the checked-in lock')
    files = {p.name: p for p in prefix.glob('*.dylib')}
    real = {name: p for name, p in files.items() if not p.is_symlink()}
    if set(real) != set(manifest['libraries']):
        raise RuntimeError('Dependency library inventory mismatch')
    for name, path in real.items():
        if sha256(path) != manifest['libraries'][name]:
            raise RuntimeError(f'Dependency changed after preparation: {name}')
    if 'libmpv.2.dylib' not in files:
        raise RuntimeError('Missing libmpv.2.dylib')
    resources = app / 'Contents/Resources'
    framework = app / 'Contents/Frameworks'
    if any(p.is_symlink() for p in (app / 'Contents', resources, framework)):
        raise RuntimeError('Refusing bundle directory symlinks')
    framework.mkdir(parents=True, exist_ok=True); resources.mkdir(parents=True, exist_ok=True)
    for name in files:
        if (framework / name).exists() or (framework / name).is_symlink():
            raise RuntimeError(f'Refusing to overwrite an existing bundled library: {name}')
    for item in expected_sources:
        source = work / 'corresponding-source' / item['archive']
        if sha256(source) != item['sha256']:
            raise RuntimeError(f'Corresponding source mismatch: {source.name}')
        if not any(p.is_file() for p in (work / 'notices' / item['name']).rglob('*')):
            raise RuntimeError(f'Missing license notices: {item["name"]}')
    for name, path in files.items():
        if path.is_symlink():
            target = path.resolve()
            if target.parent != prefix.resolve() or target.name not in real:
                raise RuntimeError(f'Escaping/untracked library symlink: {name}')
            (framework / name).symlink_to(target.name)
        else:
            shutil.copy2(path, framework / name)
    for name in real:
        path = framework / name
        # Changing load commands invalidates upstream ad-hoc signatures. This is
        # exclusively a new copy; the source dependency and old apps stay intact.
        subprocess.run(['/usr/bin/codesign', '--remove-signature', str(path)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        run('/usr/bin/install_name_tool', '-id', '@rpath/' + name, path)
        for value in dependencies(path):
            if system_dependency(value) or value == '@rpath/' + name:
                continue
            dependency_name = Path(value).name
            if dependency_name not in files:
                raise RuntimeError(f'Unresolved dependency: {value}')
            run('/usr/bin/install_name_tool', '-change', value, '@loader_path/' + dependency_name, path)
        commands = run('/usr/bin/otool', '-l', path)
        for rpath in re.findall(r'cmd LC_RPATH\n.*?\n\s*path (.*?) \(offset', commands):
            run('/usr/bin/install_name_tool', '-delete_rpath', rpath, path)
        audit_library(path, framework)
    shutil.copytree(work / 'notices', resources / 'MPV-Licenses')
    shutil.copytree(work / 'corresponding-source', resources / 'MPV-Sources')
    shutil.copy2(work / 'manifest.json', resources / 'MPV-Provenance.json')
    (resources / 'MPV-Bundle.json').write_text(json.dumps({
        'libraries': {name: sha256(framework / name) for name in real},
        'aliases': {name: p.resolve().name for name, p in files.items() if p.is_symlink()},
    }, indent=2) + '\n')


def sign_or_verify(app, identity):
    framework = app / 'Contents/Frameworks'
    manifest = json.loads((app / 'Contents/Resources/MPV-Bundle.json').read_text())
    if identity is not None and (app / 'Contents/_CodeSignature').exists():
        raise RuntimeError('Refusing to re-sign libraries in an already signed app')
    signed_hashes = {}
    for name in manifest['libraries']:
        path = framework / name
        audit_library(path, framework)
        if identity is not None:
            if sha256(path) != manifest['libraries'][name]:
                raise RuntimeError(f'Bundled library changed before signing: {name}')
            # Order is immaterial among sibling dylibs, but every leaf is signed
            # before the app; never deep-sign the enclosing app.
            run('/usr/bin/codesign', '--force', '--options', 'runtime',
                '--timestamp=none' if identity == '-' else '--timestamp', '--sign', identity, path)
        run('/usr/bin/codesign', '--verify', '--strict', path)
        signed_hashes[name] = sha256(path)
        if identity is None and signed_hashes[name] != manifest.get('signedLibraries', {}).get(name):
            raise RuntimeError(f'Signed library inventory mismatch: {name}')
    if identity is not None:
        manifest['signedLibraries'] = signed_hashes
        (app / 'Contents/Resources/MPV-Bundle.json').write_text(json.dumps(manifest, indent=2) + '\n')
    for name, target in manifest['aliases'].items():
        path = framework / name
        if not path.is_symlink() or path.readlink() != Path(target):
            raise RuntimeError(f'Bundled alias mismatch: {name}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['install', 'sign', 'verify'])
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--dependency-dir', type=Path)
    parser.add_argument('--identity')
    args = parser.parse_args()
    app = args.app.resolve()
    if app.suffix != '.app' or app.is_relative_to(Path('/Applications')):
        parser.error('Use a newly staged .app, never the installed application')
    if args.action == 'install':
        if args.dependency_dir is None:
            parser.error('install requires --dependency-dir (run prepare-mpv.py first)')
        install(args.dependency_dir.resolve(), app)
    else:
        if args.action == 'sign' and args.identity is None:
            parser.error('sign requires --identity')
        sign_or_verify(app, args.identity if args.action == 'sign' else None)

if __name__ == '__main__':
    main()
