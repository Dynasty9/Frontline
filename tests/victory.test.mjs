// How a skirmish is won (scripts/game/victory.gd): a side loses when its
// resolve runs out (it drains while the enemy holds more ground, and with
// every man and vehicle lost), or when it has no base left, a wrecked FOB
// left in ruins counting as none. Each test loads an AI-vs-AI battle and rigs
// it through the test port ("rig"): hands a side the towns, sets resolve,
// wrecks a FOB. victory_from / victory_grace bring the minutes-long waits
// down to seconds.

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

const world = () => game.query("world");

test("holding more ground drains the enemy's resolve, not your own", async () => {
  await game.load({ battle: true, seed: 2, victory_from: 12 });
  await game.step(11);
  const before = await world();
  assert.deepEqual(before.resolve, [600, 600], "both sides start at 600");
  const r = await game.send("rig", { towns: 0 });
  assert.equal(r.ok, true);
  await game.step(10);
  const w = await world();
  assert.ok(w.ground[0] > w.ground[1], `the Coalition holds more (${w.ground})`);
  assert.ok(w.bleed[1] > 0, `the Rebels are bleeding (${w.bleed[1]}/s)`);
  assert.equal(w.bleed[0], 0, "the Coalition isn't");
  assert.ok(w.resolve[1] < 599, `the Rebels' resolve has fallen (${w.resolve[1]})`);
  assert.equal(w.resolve[0], 600, "the Coalition's hasn't");
  assert.equal(w.winner, -1, "nobody has won yet");
});

test("a side whose resolve runs out loses the battle", async () => {
  await game.load({ battle: true, seed: 2, victory_from: 12 });
  await game.step(11);
  await game.send("rig", { towns: 0, resolve: [400, 3] });
  const r = await game.step(10);
  assert.equal(r.winner, 0, "the Coalition wins");
  const { counters } = await game.stats();
  assert.equal(counters.victory_resolve, 1, "on resolve");
});

test("a FOB wrecked and left in ruins stops counting as a base", async () => {
  // (its engineers have it patched up again in about eight seconds, so the
  // grace here is shorter than that)
  await game.load({ battle: true, seed: 2, victory_grace: 2 });
  await game.step(11);
  const { structures } = await game.query("structures", { team: 1, kind: "fob" });
  assert.equal(structures.length, 1, "the Rebels have one FOB");
  await game.send("rig", { wreck: structures[0].id });
  let r = await game.step(1);
  assert.equal(r.winner, -1, "inside its grace the wreck still counts");
  r = await game.step(4);
  assert.equal(r.winner, 0, "after it, the Rebels have no base and lose");
  const { counters } = await game.stats();
  assert.equal(counters.victory_no_base, 1, "for want of a base");
});

test("victory: fobs keeps the old rule: no resolve, only the bases", async () => {
  await game.load({ battle: true, seed: 2, victory: "fobs", victory_from: 12 });
  await game.step(11);
  await game.send("rig", { towns: 0, resolve: [400, 3] });
  const r = await game.step(10);
  assert.equal(r.winner, -1, "nobody wins on resolve");
  const w = await world();
  assert.deepEqual(w.bleed, [0, 0], "and nothing bleeds");
});
