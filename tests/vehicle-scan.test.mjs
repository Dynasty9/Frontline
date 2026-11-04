import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust vehicle acquisition preserves owned poses, visibility, priorities and reports", async () => {
  const stdout = await runFixture("vehicle-scan");
  assert.match(stdout, /VEHICLE_SCAN passed states=4224/);
});
