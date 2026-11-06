import test from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("terrain material arrays preserve packed channels and mipmaps", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/terrain-materials.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|SHADER ERROR|Parse Error/);
  assert.match(stdout, /TERRAIN_MATERIALS passed/);
});

// GPU visibility and colour checks also run when this fixture is launched natively.
test("scenery lighting shader resolves the active map dimensions", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/scenery-lighting.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|SHADER ERROR|Parse Error/);
  assert.match(stdout, /SCENERY_LIGHTING passed/);
});
