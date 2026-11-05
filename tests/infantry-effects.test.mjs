import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust shared combat preserves suppression, casualties, credit, claims and squad responses", async () => {
  const stdout = await runFixture("infantry-effects");
  assert.match(stdout, /INFANTRY_EFFECTS passed states=18432/);
});
