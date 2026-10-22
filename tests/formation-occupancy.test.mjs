import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("nearby formation occupancy preserves positions, cover, trenches and map edges", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/formation-occupancy.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
  assert.match(stdout, /FORMATION_OCCUPANCY passed/);
});
