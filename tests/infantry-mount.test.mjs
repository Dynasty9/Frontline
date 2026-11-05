import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust mounted infantry preserve climbing, gun traverse, target selection and firing", async () => {
  const stdout = await runFixture("infantry-mount");
  assert.match(stdout, /INFANTRY_MOUNT passed steps=15360/);
  assert.match(stdout, /INFANTRY_MOUNT_FREED passed/);
});
