import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def sandbox(tmp):
    """A throwaway copy of the checkout and an empty home folder."""
    repo = tmp / 'repo'
    shutil.copytree(ROOT, repo, ignore=shutil.ignore_patterns('.git', '.twilight', 'docs', '__pycache__'))
    (repo / '.twilight').mkdir()
    home = tmp / 'home'
    home.mkdir()
    shims = tmp / 'bin'
    shims.mkdir()
    env = dict(os.environ, HOME=str(home), PATH=f'{shims}:{os.environ["PATH"]}')
    return repo, home, shims, env


def install(repo, env, *args):
    return subprocess.run(['bash', str(repo / 'install.sh'), '--no-sudo', *args],
                          capture_output=True, text=True, env=env)


class FailureIsolationTests(unittest.TestCase):
    def test_failed_step_is_traced_and_later_steps_still_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, home, shims, env = sandbox(Path(tmp))
            shutil.copy(repo / 'palette.conf', repo / '.twilight/palette.conf')
            (shims / 'fc-cache').write_text('#!/bin/sh\nexit 3\n')
            (shims / 'fc-cache').chmod(0o755)

            result = install(repo, env, '--keep-palette', '--only', 'fonts,sounds')

            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn('Failed (exit 3): fc-cache', result.stderr)
            self.assertIn('at step_fonts (install.sh:', result.stderr)
            self.assertIn('Failed steps: fonts', result.stderr)
            self.assertIn('--keep-palette --only fonts', result.stderr)
            self.assertTrue((home / '.local/share/sounds/Twilight').is_dir())

    @unittest.skipIf(subprocess.run(['sudo', '-n', 'true'], capture_output=True).returncode == 0,
                     'sudo credentials are cached')
    def test_sudo_without_a_terminal_stops_before_changing_anything(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, home, shims, env = sandbox(Path(tmp))
            shutil.copy(repo / 'palette.conf', repo / '.twilight/palette.conf')
            result = subprocess.run(['bash', str(repo / 'install.sh'), '--only', 'lockscreen'],
                                    capture_output=True, text=True, env=env, stdin=subprocess.DEVNULL)
            self.assertEqual(result.returncode, 1)
            self.assertIn('no terminal to ask for the password', result.stderr)
            self.assertFalse((repo / '.twilight/backups').exists())


class PaletteSelectionTests(unittest.TestCase):
    def test_partial_run_keeps_a_wallpaper_palette(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, home, shims, env = sandbox(Path(tmp))
            active = repo / '.twilight/palette.conf'
            # An install from before palette-source existed, with generated colours.
            active.write_text((repo / 'palette.conf').read_text().replace('GNOME_ACCENT=', 'GNOME_ACCENT=yellow\n#'))
            generated = active.read_text()

            result = install(repo, env, '--only', 'sounds')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(active.read_text(), generated)
            self.assertEqual((repo / '.twilight/state/palette-source').read_text().strip(), 'wallpaper')

            result = install(repo, env, '--only', 'sounds')
            self.assertEqual(active.read_text(), generated)

    def test_partial_run_follows_edits_to_the_checkout_palette(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, home, shims, env = sandbox(Path(tmp))
            active = repo / '.twilight/palette.conf'
            shutil.copy(repo / 'palette.conf', active)
            self.assertEqual(install(repo, env, '--only', 'sounds').returncode, 0)

            edited = (repo / 'palette.conf').read_text().replace('CLOSE=', 'CLOSE=#123456\n#')
            (repo / 'palette.conf').write_text(edited)
            self.assertEqual(install(repo, env, '--only', 'sounds').returncode, 0)
            self.assertEqual(active.read_text(), edited)
            self.assertEqual((repo / '.twilight/state/palette-source').read_text().strip(), 'repo')

    def test_only_ten_backups_are_kept(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, home, shims, env = sandbox(Path(tmp))
            shutil.copy(repo / 'palette.conf', repo / '.twilight/palette.conf')
            for i in range(12):
                (repo / f'.twilight/backups/20200101-0000{i:02d}-1').mkdir(parents=True)
            self.assertEqual(install(repo, env, '--only', 'sounds').returncode, 0)
            kept = sorted(p.name for p in (repo / '.twilight/backups').iterdir())
            self.assertEqual(len(kept), 10)
            self.assertNotIn('20200101-000000-1', kept)


class UninstallTests(unittest.TestCase):
    def test_uninstall_removes_twilight_and_keeps_user_css(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, home, shims, env = sandbox(Path(tmp))
            shutil.copy(repo / 'palette.conf', repo / '.twilight/palette.conf')
            # Never touch the real session's settings or services.
            log = Path(tmp) / 'calls.log'
            for cmd in ('dconf', 'gsettings', 'systemctl'):
                (shims / cmd).write_text(f'#!/bin/sh\necho "{cmd} $*" >> "{log}"\n')
                (shims / cmd).chmod(0o755)
            (shims / 'gsettings').write_text(
                f'#!/bin/sh\necho "gsettings $*" >> "{log}"\n'
                '[ "$1 $3" = "get enabled-extensions" ] && '
                'echo "[\'burn-my-windows@schneegans.github.com\', \'mine@example.org\']"\nexit 0\n')
            self.assertEqual(install(repo, env, '--only', 'sounds,gtk').returncode, 0)
            gtk3 = home / '.config/gtk-3.0/gtk.css'
            gtk3.write_text('window { margin: 1px; }\n' + gtk3.read_text())
            self.assertTrue((home / '.local/share/sounds/Twilight').is_dir())

            dry = install(repo, env, '--uninstall', '--dry-run')
            self.assertEqual(dry.returncode, 0, dry.stderr)
            self.assertTrue((home / '.local/share/sounds/Twilight').is_dir())

            result = install(repo, env, '--uninstall')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((home / '.local/share/sounds/Twilight').exists())
            self.assertEqual(gtk3.read_text(), 'window { margin: 1px; }\n')
            self.assertFalse((home / '.config/gtk-4.0/gtk.css').exists())
            calls = log.read_text()
            self.assertIn('dconf reset /org/gnome/desktop/wm/preferences/button-layout', calls)
            self.assertIn('systemctl --user disable --now twilight-heal.service', calls)
            self.assertIn("gsettings set org.gnome.shell enabled-extensions ['mine@example.org']", calls)

            again = install(repo, env, '--uninstall')
            self.assertEqual(again.returncode, 0, again.stderr)

    def test_uninstall_refuses_other_options(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo, home, shims, env = sandbox(Path(tmp))
            result = install(repo, env, '--uninstall', '--only', 'gtk')
            self.assertEqual(result.returncode, 1)
            self.assertIn('--uninstall on its own', result.stderr)


if __name__ == '__main__':
    unittest.main()
