import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("support aircraft bend onto the pass and ease into the climb", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--fixed-fps", "30", "--path", ROOT, "--quit-after", "900",
    "res://tests/fixtures/banked-flyovers.tscn", "--", "--scenario=trenches", "--seed=3", "--static",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
  assert.match(stdout, /BANKED_FLYOVERS passed/);
});
