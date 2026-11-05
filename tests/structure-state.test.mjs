import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust structures retain geometry, construction, capture and production state", async () => {
  const stdout = await runFixture("structure-state");
  assert.match(stdout, /STRUCTURE_STATE passed cases=1152/);
});
