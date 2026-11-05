import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust medical tasks preserve rescue, dragging, healing and escort callback order", async () => {
  const stdout = await runFixture("infantry-medicine");
  assert.match(stdout, /INFANTRY_MEDICINE passed steps=18432/);
  assert.match(stdout, /INFANTRY_MEDICINE_FREED passed tasks=4/);
});
