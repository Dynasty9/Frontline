import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("retained Rust infantry connects actions, interruptions and blast recovery", async () => {
  const stdout = await runFixture("infantry-execution");
  assert.match(stdout, /INFANTRY_EXECUTION passed steps=16896/);
});
