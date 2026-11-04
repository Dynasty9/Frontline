import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust navigation retains overlapping obstacles, terrain, fires and incremental repairs", async () => {
  const stdout = await runFixture("navigation-scene");
  assert.match(stdout, /NAVIGATION_SCENE passed states=392/);
});
