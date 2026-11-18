import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

const run = promisify(execFile);

test("a tank whose ammunition goes up loses its turret beside the hull, and every wreck reaches the clients burnt out in its own paint", async () => {
  const { stdout, stderr } = await run(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/vehicle-wrecks.tscn",
  ], { timeout: 120_000, maxBuffer: 2 * 1024 * 1024 });
  assert.match(stdout, /VEHICLE WRECKS \d+ checks, 0 failures/);
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|TESTRUN failed/);
});
