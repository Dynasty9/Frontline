import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

for (const [mode, name] of [[17, "projectiles and support aircraft"], [18, "FPV drones"]]) {
  test(`Rust shared world preserves ${name}`, async () => {
    const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
      "--headless", "--quit-after", "2", "--path", ROOT, "res://tests/fixtures/ordnance-world.tscn", "--", `--case=${mode}`,
    ], { timeout: 120_000 });
    assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
    assert.match(stdout, /ORDNANCE_WORLD passed states=\d+/);
  });
}
