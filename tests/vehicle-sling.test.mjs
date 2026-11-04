import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust sling transport preserves paired links, swing, release and dropped cargo", async () => {
  const stdout = await runFixture("vehicle-sling");
  assert.match(stdout, /VEHICLE_SLING passed states=9117/);
});
