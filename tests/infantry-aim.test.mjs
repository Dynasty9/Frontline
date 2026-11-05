import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry aiming preserves sight timers, cover fire and randomness", async () => {
  const stdout = await runFixture("infantry-aim");
  assert.match(stdout, /INFANTRY_AIM passed steps=20480/);
});
