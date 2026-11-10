import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

for (const [scene, marker] of [["tests/fixtures/camera-streaming.tscn", "CAMERA_STREAMING passed"], ["tests/grass_stream_test.tscn", "GRASS_STREAM_TEST failures=0"], ["tests/structure_view_test.tscn", "STRUCTURE_VIEW_TEST failures=0"]]) {
  test(`camera streaming: ${scene}`, async () => {
    const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
      "--headless", "--path", ROOT, `res://${scene}`,
    ], { timeout: 120_000 });
    assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|^ERROR:/m);
    assert.ok(stdout.includes(marker), stdout);
  });
}
