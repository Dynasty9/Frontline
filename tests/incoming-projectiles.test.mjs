import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust incoming rounds preserve warning order, shared memory, suppression and dives", async () => {
  const stdout = await runFixture("incoming-projectiles");
  assert.match(stdout, /INCOMING_PROJECTILES passed steps=12288/);
});
