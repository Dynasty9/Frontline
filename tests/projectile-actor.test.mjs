import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("retained Rust projectiles preserve handlers, flight, impact effects and attribution", async () => {
  const stdout = await runFixture("projectile-actor");
  assert.match(stdout, /PROJECTILE_ACTOR passed cases=336 steps=91224/);
});
