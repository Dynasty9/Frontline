import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("Rust vehicle orders use shared ground, boat and landing routes", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--quit-after", "2", "--path", ROOT, "res://tests/fixtures/vehicle-orders-world.tscn",
  ], { timeout: 240_000, maxBuffer: 4 * 1024 * 1024 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
  const result = stdout.match(/VEHICLE_ORDERS_WORLD passed states=(\d+) profiles=(\d+)/);
  assert.ok(result); assert.ok(Number(result[2]) >= 8); assert.equal(Number(result[1]), Number(result[2]) * 32);
  console.log(result[0]);
});
