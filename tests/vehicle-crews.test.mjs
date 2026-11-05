import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust vehicle crews preserve withdrawal, evasion, infantry support and saved orders", async () => {
  const stdout = await runFixture("vehicle-crews");
  assert.match(stdout, /VEHICLE_CREWS passed steps=12288/);
});
