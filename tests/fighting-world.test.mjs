import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust fighting connects movement, cover, firing, escort and downtime against the shared world", async () => {
  const stdout = await runFixture("fighting-world");
  assert.match(stdout, /FIGHTING_WORLD passed states=1536/);
});
