"""Development entrypoint and output ownership regressions, without real builds."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True


def load(path):
    spec = importlib.util.spec_from_file_location('packaging_guard_fixture', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class DevelopmentPackagingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.scripts = self.root / 'Scripts'
        self.scripts.mkdir()
        self.calls = self.root / 'calls.jsonl'
        self.env = os.environ.copy()
        self.env.update(PACKAGING_TEST_CALLS=str(self.calls), PYTHONDONTWRITEBYTECODE='1')
        self.env.pop('MUSES_BUNDLE_ID', None)
        self.env.pop('MUSES_MPV_DEPENDENCY_DIR', None)

    def executable(self, name, source):
        path = self.scripts / name
        path.write_text(source)
        path.chmod(0o755)
        return path

    def runner(self):
        # Replace OS launch tools only in the disposable copy. Any launch,
        # process termination or debugger call becomes observable fixture data.
        source = (ROOT / 'Scripts/build_and_run.sh').read_text()
        for name in ('open', 'log'):
            source = source.replace('/usr/bin/' + name, str(self.scripts / name))
        runner = self.executable('build_and_run.sh', source)
        for name in ('open', 'log', 'pkill', 'pgrep', 'codesign', 'swift', 'lldb'):
            self.executable(name, '#!/usr/bin/env python3\n'
                            'import json, os, sys\n'
                            'with open(os.environ["PACKAGING_TEST_CALLS"], "a") as out:\n'
                            '    out.write(json.dumps(sys.argv) + "\\n")\n')
        self.env['PATH'] = str(self.scripts) + os.pathsep + self.env['PATH']
        self.executable('build-app.sh', '''#!/usr/bin/env python3
import json, os, pathlib, shutil, sys
args = sys.argv[1:]
with open(os.environ['PACKAGING_TEST_CALLS'], 'a') as out:
    out.write(json.dumps(['packager', *args]) + '\\n')
if os.environ.get('PACKAGING_TEST_FAIL'): raise SystemExit(1)
app = pathlib.Path(args[args.index('--output') + 1])
if app.exists(): shutil.rmtree(app)
app.mkdir(parents=True)
(app / 'complete-debug-bundle').write_text('fresh complete assembly')
''')
        return runner

    def observed(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []

    def test_verify_rebuilds_stale_bundle_without_launch_or_process_kill(self):
        runner = self.runner()
        output = self.root / 'build/MusesDevelopment.app'
        output.mkdir(parents=True)
        (output / 'stale-single-file-runtime').write_text('old')
        result = subprocess.run([str(runner), '--verify'], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.observed(), [['packager', '--configuration', 'debug', '--identity', '-',
                         '--bundle-id', 'com.muses.acceptance.development', '--output', str(output)]])
        self.assertTrue((output / 'complete-debug-bundle').exists())
        self.assertFalse((output / 'stale-single-file-runtime').exists())
        self.assertIn('Verified development bundle:', result.stdout)

    def test_isolated_mode_uses_distinct_acceptance_identity_and_memory_store(self):
        runner = self.runner()
        result = subprocess.run([str(runner), '--isolated'], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.observed()
        self.assertEqual(calls[0][calls[0].index('--bundle-id') + 1], 'com.muses.acceptance.validation')
        output = self.root / 'build/MusesValidation.app'
        self.assertEqual(calls[0][calls[0].index('--output') + 1], str(output))
        self.assertEqual(Path(calls[1][0]).name, 'open')
        self.assertIn('MUSES_IN_MEMORY_STORE=1', calls[1])
        self.assertEqual(calls[1][-1], str(output))
        self.assertEqual(len(calls), 2)

    def test_failed_complete_packaging_never_launches(self):
        runner = self.runner()
        self.env['PACKAGING_TEST_FAIL'] = '1'
        result = subprocess.run([str(runner), 'run'], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(self.observed()), 1)

    def test_debugger_does_not_inherit_release_oauth_overrides(self):
        runner = self.runner()
        keys = ('MUSES_GOOGLE_OAUTH_CLIENT_ID', 'MUSES_GOOGLE_OAUTH_CLIENT_SECRET',
                'MUSES_GOOGLE_OAUTH_REDIRECT_URI')
        self.env.update({key: 'release-configuration-fixture' for key in keys})
        self.executable('lldb', '''#!/usr/bin/env python3
import json, os, sys
keys = ('MUSES_GOOGLE_OAUTH_CLIENT_ID', 'MUSES_GOOGLE_OAUTH_CLIENT_SECRET', 'MUSES_GOOGLE_OAUTH_REDIRECT_URI')
with open(os.environ['PACKAGING_TEST_CALLS'], 'a') as out:
    out.write(json.dumps({'tool': 'lldb', 'args': sys.argv[1:],
                          'oauth': {key: os.environ[key] for key in keys if key in os.environ}}) + '\\n')
''')
        result = subprocess.run([str(runner), '--debug'], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.observed()
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0][0], 'packager')
        self.assertEqual(calls[1], {'tool': 'lldb',
                         'args': ['--', str(self.root / 'build/MusesDevelopment.app/Contents/MacOS/Muses')],
                         'oauth': {}})

    def test_log_modes_filter_the_exact_new_application(self):
        runner = self.runner()
        binary = self.root / 'build/MusesDevelopment.app/Contents/MacOS/Muses'
        for mode, predicate in (
                ('--logs', f'processImagePath == "{binary}"'),
                ('--telemetry', f'subsystem == "com.muses.app" && processImagePath == "{binary}"')):
            with self.subTest(mode=mode):
                if self.calls.exists(): self.calls.unlink()
                result = subprocess.run([str(runner), mode], env=self.env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = self.observed()
                self.assertEqual(len(calls), 3)
                self.assertEqual(Path(calls[1][0]).name, 'open')
                self.assertEqual(Path(calls[2][0]).name, 'log')
                self.assertEqual(calls[2][-2:], ['--predicate', predicate])

    def packager(self):
        script = self.scripts / 'build-app.sh'
        shutil.copy2(ROOT / 'Scripts/build-app.sh', script)
        self.executable('check-app-not-running.py', 'import os\n'
                        'raise SystemExit(1 if os.environ.get("PACKAGING_TEST_RUNNING") else 0)\n')
        self.executable('bundle-mpv.py', 'raise SystemExit(0)\n')
        self.executable('copy-ytdlp.sh', '#!/bin/sh\necho unexpected-download > changed-input\nexit 99\n')
        return script

    def test_invalid_configuration_or_nonacceptance_override_fails_before_changes(self):
        script = self.packager()
        for arguments in (['--configuration', 'Debug'], ['--configuration'],
                          ['--bundle-id', 'com.muses.app'], ['--bundle-id', 'com.muses.validation'],
                          ['--bundle-id', 'com.muses.acceptance.bad/id']):
            with self.subTest(arguments=arguments):
                result = subprocess.run([str(script), *arguments], env=self.env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse((self.root / 'changed-input').exists())
                self.assertFalse((self.root / 'build').exists())

    def test_missing_dependency_does_not_change_old_output_or_inputs(self):
        script = self.packager()
        output = self.root / 'old.app'
        output.mkdir()
        marker = output / 'old-signature'; marker.write_text('preserve')
        result = subprocess.run([str(script), '--output', str(output)], env=self.env,
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('MUSES_MPV_DEPENDENCY_DIR', result.stderr)
        self.assertEqual(marker.read_text(), 'preserve')
        self.assertFalse((self.root / 'changed-input').exists())

    def test_installed_output_and_parent_symlink_are_rejected_before_dependencies(self):
        script = self.packager()
        installed = self.root / 'installed'
        installed.symlink_to('/Applications', target_is_directory=True)
        for output in ('/Applications/Muses.app', str(installed / 'Muses.app')):
            with self.subTest(output=output):
                result = subprocess.run([str(script), '--output', output], env=self.env,
                                        capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('outside /Applications', result.stderr)
                self.assertNotIn('MUSES_MPV_DEPENDENCY_DIR', result.stderr)
                self.assertFalse((self.root / 'changed-input').exists())
                self.assertFalse((self.root / 'build').exists())

    def test_missing_matching_metadata_fails_before_packaging_with_actionable_command(self):
        script = self.packager()
        dependency = self.root / 'dependency'; dependency.mkdir()
        (dependency / 'manifest.json').write_text('{}')
        self.env['MUSES_MPV_DEPENDENCY_DIR'] = str(dependency)
        for configuration, title in (('debug', 'Debug'), ('release', 'Release')):
            result = subprocess.run([str(script), '--configuration', configuration], env=self.env,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('xcodebuild -scheme Muses -configuration ' + title, result.stderr)
            self.assertFalse((self.root / 'changed-input').exists())
            self.assertFalse((self.root / 'build').exists())

    def test_running_output_is_rejected_before_download_or_replacement(self):
        script = self.packager()
        dependency = self.root / 'dependency'; dependency.mkdir()
        (dependency / 'manifest.json').write_text('{}')
        self.env.update(MUSES_MPV_DEPENDENCY_DIR=str(dependency), PACKAGING_TEST_RUNNING='1')
        result = subprocess.run([str(script)], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'changed-input').exists())
        self.assertFalse((self.root / 'build').exists())

    def test_release_metadata_cannot_satisfy_debug_and_release_stays_the_default(self):
        script = self.packager()
        dependency = self.root / 'dependency'; dependency.mkdir()
        (dependency / 'manifest.json').write_text('{}')
        self.env['MUSES_MPV_DEPENDENCY_DIR'] = str(dependency)
        metadata = self.root / '.build/out/Build/Intermediates.noindex/Muses.build/Release/Muses.build/Objects-normal/arm64/Muses.swiftconstvalues'
        metadata.parent.mkdir(parents=True)
        metadata.write_text('fixture compiler metadata')
        result = subprocess.run([str(script), '--configuration', 'debug'], env=self.env,
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('configuration Debug', result.stderr)
        self.assertFalse((self.root / 'changed-input').exists())
        # The valid default reaches only the fixture downloader, which stops
        # before any compiler, signing tool or app assembly can run.
        result = subprocess.run([str(script)], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 99, result.stderr)
        self.assertTrue((self.root / 'changed-input').exists())


class ApplicationProcessGuardTests(unittest.TestCase):
    def test_exact_bundle_includes_helpers_but_allows_other_applications(self):
        guard = load(ROOT / 'Scripts/check-app-not-running.py')
        app = Path('/tmp/MusesDevelopment.app')
        processes = [(1, Path('/Applications/Muses.app/Contents/MacOS/Muses')),
                     (2, Path('/tmp/MusesDevelopment.app/Contents/MacOS/Muses')),
                     (3, Path('/tmp/MusesDevelopment.app/Contents/Helpers/deno')),
                     (4, Path('/tmp/MusesDevelopment.app-other/Contents/MacOS/Muses'))]
        self.assertEqual(guard.matching_processes(app, processes), [2, 3])
        with mock.patch.object(guard, 'executable_paths', return_value=iter(processes)):
            with self.assertRaisesRegex(RuntimeError, 'PID 2, 3'):
                guard.check(app)
        with mock.patch.object(guard, 'executable_paths', return_value=iter([processes[0], processes[3]])):
            guard.check(app)


if __name__ == '__main__':
    unittest.main()
