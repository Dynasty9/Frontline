import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust cover searches preserve position scoring, occupancy and tied candidate order", async () => {
  const stdout = await runFixture("cover-search");
  assert.match(stdout, /COVER_SEARCH passed searches=4270/);
});
