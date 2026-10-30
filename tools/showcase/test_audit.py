"""Release filing and altered evidence must not silently bypass presentation review."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import audit


class PresentationAudit(unittest.TestCase):
    def test_filed_release_follows_assets_and_still_detects_tampering(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            entry = root / 'changelog/v9.9.9/feature.md'
            entry.parent.mkdir(parents=True)
            entry.write_text('+++\ntitle="Feature"\nsummary="An outcome."\nkind="new"\n'
                             '[[screenshots]]\nfile="overview.jpg"\ncaption="Result."\n+++\nDetails.\n')
            image = entry.with_suffix('') / 'overview.jpg'
            image.parent.mkdir()
            image.write_bytes(b'original archived evidence')
            catalog = root / 'tools/showcase/catalog.json'
            catalog.parent.mkdir(parents=True)
            catalog.write_text(json.dumps({'entries': [{
                'entry': 'changelog/unreleased/feature.md', 'medium': 'still',
                'rationale': 'Show the visible result', 'stage': 'archive-plate', 'source_ref': 'abc123',
                'sources': [{'file': 'changelog/unreleased/feature/overview.jpg',
                             'sha256': hashlib.sha256(image.read_bytes()).hexdigest()}],
                'output': 'changelog/unreleased/feature/overview.jpg',
            }]}))
            with patch.object(audit, 'ROOT', root):
                self.assertEqual(audit.audit()[1], [])
                image.write_bytes(b'changed evidence')
                self.assertTrue(any('Source changed' in e for e in audit.audit()[1]))
                (entry.parent / 'unreviewed.md').write_text(entry.read_text())
                self.assertTrue(any('Presentation decision needed' in e for e in audit.audit()[1]))


if __name__ == '__main__':
    unittest.main()
