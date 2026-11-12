import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

const run = promisify(execFile);

test("helicopters fly by attitude: bank into turns, climb out, glide in, land, supply, sling and replicate at 30/60 Hz", async () => {
  const { stdout, stderr } = await run(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/helicopter-flight.tscn",
  ], { timeout: 120_000, maxBuffer: 2 * 1024 * 1024 });
  assert.match(stdout, /HELICOPTER FLIGHT \d+ checks, 0 failures/);
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|TESTRUN failed/);
});
