"""Changelog media survives validation, release filing, and publication."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import changelog


class Videos(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        for name, value in {
            "LOG": root,
            "UNRELEASED": root / "unreleased",
            "WEB_JSON": root / "changelog.json",
            "CHANGELOG_MD": root / "CHANGELOG.md",
        }.items():
            p = patch.object(changelog, name, value)
            p.start()
            self.addCleanup(p.stop)
        self.folder = changelog.UNRELEASED / "fire"
        self.folder.mkdir(parents=True)
        (self.folder / "clip.mp4").write_bytes(b"video fixture")
        (self.folder / "poster.jpg").write_bytes(b"poster fixture")
        self.entry = changelog.UNRELEASED / "fire.md"
        self.header = '+++\ntitle = "Fire"\nsummary = "Fire spreads."\nkind = "new"\n'
        self.media = '\n[[videos]]\nfile = "clip.mp4"\nposter = "poster.jpg"\ncaption = "Flames spread."\n'
        self.write()

    def write(self, media=None):
        self.entry.write_text(self.header + (self.media if media is None else media) + '+++\nDetails.\n', encoding="utf-8")

    def test_release_preserves_media_and_writes_links(self):
        with patch.object(changelog, "pr_of", return_value=None):
            changelog.release("9.9.9")
        self.assertTrue((changelog.LOG / "v9.9.9/fire/clip.mp4").is_file())
        data = json.loads(changelog.WEB_JSON.read_text(encoding="utf-8"))
        video = data["releases"][0]["entries"][0]["videos"][0]
        self.assertTrue(video["url"].endswith("/v9.9.9/fire/clip.mp4"))
        self.assertTrue(video["poster"].endswith("/v9.9.9/fire/poster.jpg"))
        for text in [changelog.notes("9.9.9"), changelog.CHANGELOG_MD.read_text(encoding="utf-8")]:
            self.assertIn(f"[Watch: Flames spread.]({changelog.WEBSITE}/changelog/#v9.9.9)", text)

    def test_old_entries_need_no_video(self):
        self.write("")
        self.assertEqual(changelog.read_entry(self.entry)["videos"], [])

    def test_rejects_missing_unsupported_or_escaped_media_and_empty_caption(self):
        (self.folder / "clip.gif").write_bytes(b"gif")
        for old, new in [("clip.mp4", "missing.mp4"), ("clip.mp4", "clip.gif"),
                         ("clip.mp4", "../fire/clip.mp4"), ("poster.jpg", "missing.jpg"),
                         ("Flames spread.", "")]:
            with self.subTest(new=new):
                self.write(self.media.replace(old, new))
                with self.assertRaises(changelog.EntryError):
                    changelog.read_entry(self.entry)

    def test_rejects_oversized_clip(self):
        with patch.object(changelog, "MAX_VIDEO", 1):
            with self.assertRaises(changelog.EntryError):
                changelog.read_entry(self.entry)

    def test_rejects_malformed_video_tables(self):
        for media in ['videos = "clip.mp4"\n', 'videos = ["clip.mp4"]\n']:
            with self.subTest(media=media):
                self.write(media)
                with self.assertRaises(changelog.EntryError):
                    changelog.read_entry(self.entry)


if __name__ == "__main__":
    unittest.main()
