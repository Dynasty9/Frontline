import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust captors preserve shared capture credit, prison choice and delivery", async () => {
  const stdout = await runFixture("infantry-prison-owned");
  assert.match(stdout, /INFANTRY_PRISON_OWNED passed states=5120/);
});
