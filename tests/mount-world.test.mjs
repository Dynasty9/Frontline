import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust gun crews preserve mounting, traverse, mortar orders, launches and defensive smoke", async () => {
  const stdout = await runFixture("mount-world");
  assert.match(stdout, /MOUNT_WORLD passed states=1448/);
});
