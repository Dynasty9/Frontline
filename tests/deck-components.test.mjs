// Layout checks instantiate the real controls offline. Scale calculations use
// physical window sizes even though no display is needed for these assertions.
import { spawn } from "node:child_process";
import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

const ROOT = path.resolve(import.meta.dirname, "..");

test("deck components compose without a battle and preserve state, theme and keyboard contracts", { timeout: 120_000 }, async () => {
  const child = spawn(process.env.GODOT || "godot", [
    "--headless", "--fixed-fps", "60", "--path", ROOT,
    "scripts/test/deck_components_test.tscn", "--", "--deck-components-test",
    "--matchmaker=http://127.0.0.1:1", "--no-stun",
  ]);
  let output = "";
  child.stdout.on("data", (chunk) => { output += chunk; });
  child.stderr.on("data", (chunk) => { output += chunk; });
  const timer = setTimeout(() => child.kill(), 110_000);
  try {
    const code = await new Promise((resolve, reject) => {
      child.on("error", reject);
      child.on("exit", resolve);
    });
    assert.equal(code, 0, output);
    assert.doesNotMatch(output, /SCRIPT ERROR|DECK FAIL/, output);
    assert.match(output, /DECK \d+ checks complete/, output);
  } finally {
    clearTimeout(timer);
    child.kill();
  }
});
