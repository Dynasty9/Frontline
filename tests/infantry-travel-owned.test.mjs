import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust travel duties preserve movement, shared transport, tunnels and ammunition", async () => {
  const stdout = await runFixture("infantry-travel-owned");
  assert.match(stdout, /INFANTRY_TRAVEL_OWNED passed states=14336/);
});
