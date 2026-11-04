import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust supply routes preserve completion order, wrecked FOBs, town deliveries and cleared ground", async () => {
  const stdout = await runFixture("supply-network");
  assert.match(stdout, /SUPPLY_NETWORK passed states=512 removed=\d+/);
});
