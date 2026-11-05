import test from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("standalone Rust content matches the current game definitions", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tools/export_simulation_content.tscn", "--", "--check",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
  assert.match(stdout, /SIMULATION_CONTENT passed vehicles=\d+ units=\d+ weapons=\d+/);
});
