import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

// Parked cars and hulks are copies of finished models, by look, and the first
// of a look is built a piece at a time: none of it may change a model.
test("stocked and piecewise vehicle models are the models built at once", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/vehicle-stock.tscn",
  ], { timeout: 240_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
  assert.match(stdout, /VEHICLE_STOCK passed/);
});
