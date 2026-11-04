import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust stretcher duties preserve shared carrying, solo takeover and tent delivery", async () => {
  const stdout = await runFixture("infantry-carry-owned");
  assert.match(stdout, /INFANTRY_CARRY_OWNED passed states=12288/);
});
