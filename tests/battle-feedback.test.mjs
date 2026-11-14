// How a battle tells its commanders what's happening: no two men of a squad
// share a name, and a vehicle destroyed is a moment for both sides (good news
// for the side that killed it, bad for the side that lost it).

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

test("no two men of a squad share a name", async () => {
  for (const seed of [1, 2, 3, 4]) {
    await game.load({ scenario: "attack", seed, static: true });
    const { soldiers } = await game.query("soldiers", {});
    const bySquad = new Map();
    for (const s of soldiers) {
      if (!s.squad) continue;
      if (!bySquad.has(s.squad)) bySquad.set(s.squad, []);
      bySquad.get(s.squad).push(s.name);
    }
    assert.ok(bySquad.size >= 3, `seed ${seed}: squads to look at`);
    for (const [sid, names] of bySquad) {
      assert.equal(new Set(names).size, names.length, `seed ${seed}, squad ${sid}: ${names.join(", ")}`);
    }
  }
});

test("a vehicle destroyed is a moment for both sides", async () => {
  await game.load({ scenario: "roster", seed: 1 });
  await game.step(45);
  const { counters } = await game.stats();
  assert.ok((counters.vehicle_destroyed ?? 0) >= 1, "a vehicle was destroyed");
  assert.ok((counters.moment_gain ?? 0) >= 1, "the side that killed it heard the good news");
  assert.ok((counters.moment_loss ?? 0) >= 1, "the side that lost it heard the bad");
});
