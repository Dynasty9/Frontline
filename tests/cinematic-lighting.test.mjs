import test from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("cinematic lighting presets, shadow fit, light shadows and sky moods", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/cinematic-lighting.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|SHADER ERROR|Parse Error|Assertion failed|is_inside_tree/);
  assert.match(stdout, /CINEMATIC LIGHTING passed/);
});
