import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust owned cover decisions preserve squad contacts, occupied anchors and reevaluation timing", async () => {
  const stdout = await runFixture("infantry-cover");
  assert.match(stdout, /INFANTRY_COVER passed states=27648/);
});
