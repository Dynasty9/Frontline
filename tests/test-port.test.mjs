// The test port itself: it steps exact ticks, refuses what it can't do, and a
// script error in the game fails the run.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";

let game;
// The script error test needs a game of its own (it ends with exit code 1):
// it starts with the first, so its start-up costs no extra time.
let other;
before(async () => {
  [game, other] = await Game.startMany(2);
});
after(async () => {
  await other?.close(); // (already closed, unless its test didn't run)
  assert.equal(await game?.close(), 0, "the game's exit code");
});

test("says hello", async () => {
  const r = await game.hello();
  assert.equal(r.tps, 30);
  assert.equal(r.headless, true);
});

test("refuses what it can't do", async () => {
  await assert.rejects(game.step(1), /no game loaded/);
  await assert.rejects(game.query("squads"), /no game loaded/);
  await assert.rejects(game.send("nonsense"), /unknown command/);
  await assert.rejects(game.load({ seed: 1 }), /load one of/);
  await assert.rejects(game.load({ mission: "nowhere" }), /no such mission/);
});

test("time moves only on a step, in exact ticks", async () => {
  const loaded = await game.load({ scenario: "attack", seed: 1, static: true });
  assert.equal(loaded.t, 0);
  assert.equal(loaded.squads, 4);
  const before = await game.hash();
  assert.equal(await game.hash(), before, "nothing happens between commands");
  const r = await game.step({ ticks: 45 });
  assert.equal(r.ticks, 45);
  assert.ok(Math.abs(r.t - 1.5) < 1e-6, `t=${r.t}`);
  assert.notEqual(await game.hash(), before);
});

test("queries narrow by team and kind", async () => {
  const { squads } = await game.query("squads", { team: 0 });
  assert.deepEqual(squads.map((s) => s.kind).sort(), ["mg_team", "rifle_squad", "rifle_squad"]);
  const { structures } = await game.query("structures", { kind: "sandbags" });
  assert.equal(structures.length, 1);
  const { soldiers } = await game.query("soldiers", { team: 1 });
  assert.equal(soldiers.length, 6);
  assert.ok(soldiers.every((s) => s.life === "ALIVE" && s.pos.length === 2));
});

test("a script error fails the run", async () => {
  // MapGen push_errors an unknown scenario (and lays out an empty field)
  await other.load({ scenario: "no_such_scenario" });
  assert.equal(other.errors, 1);
  const { recent } = await other.scriptErrors();
  assert.match(recent[0], /Unknown scenario: no_such_scenario/);
  assert.equal(await other.close(), 1, "the game's exit code");
});
