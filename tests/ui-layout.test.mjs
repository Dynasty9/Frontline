// Layout checks instantiate the real controls offline. Scale calculations use
// physical window sizes even though no display is needed for these assertions.
import { spawn } from "node:child_process";
import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

const ROOT = path.resolve(import.meta.dirname, "..");

test("large interface scale keeps menus and lobby actions reachable", { timeout: 120_000 }, async () => {
  const child = spawn(process.env.GODOT || "godot", [
    "--headless", "--fixed-fps", "60", "--path", ROOT,
    "scripts/test/ui_layout_test.tscn", "--", "--ui-layout-test",
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
    assert.doesNotMatch(output, /SCRIPT ERROR|UILAYOUT FAIL/, output);
    assert.match(output, /UILAYOUT \d+\/\d+ passed/, output);
  } finally {
    clearTimeout(timer);
    child.kill();
  }
});
