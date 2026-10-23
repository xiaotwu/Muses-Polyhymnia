"""Native dependency policy tests; no playback, Swift builds or signing required."""
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('bundle_mpv', ROOT / 'Scripts/bundle-mpv.py')
bundle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)


class MpvClosureTests(unittest.TestCase):
    def check_audit(self, dependency, architecture='arm64', minos='26.0'):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            path = directory / 'libmpv.2.dylib'; path.touch()
            (directory / 'libavutil.60.dylib').touch()
            def output(*args):
                if '-archs' in args:
                    return architecture + '\n'
                if '-l' in args:
                    return f'cmd LC_BUILD_VERSION\n cmdsize 32\n platform 1\n minos {minos}\n sdk 26.0\n'
                if '-D' in args:
                    return str(path) + ':\n@rpath/libmpv.2.dylib\n'
                if '-L' in args:
                    return str(path) + ':\n\t@rpath/libmpv.2.dylib (compatibility version 2.0.0)\n\t' + dependency + ' (compatibility version 1.0.0)\n'
                raise AssertionError(args)
            with patch.object(bundle, 'run', side_effect=output):
                bundle.audit_library(path, directory)

    def test_accepts_closed_loader_relative_dependency(self):
        self.check_audit('@loader_path/libavutil.60.dylib')

    def test_accepts_apple_system_dependency(self):
        self.check_audit('/usr/lib/libSystem.B.dylib')

    def test_rejects_homebrew_and_unresolved_rpath(self):
        for dependency in ('/opt/homebrew/lib/libavutil.60.dylib', '@rpath/libavutil.60.dylib',
                           '@loader_path/../libavutil.60.dylib'):
            with self.subTest(dependency=dependency), self.assertRaises(RuntimeError):
                self.check_audit(dependency)

    def test_rejects_wrong_architecture_or_newer_os(self):
        with self.assertRaises(RuntimeError):
            self.check_audit('/usr/lib/libSystem.B.dylib', architecture='x86_64')
        with self.assertRaises(RuntimeError):
            self.check_audit('/usr/lib/libSystem.B.dylib', minos='27.0')

    def test_rejects_signed_destination_before_copy(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / 'Muses.app'
            (app / 'Contents/_CodeSignature').mkdir(parents=True)
            with self.assertRaisesRegex(RuntimeError, 'already signed'):
                bundle.install(Path(temporary), app)

    def test_every_locked_source_has_digest_and_license(self):
        sources = json.loads((ROOT / 'Dependencies/mpv/source-lock.json').read_text())
        self.assertTrue({'mpv', 'ffmpeg', 'libass', 'libplacebo'} <= {s['name'] for s in sources})
        for source in sources:
            self.assertRegex(source['sha256'], '^[0-9a-f]{64}$')
            self.assertTrue(source['url'].startswith('https://'))
            self.assertTrue(source['license'])


class MpvDependencyPreflightTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.work = self.root / 'prepared'
        self.library = self.work / 'prefix/lib/libmpv.2.dylib'
        self.library.parent.mkdir(parents=True)
        self.library.write_bytes(b'prepared library fixture')
        (self.library.parent / 'libmpv.dylib').symlink_to(self.library.name)
        self.source = self.work / 'corresponding-source/source.tar'
        self.source.parent.mkdir()
        self.source.write_bytes(b'corresponding source fixture')
        self.notice = self.work / 'notices/mpv/LICENSE'
        self.notice.parent.mkdir(parents=True)
        self.notice.write_text('license fixture')
        locks = self.root / 'Dependencies/mpv'
        locks.mkdir(parents=True)
        sources = [{'name': 'mpv', 'archive': self.source.name,
                    'sha256': hashlib.sha256(self.source.read_bytes()).hexdigest()}]
        for name, value in (('source-lock.json', sources), ('tool-lock.json', {}), ('patch-lock.json', {})):
            (locks / name).write_text(json.dumps(value))
        manifest = dict(sources=sources, architecture='arm64', tools={}, patches={},
                        licenseGuards={'mpvGPL': False, 'ffmpegGPL': False,
                                       'ffmpegNonfree': False, 'ffmpegVersion3': False},
                        libraries={self.library.name: hashlib.sha256(self.library.read_bytes()).hexdigest()})
        (self.work / 'manifest.json').write_text(json.dumps(manifest))
        self.patch = patch.object(bundle, 'REPO', self.root)
        self.patch.start(); self.addCleanup(self.patch.stop)

    def snapshot(self):
        return {str(path.relative_to(self.root)): (path.lstat().st_mode, path.lstat().st_mtime_ns,
                os.readlink(path) if path.is_symlink() else path.read_bytes() if path.is_file() else None)
                for path in self.root.rglob('*')}

    def test_valid_preflight_and_cli_are_read_only_and_need_no_app(self):
        bundle.validate_dependency(self.work)
        script = self.root / 'Scripts/bundle-mpv.py'
        script.parent.mkdir()
        shutil.copy2(ROOT / 'Scripts/bundle-mpv.py', script)
        before = self.snapshot()
        result = subprocess.run([sys.executable, '-B', str(script), 'check',
                                 '--dependency-dir', str(self.work)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, self.snapshot())

    def test_missing_or_changed_library_is_rejected_without_creating_app(self):
        for damaged in (False, True):
            with self.subTest(damaged=damaged):
                if damaged:
                    self.library.write_bytes(b'changed library')
                else:
                    self.library.unlink()
                before = self.snapshot()
                with self.assertRaises(RuntimeError):
                    bundle.validate_dependency(self.work)
                self.assertEqual(before, self.snapshot())

    def test_missing_source_or_license_does_not_create_destination(self):
        for path in (self.source, self.notice):
            with self.subTest(path=path.name):
                data = path.read_bytes()
                path.unlink()
                app = self.root / 'new.app'
                with self.assertRaises((OSError, RuntimeError)):
                    bundle.install(self.work, app)
                self.assertFalse(app.exists())
                path.write_bytes(data)

    def test_escaping_alias_is_rejected_before_destination_is_created(self):
        alias = self.library.parent / 'libmpv.dylib'
        alias.unlink()
        alias.symlink_to(self.source)
        app = self.root / 'new.app'
        with self.assertRaisesRegex(RuntimeError, 'Escaping/untracked'):
            bundle.install(self.work, app)
        self.assertFalse(app.exists())


if __name__ == '__main__':
    unittest.main()
