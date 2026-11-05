import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry shock preserves knockback, landings, flinching and disorientation", async () => {
  const stdout = await runFixture("infantry-shock");
  assert.match(stdout, /INFANTRY_SHOCK passed steps=92160/);
});
