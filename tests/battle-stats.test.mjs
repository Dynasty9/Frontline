import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("Rust battle records preserve attribution, rejoins, capture credit and private reports", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--quit-after", "2", "--path", ROOT, "res://tests/fixtures/battle-stats.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
  assert.match(stdout, /BATTLE_STATS passed states=8192/);
});
