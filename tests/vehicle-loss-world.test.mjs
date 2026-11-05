import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust destruction connects passenger casualties, crew orders, logistics and burning wrecks", async () => {
  const stdout = await runFixture("vehicle-loss-world");
  assert.match(stdout, /VEHICLE_LOSS_WORLD passed states=384/);
});
