// AI difficulty (Defs.AI_LEVELS): the lobby's "ai_difficulty", or one per
// side from --ai-difficulty=0:LEVEL,1:LEVEL, reaches each AI commander and
// shapes how it thinks: a recruit looks at the battle less often, attacks
// head-on and never scouts; a veteran looks more often. Only the extremes
// touch supply, and only for a side no player commands.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

const commanders = async () => {
  const { ai } = await game.query("world");
  return Object.fromEntries(ai.map((c) => [c.team, c]));
};

test("each side's AI gets the level it was given, and thinks like it", async () => {
  await game.load({ battle: true, seed: 3, ai_difficulty: "0:recruit,1:veteran" });
  const ai = await commanders();
  assert.equal(ai[0].level, "recruit");
  assert.equal(ai[1].level, "veteran");
  assert.equal(ai[0].flanks, false, "a recruit attacks head-on");
  assert.equal(ai[1].flanks, true);
  assert.equal(ai[0].scouts, false, "a recruit sends no recon flights");
  assert.equal(ai[0].retreat_at, 0, "a recruit leaves battered squads in the fight");
  assert.ok(ai[1].retreat_at > 0.34, "a veteran pulls squads out sooner than a regular");
  assert.ok(ai[0].think > ai[1].think, `a recruit looks at the battle less often (${ai[0].think} s, ${ai[1].think} s)`);
  assert.equal(ai[0].supply, 0.85, "a recruit's lorries carry less");
  assert.equal(ai[1].supply, 1.15, "a veteran's lorries carry more");
  await game.step(120);
  const { counters } = await game.stats();
  const [r, v] = [counters.ai_think_t0 ?? 0, counters.ai_think_t1 ?? 0];
  assert.ok(r > 10 && v > r * 2, `the veteran thought far more often in two minutes (recruit ${r}, veteran ${v})`);
});

test("one level for every AI, and the next battle starts from Regular again", async () => {
  await game.load({ battle: true, seed: 3, ai_difficulty: "adaptive" });
  let ai = await commanders();
  assert.equal(ai[0].level, "adaptive");
  assert.equal(ai[1].level, "adaptive");
  assert.equal(ai[0].skill, 1, "Adaptive starts as a regular");
  assert.equal(ai[0].supply, 1, "Adaptive gets no supply handicap or bonus");
  await game.load({ battle: true, seed: 3 });
  ai = await commanders();
  assert.equal(ai[0].level, "regular");
  assert.equal(ai[1].level, "regular");
  assert.equal(ai[0].supply, 1);
});
