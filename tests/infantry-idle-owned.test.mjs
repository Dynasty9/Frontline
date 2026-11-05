import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust shared downtime preserves conversation claims, interruptions and random continuation", async () => {
  const stdout = await runFixture("infantry-idle-owned");
  assert.match(stdout, /INFANTRY_IDLE_OWNED passed states=4608/);
});
