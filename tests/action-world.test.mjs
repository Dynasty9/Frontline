import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust action completion connects door geometry, melee credit, ordnance and launch warnings", async () => {
  const stdout = await runFixture("action-world");
  assert.match(stdout, /ACTION_WORLD passed states=384/);
});
