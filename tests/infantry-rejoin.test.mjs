import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust squad rejoining preserves command succession, membership and battle records", async () => {
  const stdout = await runFixture("infantry-rejoin");
  assert.match(stdout, /INFANTRY_REJOIN passed states=2048/);
});
