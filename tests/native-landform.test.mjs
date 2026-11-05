import test from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust elevated terrain preserves grounding, slopes, rays, craters and restored geology", async () => {
  const stdout = await runFixture("native-landform");
  assert.match(stdout, /NATIVE_LANDFORM passed queries=1920/);
});
