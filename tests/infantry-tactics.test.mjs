import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("retained Rust infantry applies cover, sectors and movement choices without changing tactics", async () => {
  const stdout = await runFixture("infantry-tactics");
  assert.match(stdout, /INFANTRY_TACTICS passed cases=10240/);
});
