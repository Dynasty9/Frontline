import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("relayed simulation packets drain within frame and queue limits", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/relay-budget.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
  assert.match(stdout, /RELAY_BUDGET passed/);
});
