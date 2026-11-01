import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

for (const [mode, name] of [[13, "shared scans"], [14, "crew decisions"], [15, "driving and shoving"], [16, "smashing obstacles"], [19, "complete ground vehicle updates and troop dismounts"], [20, "complete aircraft updates, cargo and deliveries"]]) {
  test(`Rust shared world preserves ${name}`, async () => {
    const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
      "--headless", "--quit-after", "2", "--path", ROOT, "res://tests/fixtures/vehicle-movement-world.tscn", "--", `--case=${mode}`,
    ], { timeout: mode == 20 ? 360_000 : 120_000 });
    assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
    assert.match(stdout, /VEHICLE_COMBAT_WORLD passed states=\d+/);
  });
}
