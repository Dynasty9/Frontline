import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { ROOT } from "./lib/game.mjs";

test("performance reports attribute the worst measured tick including terrain work", async (t) => {
  const directory = await mkdtemp(path.join(tmpdir(), "frontline-perf-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const report = path.join(directory, "report.json");
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "--", "--scenario=stress", "--units=12",
    "--stress-mode=idle", "--perf-details", "--port=19489", "--perf-at=0.1", "--perf-duration=0.3",
    `--perf-json=${report}`, "--quit-after=3",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
  const data = JSON.parse(await readFile(report, "utf8"));
  assert.ok(data.ticks.count > 0);
  assert.equal(data.worst_tick.total_ms, data.ticks.max_ms);
  assert.ok(data.worst_tick.systems_ms["terrain + cleanup"] >= 0);
  const attributed = Object.values(data.worst_tick.systems_ms).reduce((a, b) => a + b, 0);
  assert.ok(attributed <= data.worst_tick.total_ms + 0.001);
  assert.ok(attributed > 0);
  assert.ok(data.nested_max_ms._think > 0);
  for (const [key, peak] of Object.entries(data.nested_max_ms)) {
    assert.ok(peak <= data.nested_total_ms[key] + 0.001);
  }
});
