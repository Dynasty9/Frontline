import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry vitals preserve wounds, recovery, fatigue, attribution and squad responses", async () => {
  const stdout = await runFixture("infantry-vitals");
  assert.match(stdout, /INFANTRY_VITALS passed steps=92160/);
});
