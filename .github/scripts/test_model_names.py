import contextlib
import io
import subprocess
import tempfile
import unittest
from pathlib import Path

from check_model_names import ATTRIBUTION_ALLOWLIST, findings, main


class ModelNames(unittest.TestCase):
    def test_names_and_variants(self):
        for name in ("ChatGPT", "chat-gpt", "CHAT GPT", "chat_gpt", "Claude",
                     "OpenAI", "Anthropic", "Codex", "GitHub Copilot", "Gemini",
                     "DeepSeek", "Llama3", "Mistral", "Grok", "Qwen", "Gemma",
                     "gpt-4o", "GPT5.1", "generated_by_claude"):
            with self.subTest(name=name):
                self.assertTrue(list(findings("web/src/page.tsx", name.encode())))

    def test_normal_words_and_binary(self):
        self.assertEqual([], list(findings("README.md", b"AI commander, cockpit, llamas, codexes")))
        self.assertEqual([], list(findings("image.png", b"\0Claude")))

    def test_attribution_without_known_model_names(self):
        for phrase in ("Made by Someone", "Created with Assistant", "generated_by_tool",
                       "Written by Helper", "Co-authored-by: Helper <bot@example.com>",
                       "Built by Helper", "Developed by Helper", "Designed by Helper",
                       "Powered by Helper", "Coded with Helper", "Thanks to Helper",
                       "Credits to Helper", "Author: Helper", "AI-generated",
                       "AI assisted", "With the help of Helper", "with assistance from Helper"):
            with self.subTest(phrase=phrase):
                result = list(findings("README.md", phrase.encode()))
                self.assertTrue(any("unreviewed attribution" in item for item in result))

    def test_reviewed_lines_cannot_hide_new_credits(self):
        for path, lines in ATTRIBUTION_ALLOWLIST.items():
            for line in lines:
                with self.subTest(path=path, line=line):
                    self.assertEqual([], list(findings(path, line.encode())))
                    self.assertTrue(list(findings(path, (line + " Made by Helper").encode())))
                    self.assertTrue(list(findings("new-file.md", line.encode())))

    def test_exceptions_are_narrow(self):
        for path in ("AGENTS.md", ".agents/skills/demo.md", ".claude/settings.json",
                     "tools/showcase/entries/example.json"):
            self.assertEqual([], list(findings(path, b"Claude")))
        for path in ("scripts/game/unit.gd", "web/README.md", "docs/FEATURES.md",
                     "changelog/unreleased/example.md", "web/public/AGENTS.md",
                     "tools/showcase/entries/README.md", "tools/showcase/entries/nested/example.json"):
            self.assertEqual([f"{path}:2: prohibited model/assistant name: Claude"],
                             list(findings(path, b"first line\nClaude")))

    def test_full_tracked_tree_and_exit_status(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            subprocess.run(["git", "init", "-q", folder], check=True)
            (root / "copy.txt").write_text("Welcome\nChat-GPT", encoding="utf-8")
            (root / "untracked.txt").write_text("Claude", encoding="utf-8")
            subprocess.run(["git", "add", "copy.txt"], cwd=root, check=True)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(1, main(root))
            self.assertIn("copy.txt:2:", output.getvalue())
            self.assertNotIn("untracked.txt", output.getvalue())
            (root / "copy.txt").write_text("Made by Unknown Helper", encoding="utf-8")
            with contextlib.redirect_stdout(output):
                self.assertEqual(1, main(root))
            (root / "copy.txt").write_text("Welcome", encoding="utf-8")
            with contextlib.redirect_stdout(output):
                self.assertEqual(0, main(root))
