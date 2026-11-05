import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust boats preserve currents, handling, traffic and recovery from grounding", async () => {
  const stdout = await runFixture("vehicle-boat");
  assert.match(stdout, /VEHICLE_BOAT passed states=43200/);
});
