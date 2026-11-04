import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust fire escape preserves committed duties, shelter, routes, speech and random ordering", async () => {
  const stdout = await runFixture("fire-escape-native");
  assert.match(stdout, /FIRE_ESCAPE passed states=3072/);
});
