import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry decisions preserve reflex priority, shared supply, breaching and special weapons", async () => {
  const stdout = await runFixture("infantry-decision");
  assert.match(stdout, /INFANTRY_DECISION passed states=32256/);
});
