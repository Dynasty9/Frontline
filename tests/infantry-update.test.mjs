import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("retained Rust infantry connects recovery, movement, arrivals and observation state", async () => {
  const stdout = await runFixture("infantry-update");
  assert.match(stdout, /INFANTRY_UPDATE passed labels=8880 steps=18000/);
});
