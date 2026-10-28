import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

for (const [fixture, marker] of [["vehicle-motion", "VEHICLE_MOTION failures=0"], ["vehicle-sockets", "VEHICLE_SOCKETS passed"]]) {
  test(`${fixture}: vehicle handling and model geometry contract`, async () => {
    const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
      "--headless", "--path", ROOT, `res://tests/fixtures/${fixture}.tscn`,
    ], { timeout: 120_000, maxBuffer: 4 * 1024 * 1024 });
    assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|Assertion failed/);
    assert.ok(stdout.includes(marker), stdout + stderr);
  });
}
