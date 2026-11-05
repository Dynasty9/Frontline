import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust wounded infantry preserve bleeding, carrier links, pistol fire and crawling", async () => {
  const stdout = await runFixture("wounded-world");
  assert.match(stdout, /WOUNDED_WORLD passed states=1184/);
});
