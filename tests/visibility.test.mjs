import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

const run = promisify(execFile);

test("atmospheric haze stays thin at every zoom and world symbols use transparent atlas cells", async () => {
  const { stdout, stderr } = await run(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://scripts/test/visibility_test.tscn",
  ], { timeout: 120_000, maxBuffer: 2 * 1024 * 1024 });
  assert.match(stdout, /VISIBILITYTEST \d+ checks, 0 failures/);
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|TESTRUN failed/);
});
