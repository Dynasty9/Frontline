import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust grenade reflexes preserve protection, throwback, kicking, cover and cooking", async () => {
  const stdout = await runFixture("infantry-grenades");
  assert.match(stdout, /INFANTRY_GRENADES passed cases=4096/);
});
