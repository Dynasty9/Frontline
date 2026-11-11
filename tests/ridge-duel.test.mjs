import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

async function play(seed, fps) {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--fixed-fps", String(fps), "--path", ROOT, "res://tests/fixtures/ridge-duel.tscn",
    "--", `--ridge-fps=${fps}`, `--ridge-seed=${seed}`, "--verify-ridge-duel",
  ], { timeout: 150_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
  assert.match(stdout, /RIDGE_DUEL verified/);
  return JSON.parse(stdout.match(/RIDGE_RESULT (.*)/)[1]);
}

test("ridge drivers choose different routes and either crew can win", async () => {
  const original = await play(712, 30);
  const alternate = await play(13, 30);
  assert.notEqual(original.winner, alternate.winner);
  assert.notDeepEqual(original.visits, alternate.visits);
  for (const run of [original, alternate]) {
    assert.deepEqual(run.vehicles, ["tank", "old_tank"]);
    for (const shot of ["overview", "optic", "tracks", "knockout", "engine"]) assert.ok(run.shots.includes(shot), shot);
    assert.ok(run.separation > 300);
    assert.ok(run.distance.every(metres => metres > 20));
    assert.ok(run.visits.every(([a, b]) => a + b >= 1));
    assert.equal(run.visits[run.winner][4], 1);
  }
  const optic = original.shots.indexOf("optic");
  assert.deepEqual(original.shots.slice(optic, optic + 3), ["optic", "firing", "overhead"]);
  assert.ok(original.dirt_hits > 0 && original.glances > 0 && original.shots.includes("ground"));
  const replay = await play(712, 24);
  for (const key of ["winner", "actions", "visits", "distance", "ticks", "glances", "dirt_hits"]) {
    assert.deepEqual(replay[key], original[key]);
  }
});
