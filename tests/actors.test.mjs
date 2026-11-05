import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("owned Rust actors preserve shared casualty links and autonomous drone flight", async () => {
  const stdout = await runFixture("actors");
  assert.match(stdout, /ACTOR_STATE passed shared=384 flights=72 steps=4523/);
});
