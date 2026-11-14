import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("mission climaxes wait for their promised outcome", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--quit-after", "3", "--path", ROOT, "res://tests/fixtures/mission-pacing.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|Assertion failed/);
  assert.match(stdout, /MISSION_PACING passed/);
});
