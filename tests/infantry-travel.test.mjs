import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry arrivals preserve boarding, tunnels, supply and ordered throws", async () => {
  const stdout = await runFixture("infantry-travel");
  assert.match(stdout, /INFANTRY_TRAVEL passed steps=24576/);
  assert.match(stdout, /INFANTRY_TRAVEL_BOUNDARY passed/);
});
