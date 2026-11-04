import test from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust terrain preserves routes, swept steps and soldier interruptions", async () => {
  const stdout = await runFixture("native-traversal");
  assert.match(stdout, /NATIVE_TRAVERSAL passed queries=720 interruptions=2880/);
});
