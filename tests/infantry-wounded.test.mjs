import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust wounded infantry preserve bleeding, rescue, pistol timing and corpse collection", async () => {
  const stdout = await runFixture("infantry-wounded");
  assert.match(stdout, /INFANTRY_WOUNDED passed steps=61441/);
});
