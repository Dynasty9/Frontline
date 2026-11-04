import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry geometry preserves posture, exposure, sights and hit factors", async () => {
  const stdout = await runFixture("infantry-pose");
  assert.match(stdout, /INFANTRY_POSE passed cases=19200/);
});
