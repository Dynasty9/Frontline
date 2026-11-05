import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust breach selection preserves houses, openings, closest mates and navigation ties", async () => {
  const stdout = await runFixture("breach-selection");
  assert.match(stdout, /BREACH_SELECTION passed decisions=2048 geometry=16384/);
});
