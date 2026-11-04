import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust artillery and rockets preserve laying, salvos, owned shells and warning order", async () => {
  const stdout = await runFixture("vehicle-artillery");
  assert.match(stdout, /VEHICLE_ARTILLERY passed states=39509/);
});
