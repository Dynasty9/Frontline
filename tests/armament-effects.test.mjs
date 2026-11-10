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

// Depth textures need an actual renderer; opt in on a workstation or Xvfb.
for (const renderer of ["forward_plus", "gl_compatibility"]) {
  for (const msaa of [false, true]) {
    test(`blast occlusion: ${renderer}, ${msaa ? "4x MSAA" : "no MSAA"}`, {
      skip: process.env.FL_TEST_RENDER !== "1",
    }, async () => {
      const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
        "--path", ROOT, "--rendering-method", renderer, "--audio-driver", "Dummy",
        "--resolution", "320x240", "res://tests/fixtures/blast-occlusion.tscn",
        "--", ...(msaa ? [] : ["--no-msaa"]),
      ], { timeout: 120_000 });
      assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|SHADER ERROR/);
      assert.match(stdout, /BLAST_OCCLUSION failures=0/);
    });
  }
}
