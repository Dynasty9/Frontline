import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust stationary infantry preserves spacing, terrain settling, cover alignment and watching", async () => {
  const stdout = await runFixture("infantry-stationary");
  assert.match(stdout, /INFANTRY_STATIONARY passed steps=15360/);
});
