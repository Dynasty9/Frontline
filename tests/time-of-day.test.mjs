import test from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("time passes: the light is a pure function of battle time and mood, and stands still with the setting off", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/time-of-day.tscn",
  ], { timeout: 180_000, maxBuffer: 64 * 1024 * 1024 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|TIME_OF_DAY FAIL/, (stdout + stderr).slice(0, 8000));
  assert.match(stdout, /TIME_OF_DAY passed/);
});
