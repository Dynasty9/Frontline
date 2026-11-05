import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("Rust executes squad attack, construction, boarding, garrison and fire orders", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--quit-after", "2", "--path", ROOT, "res://tests/fixtures/squad-orders.tscn",
  ], { timeout: 240_000, maxBuffer: 4 * 1024 * 1024 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
  assert.match(stdout, /SQUAD_ORDERS passed states=768/);
  console.log(stdout.match(/SQUAD_ORDERS passed states=\d+/)[0]);
});
