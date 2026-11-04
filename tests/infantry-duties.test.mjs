import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry duties preserve construction, stretcher cooperation and prisoner escorts", async () => {
  const stdout = await runFixture("infantry-duties");
  assert.match(stdout, /INFANTRY_DUTIES passed steps=30720/);
  assert.match(stdout, /INFANTRY_DUTIES_FREED passed cases=6/);
});
