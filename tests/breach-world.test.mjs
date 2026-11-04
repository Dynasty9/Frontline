import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust house entry connects approach fire, doors, grenades and buddy orders against the shared world", async () => {
  const stdout = await runFixture("breach-world");
  assert.match(stdout, /BREACH_WORLD passed states=444/);
});
