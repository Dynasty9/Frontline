import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust grenade tasks preserve approaches, pickup, kicking, covering and dives", async () => {
  const stdout = await runFixture("infantry-grenade-tasks");
  assert.match(stdout, /INFANTRY_GRENADE_TASKS passed steps=46080/);
});
