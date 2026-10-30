import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("Rust infantry movement preserves paths, vaulting, doors, slides and mount turning", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--quit-after", "600", "--path", ROOT, "res://tests/fixtures/infantry-motion.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
  assert.match(stdout, /INFANTRY_MOTION passed steps=18000/);
});
