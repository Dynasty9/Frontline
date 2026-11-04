import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust support vehicles preserve shared repair, ammunition and medical effects", async () => {
  const stdout = await runFixture("vehicle-service");
  assert.match(stdout, /VEHICLE_SERVICE passed states=36864/);
});
