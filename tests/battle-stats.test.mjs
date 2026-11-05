import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust battle records preserve attribution, rejoins, capture credit and private reports", async () => {
  const stdout = await runFixture("battle-stats");
  assert.match(stdout, /BATTLE_STATS passed states=8192/);
});
