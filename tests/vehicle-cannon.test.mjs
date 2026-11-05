import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust cannon shots preserve barrel sockets, obstruction and trench impacts", async () => {
  const stdout = await runFixture("vehicle-cannon");
  assert.match(stdout, /VEHICLE_CANNON passed states=1320/);
});
