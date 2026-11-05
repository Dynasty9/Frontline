import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust vehicle launches retain missiles, smoke, warning order and random continuation", async () => {
  const stdout = await runFixture("vehicle-launch");
  assert.match(stdout, /VEHICLE_LAUNCH passed states=1816/);
});
