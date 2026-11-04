import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry actions preserve poses, queued throws, completion effects and target lifetime", async () => {
  const stdout = await runFixture("infantry-action");
  assert.match(stdout, /INFANTRY_ACTION passed steps=24576/);
  assert.match(stdout, /INFANTRY_ACTION_FREED passed cases=7/);
  assert.match(stdout, /INFANTRY_ACTION_BOUNDARY passed/);
});
