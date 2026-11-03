import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { ROOT } from "./lib/game.mjs";

test("benchmark trace exports aligned chronological samples without changing the summary", async () => {
  const folder = await mkdtemp(join(tmpdir(), "frontline-frame-trace-"));
  try {
    const output = join(folder, "frames.json");
    const began = Date.now() / 1000;
    const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
      "--headless", "--path", ROOT, "--", "--scenario=attack", "--seed=3",
      "--perf-at=0.25", "--perf-duration=1", "--quit-after=3", `--perf-json=${output}`, "--no-stun",
    ], { timeout: 120_000, env: { ...process.env, FL_DEBUG_FRAME_TRACE: "1" } });
    assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
    const report = JSON.parse(await readFile(output, "utf8"));
    const samples = report.frame_samples_ms;
    assert.ok(samples.started_unix_s >= began - 1 && samples.started_unix_s <= Date.now() / 1000 + 1);
    const marker = stdout.split("\n").find((line) => line.startsWith("FRAME_TRACE_BEGIN "));
    assert.equal(JSON.parse(marker.slice("FRAME_TRACE_BEGIN ".length)), samples.started_unix_s);
    assert.ok(report.frames.count > 0 && Object.keys(samples.views).length > 0);
    for (const values of [samples.total, ...Object.values(samples.views)]) {
      assert.equal(values.length, report.frames.count);
      assert.ok(values.every((value) => Number.isFinite(value) && value >= 0));
    }
    assert.equal(Math.max(...samples.total), report.frames.max_ms);
    const printed = JSON.parse(stdout.split("\n").find((line) => line.startsWith("BENCHMARK ")).slice(10));
    assert.deepEqual(printed.frames, report.frames);
    assert.equal(printed.frame_samples_ms, undefined, "Raw samples stay in the requested file");
  } finally {
    await rm(folder, { recursive: true, force: true });
  }
});
