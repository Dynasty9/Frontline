import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust hidden infantry preserves treatment, transport, tunnel exits and prisoner departure", async () => {
  const stdout = await runFixture("infantry-hidden-owned");
  assert.match(stdout, /INFANTRY_HIDDEN_OWNED passed states=3584/);
});
