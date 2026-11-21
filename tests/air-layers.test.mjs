import test from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("the weather grid pools mist, bands rain, takes blasts' smoke and dust, and drifts downwind", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/air-layers.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|SHADER ERROR|Parse Error|Assertion failed/);
  assert.match(stdout, /AIR LAYERS passed/);
});
