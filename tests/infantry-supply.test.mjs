import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry supply preserves scavenging, destinations, refills and reload order", async () => {
  const stdout = await runFixture("infantry-supply");
  assert.match(stdout, /INFANTRY_SUPPLY passed steps=16384/);
});
