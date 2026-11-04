import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("retained Rust infantry preserves casualty transitions and shared link cleanup", async () => {
  const stdout = await runFixture("infantry-casualty");
  assert.match(stdout, /INFANTRY_CASUALTY passed cases=3072/);
});
