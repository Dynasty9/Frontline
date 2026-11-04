import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust rotorcraft and UAV guidance preserve momentum, hovering, landing and attitude", async () => {
  const stdout = await runFixture("vehicle-flight");
  assert.match(stdout, /VEHICLE_FLIGHT passed steps=24000/);
});
