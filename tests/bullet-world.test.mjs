import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust bullet fire preserves penetration, injuries, destruction, suppression and reports", async () => {
  const stdout = await runFixture("bullet-world");
  assert.match(stdout, /BULLET_WORLD passed states=1536/);
});
