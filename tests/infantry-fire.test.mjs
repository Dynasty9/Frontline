import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry fire retains aiming, squad support, muzzle geometry and ordered shot recovery", async () => {
  const stdout = await runFixture("infantry-fire");
  assert.match(stdout, /INFANTRY_FIRE passed states=12288/);
});
