import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust explosions preserve casualty, vehicle, supply, fire and terrain ordering", async () => {
  const stdout = await runFixture("world-combat");
  assert.match(stdout, /WORLD_COMBAT passed states=384/);
});
