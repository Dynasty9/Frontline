import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust special attacks preserve targets, ammo, cooldowns, queued fire and effects", async () => {
  const stdout = await runFixture("infantry-arsenal");
  assert.match(stdout, /INFANTRY_ARSENAL passed decisions=32768/);
});
