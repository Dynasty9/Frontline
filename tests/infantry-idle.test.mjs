import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry downtime preserves idle choices, conversations, deadlines and random cursors", async () => {
  const stdout = await runFixture("infantry-idle");
  assert.match(stdout, /INFANTRY_IDLE passed steps=32768/);
  assert.match(stdout, /INFANTRY_IDLE_FREED passed cases=2/);
  assert.match(stdout, /INFANTRY_IDLE_BOUNDARY passed/);
});
