import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust shared reflexes preserve grenade claims, rescue links, warnings and random continuation", async () => {
  const stdout = await runFixture("infantry-reflex");
  assert.match(stdout, /INFANTRY_REFLEX passed states=11520/);
});
