import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust dismounts preserve passenger state, landing gates and squad order requests", async () => {
  const stdout = await runFixture("vehicle-transport");
  assert.match(stdout, /VEHICLE_TRANSPORT passed states=640/);
});
