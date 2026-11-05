import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust prisoner rules preserve rescue, guard claims, intelligence and replay history", async () => {
  const stdout = await runFixture("prisoner-rules");
  assert.match(stdout, /PRISONER_RULES passed states=6144/);
});
