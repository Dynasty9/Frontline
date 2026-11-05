import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust squads retain contacts, cached decisions, leader succession and casualty morale", async () => {
  const stdout = await runFixture("squad-state");
  assert.match(stdout, /SQUAD_STATE passed cases=1024/);
});
