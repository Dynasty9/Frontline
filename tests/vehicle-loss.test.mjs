import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust vehicle loss preserves passenger casualties, crew births, wreck placement and random order", async () => {
  const stdout = await runFixture("vehicle-loss");
  assert.match(stdout, /VEHICLE_LOSS passed crew=\d+ wrecks=256 evacuated=1536/);
});
