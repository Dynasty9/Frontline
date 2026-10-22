import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("notifications redraw on arrival, flashing, fading and removal, but retain steady text", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/toast-drawing.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
  assert.match(stdout, /TOAST_DRAWING passed/);
});

