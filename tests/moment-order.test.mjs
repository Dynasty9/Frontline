// Rapid tutorial progress must keep the newest instruction visible.
import { spawn } from "node:child_process";
import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

const ROOT = path.resolve(import.meta.dirname, "..");

test("repeated battle events become the newest notice with their latest location", { timeout: 120_000 }, async () => {
  const child = spawn(process.env.GODOT || "godot", [
    "--headless", "--fixed-fps", "60", "--path", ROOT,
    "tests/moment-order-test.tscn", "--", "--moment-order-test",
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
    assert.doesNotMatch(output, /SCRIPT ERROR|MOMENT ORDER failures=[1-9]/, output);
    assert.match(output, /MOMENT ORDER failures=0/, output);
  } finally {
    clearTimeout(timer);
    child.kill();
  }
});
