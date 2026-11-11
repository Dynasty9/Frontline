"""Release filing and altered evidence must not silently bypass presentation review."""
import hashlib
import json
from pathlib import Path
import tempfile
import subprocess
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


class SeparateRecords(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.records = self.root / 'tools/showcase/entries'
        self.records.mkdir(parents=True)
        self.catalog = self.records.parent / 'catalog.json'
        self.catalog.write_text(json.dumps({'schema': 1, 'entries': [], 'layout_capture': {'preserved': True}}))
        (self.root / 'changelog/unreleased').mkdir(parents=True)

    def add(self, name):
        self.records.mkdir(parents=True, exist_ok=True)
        (self.root / 'changelog/unreleased').mkdir(parents=True, exist_ok=True)
        (self.root / f'changelog/unreleased/{name}.md').write_text(
            '+++\ntitle="Feature"\nsummary="An outcome."\nkind="fixed"\n+++\nDetails.\n')
        record = {'entry': f'changelog/unreleased/{name}.md', 'medium': 'text',
                  'rationale': 'Invisible fix', 'stage': 'text', 'source_ref': 'abc123',
                  'sources': [], 'output': None}
        (self.records / f'{name}.json').write_text(json.dumps(record))
        return record

    def test_legacy_and_separate_records_keep_duplicate_checks(self):
        legacy = self.add('legacy')
        (self.records / 'legacy.json').unlink()
        self.catalog.write_text(json.dumps({'entries': [legacy]}))
        self.add('new')
        with patch.object(audit, 'ROOT', self.root):
            self.assertEqual(audit.audit()[1], [])
            (self.records / 'duplicate.json').write_text(json.dumps(legacy))
            self.assertIn('Duplicate entry: changelog/unreleased/legacy.md', audit.audit()[1])

    def test_release_filing_and_hash_checks_apply_to_separate_records(self):
        record = self.add('feature')
        asset = self.root / 'changelog/unreleased/feature/source.jpg'
        asset.parent.mkdir()
        asset.write_bytes(b'evidence')
        record['sources'] = [{'file': 'changelog/unreleased/feature/source.jpg',
                              'sha256': hashlib.sha256(asset.read_bytes()).hexdigest()}]
        (self.records / 'feature.json').write_text(json.dumps(record))
        (self.root / 'changelog/unreleased').rename(self.root / 'changelog/v9.9.9')
        with patch.object(audit, 'ROOT', self.root):
            self.assertEqual(audit.audit()[1], [])
            (self.root / 'changelog/v9.9.9/feature/source.jpg').write_bytes(b'changed')
            self.assertTrue(any('Source changed' in e for e in audit.audit()[1]))

    def test_independent_branches_merge_without_a_catalog_conflict(self):
        def git(*args):
            return subprocess.run(['git', *args], cwd=self.root, check=True, capture_output=True, text=True)
        git('init', '-q', '-b', 'main')
        git('config', 'user.name', 'Test')
        git('config', 'user.email', 'test@example.com')
        git('add', '.')
        git('commit', '-qm', 'Base')
        git('checkout', '-qb', 'first')
        self.add('first')
        git('add', '.')
        git('commit', '-qm', 'First change')
        git('checkout', '-qb', 'second', 'main')
        self.add('second')
        git('add', '.')
        git('commit', '-qm', 'Second change')
        git('merge', '--no-edit', 'first')
        with patch.object(audit, 'ROOT', self.root):
            catalog, errors = audit.audit()
        self.assertEqual(errors, [])
        self.assertEqual([r['entry'] for r in catalog['entries']],
                         ['changelog/unreleased/first.md', 'changelog/unreleased/second.md'])
        self.assertEqual(catalog['layout_capture'], {'preserved': True})


if __name__ == '__main__':
    unittest.main()
