import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust vehicle weapons preserve missile priority, cannon gates and burst timing", async () => {
  const stdout = await runFixture("vehicle-weapon");
  assert.match(stdout, /VEHICLE_WEAPON passed states=21120/);
});
