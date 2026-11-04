import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry acquisition retains contacts, concealment, mount arcs and squad reports", async () => {
  const stdout = await runFixture("infantry-scan");
  assert.match(stdout, /INFANTRY_SCAN passed states=18432/);
});
