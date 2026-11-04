import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("soldier batches distinguish poses, teams and cells and expire hidden instances", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/soldier-batches.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|^ERROR:/m);
  assert.match(stdout, /SOLDIER_BATCHES passed/);
});

test("socket soldier batches retain smooth motion and immediate visibility changes", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/soldier-smoothing.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|^ERROR:/m);
  assert.match(stdout, /SOLDIER_SMOOTHING passed/);
});

test("all soldier poses share batches and animate without fresh instance uploads", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/soldier-poses.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|^ERROR:/m);
  assert.equal((stdout.match(/SOLDIER_POSES passed /g) || []).length, 16);
});
