import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust destruction preserves immediate ground edits and collision until tick end", async () => {
  const stdout = await runFixture("world-geometry");
  assert.match(stdout, /WORLD_GEOMETRY passed states=438/);
});
