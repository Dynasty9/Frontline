import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

// The native Mac embedded driver needs a debugger even with no editor attached.
const displayArgs = process.platform === "darwin" && process.env.FL_SHOW_WINDOW !== "1"
  ? ["--embedded", "--debug", "--ignore-error-breaks"]
  : [];

function render(scene, renderer, resolution, { engine = [], sceneArgs = [], timeout = 120_000 } = {}) {
  return promisify(execFile)(process.env.GODOT || "godot", [
    ...displayArgs, "--path", ROOT, "--rendering-method", renderer, "--audio-driver", "Dummy",
    "--resolution", resolution, ...engine, `res://tests/fixtures/${scene}.tscn`, "--", ...sceneArgs,
  ], { timeout, env: { ...process.env, FL_CAPTURE_SIZE: resolution } });
}

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

test("ground decals stay off cover and opaque smoke", {
  skip: process.env.FL_TEST_RENDER !== "1",
}, async () => {
  const { stdout, stderr } = await render("ground-marks", "forward_plus", "640x360");
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|SHADER ERROR/);
  assert.match(stdout, /GROUND_MARKS failures=0/);
});

// Depth textures need an actual renderer; opt in on a workstation or Xvfb.
for (const renderer of ["forward_plus", "gl_compatibility"]) {
  for (const msaa of [false, true]) {
    test(`blast occlusion: ${renderer}, ${msaa ? "4x MSAA" : "no MSAA"}`, {
      skip: process.env.FL_TEST_RENDER !== "1",
    }, async () => {
      const { stdout, stderr } = await render("blast-occlusion", renderer, "320x240", {
        sceneArgs: msaa ? [] : ["--no-msaa"],
      });
      assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|SHADER ERROR/);
      assert.match(stdout, /BLAST_OCCLUSION failures=0/);
    });
  }
}

for (const renderer of ["forward_plus", "gl_compatibility"]) {
  test(`ground crater remains detailed nearby: ${renderer}`, {
    skip: process.env.FL_TEST_RENDER !== "1",
  }, async () => {
    const { stdout, stderr } = await render("ground-deformation", renderer, "640x360", {
      engine: ["--fixed-fps", "24"], timeout: 180_000,
    });
    assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|SHADER ERROR/);
    assert.match(stdout, /GROUND_DEFORMATION failures=0/);
  });
}
