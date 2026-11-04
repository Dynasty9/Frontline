import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./game.mjs";

const execute = promisify(execFile);

// Numeric fixtures finish in _ready; two frames let the engine flush diagnostics.
export async function runFixture(scene) {
  const { stdout, stderr } = await execute(process.env.GODOT || "godot", [
    "--headless", "--quit-after", "2", "--path", ROOT, `res://tests/fixtures/${scene}.tscn`,
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
  return stdout;
}
