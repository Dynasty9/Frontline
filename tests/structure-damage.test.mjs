import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust structure damage preserves occupants, gunners, repairable FOBs and delayed destruction effects", async () => {
  const stdout = await runFixture("structure-damage");
  assert.match(stdout, /STRUCTURE_DAMAGE passed states=6144/);
});
