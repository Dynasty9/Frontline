// A test whose check fails before it closes its game, for test-port.test.mjs to
// run on its own (node --test fixtures/left-running.mjs): the run must fail, and
// end. (Not a *.test.mjs, so the suite itself doesn't pick it up.)

import { test } from "node:test";
import assert from "node:assert/strict";
import { Game } from "../lib/game.mjs";

test("a check fails before the game is closed", async () => {
  const game = await Game.start();
  const { tps } = await game.hello();
  assert.equal(tps, 0, "a check that fails");
  assert.equal(await game.close(), 0);
});
