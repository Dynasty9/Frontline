import test from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("smoke throws its shadow downsun, keeps its depth, and reaches every sunlit shader and the fog", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/smoke-shadow.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|SHADER ERROR|Parse Error|Assertion failed/);
  assert.match(stdout, /SMOKE SHADOW passed/);
});
