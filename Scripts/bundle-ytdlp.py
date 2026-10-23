#!/usr/bin/env python3
"""Pin, assemble and sign yt-dlp's onedir runtime without per-request extraction."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import subprocess
import tempfile
import zipfile

VERSION = '2026.10.21'
ARCHIVE_SHA256 = '2b5251788b36fcbc476568b4eea8cb239f0a775759456f2ff9344a437c52f000'
# Unsigned tree after restoring the four flattened Python.framework links.
RUNTIME_SHA256 = '11ffbd44449218dc560fb0157cd1229c597bcdd90ac9e255bd7148fcc40d5b8a'
LICENSE_SHA256 = '7e12e5df4bae12cb21581ba157ced20e1986a0508dd10d0e8a4ab9a4cf94e85c'
REMOTE_URL = f'https://github.com/yt-dlp/yt-dlp/releases/download/{VERSION}/yt-dlp_macos.zip'
LICENSE_URL = f'https://raw.githubusercontent.com/yt-dlp/yt-dlp/{VERSION}/LICENSE'
ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / 'Sources/Muses/Resources'
COMPONENTS = ('yt-dlp', '_internal', 'yt-dlp-LICENSE')
RUNTIME_ROOTS = ('Contents/Resources',
                 'Contents/Resources/Muses_Muses.bundle/Contents/Resources/Resources')
MACHO_MAGICS = {bytes.fromhex(s) for s in
                ('feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
                 'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def inventory(root, names):
    """Include paths, modes, bytes and links, without following directory links."""
    entries = []

    def visit(path):
        mode = path.lstat().st_mode
        entry = {'path': path.relative_to(root).as_posix(), 'mode': stat.S_IMODE(mode)}
        if stat.S_ISLNK(mode):
            target = os.readlink(path)
            if Path(target).is_absolute() or not path.resolve().is_relative_to(root.resolve()):
                raise RuntimeError(f'Runtime link escapes its root: {path}')
            entry.update(kind='link', target=target)
        elif stat.S_ISREG(mode):
            entry.update(kind='file', sha256=sha256(path))
        elif stat.S_ISDIR(mode):
            entry.update(kind='directory')
        else:
            raise RuntimeError(f'Unexpected runtime file type: {path}')
        entries.append(entry)
        if stat.S_ISDIR(mode):
            for child in sorted(path.iterdir()):
                visit(child)

    for name in names:
        visit(root / name)
    return entries


def runtime_sha256(root):
    value = inventory(root, ('yt-dlp', '_internal'))
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def runtime_valid(root):
    try:
        return runtime_sha256(root) == RUNTIME_SHA256
    except (OSError, RuntimeError):
        return False


def license_valid(root):
    path = root / 'yt-dlp-LICENSE'
    return path.is_file() and not path.is_symlink() and sha256(path) == LICENSE_SHA256


def remove(path):
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    elif path.exists() or path.is_symlink():
        path.unlink()


def extract_runtime(archive, destination):
    """Extract only regular release members; never permit traversal or links."""
    with zipfile.ZipFile(archive) as source:
        seen = set()
        for member in source.infolist():
            name = member.filename.rstrip('/')
            relative = PurePosixPath(name)
            mode = member.external_attr >> 16
            if (not name or str(relative) != name or relative.is_absolute()
                    or '..' in relative.parts or '\\' in name or name in seen
                    or relative.parts[0] not in ('_internal', 'yt-dlp_macos')
                    or (relative.parts[0] == 'yt-dlp_macos' and len(relative.parts) != 1)
                    or stat.S_IFMT(mode) not in (stat.S_IFREG, stat.S_IFDIR)):
                raise RuntimeError(f'Invalid runtime archive member: {member.filename}')
            seen.add(name)
            path = destination / relative
            if member.is_dir():
                path.mkdir(parents=True, exist_ok=True)
                path.chmod(0o755)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                with source.open(member) as data, path.open('xb') as output:
                    shutil.copyfileobj(data, output)
                path.chmod(0o755 if mode & 0o111 else 0o644)
    (destination / 'yt-dlp_macos').rename(destination / 'yt-dlp')
    # The official ZIP contains byte-identical flattened copies. Reconstruct
    # the canonical framework before signing; codesign rejects the flat layout.
    framework = destination / '_internal/Python.framework'
    links = (
        (framework / 'Versions/Current', framework / 'Versions/3.14', '3.14'),
        (framework / 'Python', framework / 'Versions/3.14/Python', 'Versions/Current/Python'),
        (framework / 'Resources', framework / 'Versions/3.14/Resources', 'Versions/Current/Resources'),
        (destination / '_internal/Python', framework / 'Versions/3.14/Python',
         'Python.framework/Versions/Current/Python'),
    )
    for duplicate, canonical, target in links:
        if inventory(duplicate.parent, (duplicate.name,)) != [
                dict(entry, path=duplicate.name + entry['path'][len(canonical.name):])
                for entry in inventory(canonical.parent, (canonical.name,))]:
            raise RuntimeError(f'Flattened Python framework differs: {duplicate}')
        remove(duplicate)
        duplicate.symlink_to(target)


def replace_components(staging, destination):
    """Validate first; roll back the whole installed set if a rename fails."""
    backup = staging / 'previous'
    backup.mkdir()
    saved, installed = [], []
    try:
        for name in COMPONENTS:
            old = destination / name
            if old.exists() or old.is_symlink():
                old.rename(backup / name)
                saved.append(name)
        for name in COMPONENTS:
            (staging / name).rename(destination / name)
            installed.append(name)
    except OSError:
        for name in installed:
            remove(destination / name)
        for name in saved:
            (backup / name).rename(destination / name)
        raise


def fetch(check):
    valid, license_ok = runtime_valid(RESOURCES), license_valid(RESOURCES)
    print(f'== yt-dlp bundling ==\npinned: {VERSION} (onedir)\n'
          f'runtime verified: {int(valid)}\nlicense verified: {int(license_ok)}')
    if check or (valid and license_ok):
        return
    RESOURCES.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.yt-dlp-download.', dir=RESOURCES) as temporary:
        staging = Path(temporary)
        if valid:
            shutil.copy2(RESOURCES / 'yt-dlp', staging / 'yt-dlp')
            shutil.copytree(RESOURCES / '_internal', staging / '_internal', symlinks=True)
        else:
            archive = staging / 'runtime.zip'
            subprocess.run(['curl', '-fL', '--retry', '2', REMOTE_URL, '-o', str(archive)], check=True)
            if sha256(archive) != ARCHIVE_SHA256:
                raise RuntimeError('Pinned yt-dlp archive SHA-256 verification failed')
            extract_runtime(archive, staging)
        license_path = staging / 'yt-dlp-LICENSE'
        if license_ok:
            shutil.copy2(RESOURCES / 'yt-dlp-LICENSE', license_path)
        else:
            subprocess.run(['curl', '-fsSL', '--retry', '2', LICENSE_URL,
                            '-o', str(license_path)], check=True)
        license_path.chmod(0o644)
        if not runtime_valid(staging) or not license_valid(staging):
            raise RuntimeError('Pinned yt-dlp runtime/license verification failed; resources were not replaced')
        replace_components(staging, RESOURCES)
    print(f'Bundled verified yt-dlp {VERSION}, Python runtime and licenses.')


def unsigned_app(app):
    if (app / 'Contents/_CodeSignature').exists():
        raise RuntimeError('Refusing to mutate an already signed app bundle')


def install(app):
    unsigned_app(app)
    if not runtime_valid(RESOURCES) or not license_valid(RESOURCES):
        raise RuntimeError('Run copy-ytdlp.sh to prepare the pinned runtime first')
    for relative in RUNTIME_ROOTS:
        destination = app / relative
        destination.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='.yt-dlp-install.', dir=destination) as temporary:
            staging = Path(temporary)
            shutil.copy2(RESOURCES / 'yt-dlp', staging / 'yt-dlp')
            shutil.copy2(RESOURCES / 'yt-dlp-LICENSE', staging / 'yt-dlp-LICENSE')
            shutil.copytree(RESOURCES / '_internal', staging / '_internal', symlinks=True)
            if not runtime_valid(staging):
                raise RuntimeError('Runtime changed during packaging')
            replace_components(staging, destination)


def native_files(root):
    files = []
    for entry in inventory(root, ('yt-dlp', '_internal')):
        path = root / entry['path']
        if entry['kind'] == 'file':
            with path.open('rb') as source:
                if source.read(4) in MACHO_MAGICS:
                    files.append(path)
    return files


def codesign(*arguments):
    subprocess.run(['/usr/bin/codesign', *map(str, arguments)], check=True)


def sign_or_verify(app, identity):
    receipt_path = app / 'Contents/Resources/yt-dlp-runtime.json'
    if identity is not None:
        unsigned_app(app)
        if not all(runtime_valid(app / r) and license_valid(app / r) for r in RUNTIME_ROOTS):
            raise RuntimeError('Bundled runtime differs from the unsigned pin')
        receipt = dict(version=VERSION, archiveSHA256=ARCHIVE_SHA256,
                       unsignedRuntimeSHA256=RUNTIME_SHA256, roots={})
    else:
        receipt = json.loads(receipt_path.read_text())
        if (receipt.get('version') != VERSION or receipt.get('archiveSHA256') != ARCHIVE_SHA256
                or receipt.get('unsignedRuntimeSHA256') != RUNTIME_SHA256
                or set(receipt.get('roots', {})) != set(RUNTIME_ROOTS)):
            raise RuntimeError('Unexpected runtime receipt')
    for relative in RUNTIME_ROOTS:
        root = app / relative
        natives = native_files(root)
        framework = root / '_internal/Python.framework'
        if identity is not None:
            arguments = ['--force', '--options', 'runtime',
                         '--timestamp=none' if identity == '-' else '--timestamp', '--sign', identity]
            for path in natives:
                if path.name != 'yt-dlp':
                    codesign(*arguments, path)
            codesign(*arguments, framework)
            # Keep the standalone Python helper's existing entitlement scoped
            # to its entry point; do not apply it to the app or other helpers.
            codesign(*arguments, '--entitlements', RESOURCES / 'YTDLP.entitlements', root / 'yt-dlp')
        for path in natives:
            codesign('--verify', '--strict', path)
        codesign('--verify', '--deep', '--strict', framework)
        value = dict(signedRuntimeSHA256=runtime_sha256(root),
                     nativeFiles=[p.relative_to(root).as_posix() for p in natives])
        if not license_valid(root):
            raise RuntimeError('Bundled resolver license changed')
        if identity is None and value != receipt['roots'].get(relative):
            raise RuntimeError('Signed runtime changed after signing')
        receipt['roots'][relative] = value
    if identity is not None:
        receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_subparsers(dest='action', required=True)
    actions.add_parser('fetch').add_argument('--check', action='store_true')
    for name in ('install', 'sign', 'verify'):
        command = actions.add_parser(name)
        command.add_argument('--app', required=True, type=Path)
        if name == 'sign':
            command.add_argument('--identity', required=True)
    args = parser.parse_args()
    if args.action == 'fetch':
        fetch(args.check)
    elif args.action == 'install':
        install(args.app)
    else:
        sign_or_verify(args.app, args.identity if args.action == 'sign' else None)


if __name__ == '__main__':
    main()
