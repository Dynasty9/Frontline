import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust house entry preserves stacking, cooking, door kicks and buddy entry", async () => {
  const stdout = await runFixture("infantry-breach");
  assert.match(stdout, /INFANTRY_BREACH passed steps=46080/);
});
