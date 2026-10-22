"""Pinned onedir download, closure and signing tests; no network or real resolver."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / 'Scripts/bundle-ytdlp.py'
BINARY = b'#!/bin/sh\necho 2026.10.21\n'
NATIVE = bytes.fromhex('cffaedfe') + b'isolated Mach-O fixture'
LICENSE = b'isolated downloader license fixture\n'
sys.dont_write_bytecode = True


def load(path):
    spec = importlib.util.spec_from_file_location('resolver_fixture', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def archive_bytes(extra=None):
    files = {
        'yt-dlp_macos': BINARY,
        '_internal/Python': NATIVE,
        '_internal/Python.framework/Python': NATIVE,
        '_internal/Python.framework/Resources/Info.plist': b'framework plist',
        '_internal/Python.framework/Versions/3.14/Python': NATIVE,
        '_internal/Python.framework/Versions/3.14/Resources/Info.plist': b'framework plist',
        '_internal/Python.framework/Versions/Current/Python': NATIVE,
        '_internal/Python.framework/Versions/Current/Resources/Info.plist': b'framework plist',
        '_internal/lib-dynload/extension.so': NATIVE,
        '_internal/base_library.zip': b'python data',
        '_internal/THIRD_PARTY_LICENSES.txt': b'third party notices',
    }
    files.update(extra or {})
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w') as archive:
        directories = {p.as_posix() + '/' for name in files
                       for p in Path(name).parents if str(p) != '.'}
        for name in sorted(directories):
            member = zipfile.ZipInfo(name)
            member.external_attr = (stat.S_IFDIR | 0o755) << 16
            archive.writestr(member, b'')
        for name, data in sorted(files.items()):
            member = zipfile.ZipInfo(name)
            member.external_attr = (stat.S_IFREG | (0o755 if name.endswith(('.so', 'Python', 'macos')) else 0o644)) << 16
            archive.writestr(member, data)
    return stream.getvalue()


class ResolverBundleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'Scripts').mkdir()
        self.resources = self.root / 'Sources/Muses/Resources'
        self.script = self.root / 'Scripts/copy-ytdlp.sh'
        shutil.copy2(ROOT / 'Scripts/copy-ytdlp.sh', self.script)
        self.helper = self.root / 'Scripts/bundle-ytdlp.py'
        shutil.copy2(HELPER, self.helper)
        self.fixtures = self.root / 'fixtures'; self.fixtures.mkdir()
        self.archive = self.fixtures / 'archive.zip'; self.archive.write_bytes(archive_bytes())
        (self.fixtures / 'LICENSE').write_bytes(LICENSE)
        self.normalized = self.root / 'normalized'; self.normalized.mkdir()
        module = load(self.helper)
        module.extract_runtime(self.archive, self.normalized)
        pins = dict(ARCHIVE_SHA256=hashlib.sha256(self.archive.read_bytes()).hexdigest(),
                    LICENSE_SHA256=hashlib.sha256(LICENSE).hexdigest(),
                    RUNTIME_SHA256=module.runtime_sha256(self.normalized))
        script = self.helper.read_text()
        for name, value in pins.items():
            script = re.sub(rf"^{name} = '[0-9a-f]+'", f"{name} = '{value}'", script, flags=re.M)
        self.helper.write_text(script)
        self.module = load(self.helper)
        self.bin = self.root / 'fake-bin'; self.bin.mkdir()
        self.calls = self.root / 'curl-calls'
        fake_curl = self.bin / 'curl'
        fake_curl.write_text('''#!/usr/bin/env python3
import os, pathlib, sys
args=sys.argv[1:]
url=next(a for a in args if a.startswith('https://'))
with open(os.environ['RESOLVER_TEST_CALLS'], 'a') as out: out.write(url+'\\n')
if os.environ.get('RESOLVER_TEST_FAIL') == 'network': raise SystemExit(22)
output=pathlib.Path(args[args.index('-o')+1])
source=pathlib.Path(os.environ['RESOLVER_TEST_FIXTURES']) / ('LICENSE' if url.endswith('/LICENSE') else 'archive.zip')
failure=os.environ.get('RESOLVER_TEST_FAIL')
corrupt=failure == 'checksum' or (failure == 'license-checksum' and url.endswith('/LICENSE'))
output.write_bytes(b'truncated' if corrupt else source.read_bytes())
''')
        fake_curl.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update(PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        RESOLVER_TEST_CALLS=str(self.calls), RESOLVER_TEST_FIXTURES=str(self.fixtures))

    def run_script(self, *arguments, failure=None):
        env = self.env.copy()
        if failure: env['RESOLVER_TEST_FAIL'] = failure
        return subprocess.run(['/bin/bash', str(self.script), *arguments], cwd=self.root,
                              env=env, capture_output=True, text=True)

    def existing(self):
        self.resources.mkdir(parents=True)
        shutil.copy2(self.normalized / 'yt-dlp', self.resources / 'yt-dlp')
        shutil.copytree(self.normalized / '_internal', self.resources / '_internal', symlinks=True)
        (self.resources / 'yt-dlp-LICENSE').write_bytes(LICENSE)

    def snapshot(self):
        return {str(p.relative_to(self.resources)): (os.readlink(p) if p.is_symlink()
                else p.read_bytes() if p.is_file() else None, p.lstat().st_mode, p.lstat().st_mtime_ns)
                for p in self.resources.rglob('*')}

    def test_checked_in_pin_matches_official_release(self):
        script = HELPER.read_text()
        for pin in ('2b5251788b36fcbc476568b4eea8cb239f0a775759456f2ff9344a437c52f000',
                    '11ffbd44449218dc560fb0157cd1229c597bcdd90ac9e255bd7148fcc40d5b8a',
                    '7e12e5df4bae12cb21581ba157ced20e1986a0508dd10d0e8a4ab9a4cf94e85c'):
            self.assertIn(pin, script)
        self.assertNotIn('/latest', script); self.assertNotIn('/master/', script)
        self.assertIn('/yt-dlp_macos.zip', script)

    def test_check_missing_destination_is_read_only(self):
        result = self.run_script('--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.resources.exists()); self.assertFalse(self.calls.exists())

    def test_check_never_executes_or_changes_existing_resolver(self):
        self.existing()
        marker = self.root / 'unexpected-execution'
        (self.resources / 'yt-dlp').write_text(f'#!/bin/sh\ntouch "{marker}"\n')
        before = self.snapshot()
        result = self.run_script('--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(marker.exists()); self.assertFalse(self.calls.exists())
        self.assertEqual(before, self.snapshot())
        self.assertFalse(list(self.root.rglob('__pycache__')))

    def test_valid_closure_skips_all_downloads(self):
        self.existing()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.calls.exists())

    def test_same_version_with_damaged_extension_is_replaced(self):
        self.existing()
        (self.resources / '_internal/lib-dynload/extension.so').write_bytes(b'tampered')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.module.runtime_valid(self.resources))
        self.assertIn('/2026.10.21/yt-dlp_macos.zip', self.calls.read_text())
        self.assertFalse(any(self.resources.glob('.yt-dlp-download.*')))

    def test_wrong_license_is_repaired_without_runtime_download(self):
        self.existing()
        (self.resources / 'yt-dlp-LICENSE').write_bytes(b'wrong license')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.resources / 'yt-dlp-LICENSE').read_bytes(), LICENSE)
        calls = self.calls.read_text()
        self.assertIn('/2026.10.21/LICENSE', calls); self.assertNotIn('yt-dlp_macos', calls)

    def test_download_and_checksum_failures_preserve_entire_old_set(self):
        for failure in ('network', 'checksum', 'license-checksum'):
            with self.subTest(failure=failure):
                if self.resources.exists(): shutil.rmtree(self.resources)
                self.existing()
                (self.resources / 'yt-dlp').write_bytes(b'old binary')
                (self.resources / 'yt-dlp-LICENSE').write_bytes(b'old license')
                before = self.snapshot()
                result = self.run_script(failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(before, self.snapshot())
                self.assertFalse(any(self.resources.glob('.yt-dlp-download.*')))

    def test_framework_links_are_relative_and_preserve_python_bytes(self):
        self.assertEqual(os.readlink(self.normalized / '_internal/Python'),
                         'Python.framework/Versions/Current/Python')
        self.assertEqual((self.normalized / '_internal/Python').read_bytes(), NATIVE)
        self.assertEqual(os.readlink(self.normalized / '_internal/Python.framework/Versions/Current'), '3.14')

    def test_differing_flattened_framework_is_rejected(self):
        self.archive.write_bytes(archive_bytes({'_internal/Python.framework/Python': b'wrong Python'}))
        out = self.root / 'bad-framework'; out.mkdir()
        with self.assertRaisesRegex(RuntimeError, 'framework differs'):
            self.module.extract_runtime(self.archive, out)

    def test_archive_traversal_is_rejected(self):
        self.archive.write_bytes(archive_bytes({'_internal/../../outside': b'invalid'}))
        out = self.root / 'bad-path'; out.mkdir()
        with self.assertRaisesRegex(RuntimeError, 'archive member'):
            self.module.extract_runtime(self.archive, out)
        self.assertFalse((self.root / 'outside').exists())

    def test_install_refreshes_both_complete_copies(self):
        self.existing()
        app = self.root / 'fixture.app'
        for relative in self.module.RUNTIME_ROOTS:
            old = app / relative; old.mkdir(parents=True)
            (old / 'yt-dlp').write_bytes(b'stale single-file runtime')
        self.module.install(app)
        for relative in self.module.RUNTIME_ROOTS:
            self.assertTrue(self.module.runtime_valid(app / relative))
            self.assertTrue((app / relative / '_internal/THIRD_PARTY_LICENSES.txt').exists())

    def test_sign_covers_each_native_file_and_receipt_detects_data_tampering(self):
        self.existing()
        app = self.root / 'fixture.app'; self.module.install(app)
        with mock.patch.object(self.module, 'codesign') as signer:
            self.module.sign_or_verify(app, '-')
            signed = {Path(c.args[-1]) for c in signer.call_args_list if '--sign' in c.args}
            for relative in self.module.RUNTIME_ROOTS:
                root = app / relative
                self.assertTrue(set(self.module.native_files(root)).issubset(signed))
                self.assertIn(root / '_internal/Python.framework', signed)
            self.module.sign_or_verify(app, None)
            (app / self.module.RUNTIME_ROOTS[1] / '_internal/base_library.zip').write_bytes(b'tampered')
            with self.assertRaisesRegex(RuntimeError, 'changed after signing'):
                self.module.sign_or_verify(app, None)

    def test_signed_app_is_never_modified(self):
        self.existing()
        app = self.root / 'fixture.app'; (app / 'Contents/_CodeSignature').mkdir(parents=True)
        with self.assertRaisesRegex(RuntimeError, 'already signed'):
            self.module.install(app)


if __name__ == '__main__':
    unittest.main()
