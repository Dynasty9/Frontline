import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust engineers preserve work, return fire, completed cover, supply roads and repairs", async () => {
  const stdout = await runFixture("build-world");
  assert.match(stdout, /BUILD_WORLD passed states=940/);
});
