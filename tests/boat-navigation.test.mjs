import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust boat navigation preserves shore searches, connected water and weighted routes", async () => {
  const stdout = await runFixture("boat-navigation");
  assert.match(stdout, /BOAT_NAVIGATION passed queries=3072/);
});
