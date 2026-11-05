import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry scheduling preserves interruption priority, task order, deadlines and random cursors", async () => {
  const stdout = await runFixture("infantry-controller");
  assert.match(stdout, /INFANTRY_CONTROLLER passed steps=35328/);
  assert.match(stdout, /INFANTRY_CONTROLLER_BOUNDARY passed/);
});
