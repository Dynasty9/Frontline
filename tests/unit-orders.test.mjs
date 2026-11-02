import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("Rust individual orders retain cover, claims and mounted gun assignments", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--quit-after", "2", "--path", ROOT, "res://tests/fixtures/unit-orders.tscn",
  ], { timeout: 240_000, maxBuffer: 4 * 1024 * 1024 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
  assert.match(stdout, /UNIT_ORDERS passed states=432/);
  console.log(stdout.match(/UNIT_ORDERS passed states=\d+/)[0]);
});
