import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("retained Rust infantry orders preserve route replacement, arrival and random draws", async () => {
  const stdout = await runFixture("infantry-orders");
  assert.match(stdout, /INFANTRY_ORDERS passed cases=4096/);
});
