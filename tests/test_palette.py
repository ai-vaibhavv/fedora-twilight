import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('palette', ROOT / 'scripts/palette-from-wallpaper.py')
palette = importlib.util.module_from_spec(spec)
spec.loader.exec_module(palette)


class PaletteTests(unittest.TestCase):
    def test_solid_and_monochrome_images(self):
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / 'wall paper.png'
            for colour in ('white', 'black', 'gray', 'red', 'green', 'blue', '#808000'):
                Image.new('RGB', (20, 20), colour).save(image)
                result = palette.suggest(image)
                self.assertEqual(result, palette.suggest(image))
                for key in ('BASE', 'TEXT', 'ACCENT', 'CLOSE', 'MINIMIZE', 'MAXIMIZE'):
                    self.assertRegex(result[key], r'^#[0-9A-F]{6}$')
                self.assertEqual(len({result[k] for k in ('CLOSE', 'MINIMIZE', 'MAXIMIZE')}), 3)

    def test_output_preserves_default_palette(self):
        before = (ROOT / 'palette.conf').read_bytes()
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / 'yellow wallpaper.jpg'
            target = Path(tmp) / 'palette.conf'
            Image.new('RGB', (30, 30), '#dac124').save(image)
            result = subprocess.run(['python3', str(ROOT / 'scripts/palette-from-wallpaper.py'), str(image), '--output', str(target)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('GNOME_ACCENT=yellow', target.read_text())
            self.assertIn('LOCK_CLOCK_X=0.76', target.read_text())
        self.assertEqual(before, (ROOT / 'palette.conf').read_bytes())

    def test_invalid_image_is_readable_error(self):
        result = subprocess.run(['python3', str(ROOT / 'scripts/palette-from-wallpaper.py'), '/does/not/exist'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Cannot read wallpaper', result.stderr)
        self.assertNotIn('Traceback', result.stderr)

    def test_dry_run_and_argument_errors_do_not_write(self):
        before = (ROOT / 'palette.conf').read_bytes()
        for args, success in ((['--dry-run'], True), (['--wallpaper'], False), (['--only'], False), (['--only', 'gtk,unknown'], False), (['--auto-palette'], False), (['--only', 'gtk,'], False)):
            result = subprocess.run(['bash', str(ROOT / 'install.sh'), *args], capture_output=True, text=True)
            self.assertEqual(result.returncode == 0, success, result.stderr)
            self.assertNotIn('unbound variable', result.stderr)
        self.assertEqual(before, (ROOT / 'palette.conf').read_bytes())


if __name__ == '__main__':
    unittest.main()
