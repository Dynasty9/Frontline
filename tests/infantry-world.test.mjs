import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

for (const [mode, name] of [[8, "lifecycle and decisions"], [3, "fighting"], [4, "breaching"], [5, "construction"], [6, "mounted weapons"], [7, "actions"], [9, "travel, carrying and custody"]]) {
  test(`Rust complete infantry tick preserves ${name}`, async () => {
    const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
      "--headless", "--quit-after", "2", "--path", ROOT, "res://tests/fixtures/infantry-world.tscn", "--", `--case=${mode}`,
    ], { timeout: 120_000 });
    assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
    assert.match(stdout, /INFANTRY_WORLD passed states=\d+/);
  });
}
