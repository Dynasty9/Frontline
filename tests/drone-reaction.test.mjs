import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust drone reactions preserve warnings, hearing memory and dive priority", async () => {
  const stdout = await runFixture("drone-reaction");
  assert.match(stdout, /DRONE_REACTION passed steps=20480/);
});
