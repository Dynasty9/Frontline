import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry births preserve every unit loadout, upgrades, squad membership and random ordering", async () => {
  const stdout = await runFixture("infantry-spawn");
  assert.match(stdout, /INFANTRY_SPAWN passed states=\d+ kinds=\d+/);
});
