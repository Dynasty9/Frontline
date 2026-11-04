import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust spatial queries preserve current positions, bucket order and checkpoint continuation", async () => {
  const stdout = await runFixture("spatial-state");
  assert.match(stdout, /SPATIAL_STATE passed cases=8192/);
});
