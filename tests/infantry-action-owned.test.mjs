import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust action completion preserves shared projectiles, melee, doors and launch reactions", async () => {
  const stdout = await runFixture("infantry-action-owned");
  assert.match(stdout, /INFANTRY_ACTION_OWNED passed states=12288/);
});
