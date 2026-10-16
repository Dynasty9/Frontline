// A seed replays the same fight, tick for tick: the fingerprint of the whole
// simulation (every entity's place and health, every squad, the dice) matches
// at every check. When this fails, something gameplay depends on has escaped
// the seed: Godot's global randf()/shuffle(), the wall clock, frame timing.

import { test } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";

/** Loads a game and fingerprints it every `every` seconds for `secs`. */
async function fingerprints(game, what, secs, every) {
  await game.load(what);
  const out = [];
  for (let t = every; t <= secs; t += every) {
    await game.step(every);
    out.push(`t=${t} ${await game.hash()}`);
  }
  return out;
}

test("a scenario replays the same from its seed", async () => {
  const game = await Game.start();
  const a = await fingerprints(game, { scenario: "attack", seed: 3 }, 60, 15);
  const b = await fingerprints(game, { scenario: "attack", seed: 3 }, 60, 15);
  assert.deepEqual(b, a);
  const c = await fingerprints(game, { scenario: "attack", seed: 4 }, 15, 15);
  assert.notEqual(c[0], a[0], "another seed, another fight");
  assert.equal(await game.close(), 0);
});

test("a battle on a full map replays the same in another process", async () => {
  // two games side by side: nothing may hang on which process or when
  const games = await Promise.all([Game.start(), Game.start()]);
  const [a, b] = await Promise.all(games.map((g) => fingerprints(g, { battle: true, seed: 3 }, 120, 30)));
  assert.deepEqual(b, a);
  for (const g of games) assert.equal(await g.close(), 0);
});
