import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust vehicle damage preserves armour, blast shove, tracks and ordered ricochets", async () => {
  const stdout = await runFixture("vehicle-damage");
  assert.match(stdout, /VEHICLE_DAMAGE passed states=7392/);
});
