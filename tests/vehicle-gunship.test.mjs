import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust gunships preserve attack orbits, target tracking and rocket firing gates", async () => {
  const stdout = await runFixture("vehicle-gunship");
  assert.match(stdout, /VEHICLE_GUNSHIP passed states=19200/);
});
