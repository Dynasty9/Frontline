// Synthetic ownership only: no world simulation or gameplay commands.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("adviser display follows ownership and retains only valid completion feedback at cutoff", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/adviser-display.tscn",
    "--", "--matchmaker=http://127.0.0.1:1", "--no-stun",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
  assert.match(stdout, /ADVISER_DISPLAY failures=0/);
});
