import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust grenade duties preserve approach, pickup, kick, dive and shared round state", async () => {
  const stdout = await runFixture("infantry-grenade-owned");
  assert.match(stdout, /INFANTRY_GRENADE_OWNED passed states=23040/);
});
