"""Check that original legal text and custom Qt attribution files survive packaging."""
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('legal_notices', ROOT / 'scripts/package-legal-notices.py')
legal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(legal)


class LegalNoticesTests(unittest.TestCase):
    def test_preserves_original_copyright_and_custom_license(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            original = legal.CACHE
            legal.CACHE = folder
            try:
                attribution = json.dumps({'Name': 'Fixture library', 'Copyright': 'Copyright 1998 Original Author',
                                          'LicenseFile': '../rights/TERMS.txt'}).encode()
                attribution = attribution.replace(b'Original Author', b'Original "Author"\tand contributors')
                terms = b'Original copyright and permission notice.\n'
                with tarfile.open(folder / 'fixture.tar.gz', 'w:gz') as archive:
                    for name, data in [('upstream/src/qt_attribution.json', attribution), ('upstream/rights/TERMS.txt', terms),
                                       ('upstream/LICENSES/BSD-3-Clause.txt', terms), ('upstream/build_recipe.py', terms)]:
                        info = tarfile.TarInfo(name); info.size = len(data)
                        archive.addfile(info, io.BytesIO(data))
                result = legal.collect_archive({'id': 'fixture', 'name': 'Fixture library', 'archive': 'fixture.tar.gz',
                                                'notice_paths': ['build_recipe.py']}, folder / 'notices')
                self.assertEqual((folder / 'notices/components/fixture/rights/TERMS.txt').read_bytes(), terms)
                self.assertEqual((folder / 'notices/components/fixture/LICENSES/BSD-3-Clause.txt').read_bytes(), terms)
                self.assertEqual((folder / 'notices/components/fixture/src/qt_attribution.json').read_bytes(), attribution)
                self.assertEqual((folder / 'notices/components/fixture/build_recipe.py').read_bytes(), terms)
                self.assertEqual(len(result['notices']), 4)
            finally:
                legal.CACHE = original

    def test_preserves_bundled_font_notice(self):
        notice = legal.font_notices(ROOT / 'app/ModeSeven.ttf')
        self.assertIn('1998 Andrew', notice)
        self.assertIn('Freely distributable.', notice)


if __name__ == '__main__':
    unittest.main()
