import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

for (const mode of ["GPU", "CPU"]) {
  test(`armament effects: ${mode} pools, elevated ground, airbursts and flares`, async () => {
    const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
      "--headless", "--path", ROOT, "res://tests/fixtures/armament-effects.tscn",
      "--", ...(mode === "CPU" ? ["--cpu-effects"] : []),
    ], { timeout: 120_000 });
    assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|SHADER ERROR/);
    assert.match(stdout, new RegExp(`ARMAMENT_EFFECTS ${mode} failures=0`));
  });
}
