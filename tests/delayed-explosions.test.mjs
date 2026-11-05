import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("cache explosions and rubble follow simulation time and resume pending events", async () => {
  const stdout = await runFixture("delayed-explosions");
  assert.match(stdout, /DELAYED_EXPLOSIONS passed steps=38400 blasts=\d+/);
});
