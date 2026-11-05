import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust inactive infantry preserves carried bodies, cleanup deadlines and prisoner movement", async () => {
  const stdout = await runFixture("infantry-inactive-owned");
  assert.match(stdout, /INFANTRY_INACTIVE_OWNED passed states=1536/);
});
