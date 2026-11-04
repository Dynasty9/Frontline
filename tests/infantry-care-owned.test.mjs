import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust medical duties preserve shared casualty claims, treatment, shelter and return", async () => {
  const stdout = await runFixture("infantry-care-owned");
  assert.match(stdout, /INFANTRY_CARE_OWNED passed states=9216/);
});
