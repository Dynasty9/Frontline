import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust infantry lifecycle preserves hidden duties, status, moving posture and drone operators", async () => {
  const stdout = await runFixture("infantry-control");
  assert.match(stdout, /INFANTRY_CONTROL passed steps=28672/);
  assert.match(stdout, /INFANTRY_CONTROL_FREED passed cases=4/);
  assert.match(stdout, /INFANTRY_CONTROL_BOUNDARY passed/);
});
