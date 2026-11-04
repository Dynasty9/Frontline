import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust vehicle driving preserves steering, traffic, braking and stuck recovery", async () => {
  const stdout = await runFixture("vehicle-driving");
  assert.match(stdout, /VEHICLE_MOTION passed steps=26880/);
});
