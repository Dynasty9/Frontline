import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry resupply preserves shared ammunition, searches, routes and reloads", async () => {
  const stdout = await runFixture("infantry-logistics");
  assert.match(stdout, /INFANTRY_LOGISTICS passed states=13824/);
});
