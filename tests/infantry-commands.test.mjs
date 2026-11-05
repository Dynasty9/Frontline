import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("retained Rust infantry commands preserve order gates, rescue claims and breach commitments", async () => {
  const stdout = await runFixture("infantry-commands");
  assert.match(stdout, /INFANTRY_COMMANDS passed cases=3840/);
});
