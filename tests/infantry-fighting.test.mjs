import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry weapon decisions preserve cover shifts, posture, traverse and firing order", async () => {
  const stdout = await runFixture("infantry-fighting");
  assert.match(stdout, /INFANTRY_FIGHTING passed states=49152/);
});
