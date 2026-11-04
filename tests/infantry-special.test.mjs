import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust special attacks preserve owned targets, ammunition, actions and random continuation", async () => {
  const stdout = await runFixture("infantry-special");
  assert.match(stdout, /INFANTRY_SPECIAL passed states=32768/);
});
