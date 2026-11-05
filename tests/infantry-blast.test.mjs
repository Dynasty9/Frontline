import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust shared blasts preserve victim order, shelter, casualties, carrier links and flinching", async () => {
  const stdout = await runFixture("infantry-blast");
  assert.match(stdout, /INFANTRY_BLAST passed states=12288/);
});
