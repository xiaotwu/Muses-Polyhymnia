"""Native dependency policy tests; no playback, Swift builds or signing required."""
import importlib.util
import json
from pathlib import Path
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


if __name__ == '__main__':
    unittest.main()
