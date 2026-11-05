import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust transport pilots preserve pickup, landing, delivery and return flight phases", async () => {
  const stdout = await runFixture("vehicle-air");
  assert.match(stdout, /VEHICLE_AIR passed steps=76800/);
});
