// A seed replays the same fight, tick for tick: the fingerprint of the whole
// simulation (every entity's place and health, every squad, the dice) matches
// at every check. When this fails, something gameplay depends on has escaped
// the seed: Godot's global randf()/shuffle(), the wall clock, frame timing.

import { describe, test } from "node:test";
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

/** Runs `fn` with `n` games of its own, and closes them whatever happens (their exit codes must be 0). */
async function withGames(n, fn) {
  const games = await Game.startMany(n);
  try {
    await fn(...games);
  } finally {
    const codes = await Promise.all(games.map((g) => g.close()));
    assert.deepEqual(codes, games.map(() => 0), "the games' exit codes");
  }
}

// The two run side by side, each in games of its own: the battle on a full map
// is the longest test of all, and the rest of the suite runs alongside it.
describe("a seed replays the same", { concurrency: true }, () => {
  test("a scenario replays the same from its seed", () =>
    withGames(1, async (game) => {
      // (in one game, one load after another: nothing may carry over from the last)
      const a = await fingerprints(game, { scenario: "attack", seed: 3 }, 60, 15);
      const b = await fingerprints(game, { scenario: "attack", seed: 3 }, 60, 15);
      assert.deepEqual(b, a);
      const c = await fingerprints(game, { scenario: "attack", seed: 4 }, 15, 15);
      assert.notEqual(c[0], a[0], "another seed, another fight");
    }));

  test("a battle on a full map replays the same in another process", () =>
    // two games side by side: nothing may hang on which process or when
    withGames(2, async (...games) => {
      const [a, b] = await Promise.all(games.map((g) => fingerprints(g, { battle: true, seed: 3 }, 120, 30)));
      assert.deepEqual(b, a);
    }));
});
