"""Pinned resolver downloader tests in a temporary checkout, without network."""
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'Scripts/copy-ytdlp.sh'
BINARY = b'#!/bin/sh\necho 2026.10.21\n'
LICENSE = b'isolated downloader license fixture\n'


class ResolverBundleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'Scripts').mkdir()
        self.resources = self.root / 'Sources/Muses/Resources'
        script = SCRIPT.read_text()
        script = re.sub(r'^SHA256="[0-9a-f]+"',
                        'SHA256="' + hashlib.sha256(BINARY).hexdigest() + '"', script, flags=re.M)
        script = re.sub(r'^LICENSE_SHA256="[0-9a-f]+"',
                        'LICENSE_SHA256="' + hashlib.sha256(LICENSE).hexdigest() + '"', script, flags=re.M)
        self.script = self.root / 'Scripts/copy-ytdlp.sh'
        self.script.write_text(script)
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
source=pathlib.Path(os.environ['RESOLVER_TEST_FIXTURES']) / ('LICENSE' if url.endswith('/LICENSE') else 'binary')
failure=os.environ.get('RESOLVER_TEST_FAIL')
corrupt=failure == 'checksum' or (failure == 'license-checksum' and url.endswith('/LICENSE'))
output.write_bytes(b'truncated' if corrupt else source.read_bytes())
''')
        fake_curl.chmod(0o755)
        fixtures = self.root / 'fixtures'; fixtures.mkdir()
        (fixtures / 'binary').write_bytes(BINARY); (fixtures / 'LICENSE').write_bytes(LICENSE)
        self.env = os.environ.copy()
        self.env.update(PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        RESOLVER_TEST_CALLS=str(self.calls), RESOLVER_TEST_FIXTURES=str(fixtures))

    def run_script(self, *arguments, failure=None):
        env = self.env.copy()
        if failure: env['RESOLVER_TEST_FAIL'] = failure
        return subprocess.run(['/bin/bash', str(self.script), *arguments], cwd=self.root,
                              env=env, capture_output=True, text=True)

    def existing(self, binary=BINARY, license=LICENSE):
        self.resources.mkdir(parents=True)
        (self.resources / 'yt-dlp').write_bytes(binary)
        (self.resources / 'yt-dlp').chmod(0o755)
        (self.resources / 'yt-dlp-LICENSE').write_bytes(license)

    def test_checked_in_pin_matches_official_release(self):
        script = SCRIPT.read_text()
        self.assertIn('VERSION="2026.10.21"', script)
        self.assertIn('SHA256="7a6fe71d7d680f1fb0ac18d4949873d77db2859e90017c0f44bd94b23be4ee40"', script)
        self.assertIn('LICENSE_SHA256="7e12e5df4bae12cb21581ba157ced20e1986a0508dd10d0e8a4ab9a4cf94e85c"', script)
        self.assertNotIn('/latest', script)
        self.assertNotIn('/master/', script)

    def test_check_missing_destination_is_read_only(self):
        result = self.run_script('--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.resources.exists())
        self.assertFalse(self.calls.exists())

    def test_check_never_executes_or_changes_existing_resolver(self):
        marker = self.root / 'unexpected-execution'
        self.existing(binary=('#!/bin/sh\ntouch "' + str(marker) + '"\necho 2026.10.21\n').encode())
        before = {p.name: (p.read_bytes(), p.stat().st_mode, p.stat().st_mtime_ns)
                  for p in self.resources.iterdir()}
        result = self.run_script('--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(marker.exists()); self.assertFalse(self.calls.exists())
        self.assertEqual(before, {p.name: (p.read_bytes(), p.stat().st_mode, p.stat().st_mtime_ns)
                                 for p in self.resources.iterdir()})

    def test_valid_bytes_skip_all_downloads(self):
        self.existing()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.calls.exists())

    def test_same_version_with_wrong_hash_is_replaced(self):
        self.existing(binary=BINARY + b'# modified bytes\n')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.resources / 'yt-dlp').read_bytes(), BINARY)
        self.assertIn('/2026.10.21/yt-dlp_macos', self.calls.read_text())
        self.assertFalse(any(self.resources.glob('.yt-dlp-download.*')))

    def test_wrong_license_is_repaired_without_binary_download(self):
        self.existing(license=b'wrong license')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.resources / 'yt-dlp-LICENSE').read_bytes(), LICENSE)
        calls = self.calls.read_text()
        self.assertIn('/2026.10.21/LICENSE', calls)
        self.assertNotIn('yt-dlp_macos', calls)

    def test_download_and_checksum_failures_preserve_resources(self):
        for failure in ('network', 'checksum', 'license-checksum'):
            with self.subTest(failure=failure):
                if self.resources.exists(): shutil.rmtree(self.resources)
                self.existing(binary=b'old binary', license=b'old license')
                result = self.run_script(failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((self.resources / 'yt-dlp').read_bytes(), b'old binary')
                self.assertEqual((self.resources / 'yt-dlp-LICENSE').read_bytes(), b'old license')
                self.assertFalse(any(self.resources.glob('.yt-dlp-download.*')))


if __name__ == '__main__':
    unittest.main()
