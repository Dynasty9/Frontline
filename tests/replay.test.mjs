import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { test } from "node:test";
import path from "node:path";

for (const scenario of ["attack", ""]) test(`recorded ${scenario || "mountain"} battles restore state across forward and backward seeks`, { timeout: 180_000 }, async (t) => {
  const process = spawn(globalThis.process.env.GODOT || "godot", ["--headless", "--fixed-fps", "30", "--path", path.resolve(import.meta.dirname, ".."), "--", "--replay-test", `--replay-scenario=${scenario}`, "--no-stun"], { stdio: ["ignore", "pipe", "pipe"] });
  t.after(() => { if (process.exitCode === null) process.kill(); });
  let output = "";
  process.stdout.on("data", (data) => { output += data; });
  process.stderr.on("data", (data) => { output += data; });
  const code = await new Promise((resolve, reject) => {
    process.once("error", reject);
    process.once("exit", resolve);
  });
  assert.equal(code, 0, output);
  assert.match(output, /REPLAY TEST complete/, output);
  assert.doesNotMatch(output, /SCRIPT ERROR|REPLAY TEST:/);
});
