import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust vehicles retain crew orders, repairs, transport links and turret state", async () => {
  const stdout = await runFixture("vehicle-state");
  assert.match(stdout, /VEHICLE_STATE passed cases=25315/);
});
