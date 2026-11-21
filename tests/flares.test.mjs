// Illumination flares (scenario "flares", a night attack on a line of walls):
// at night men see only a short way, so an enemy out in the dark goes unseen
// until a star shell lights him, and the AI commander puts star shells up
// over the fighting. Loaded with static: true nobody moves until told.
//
// One game serves the whole file (see attack.test.mjs).

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game, v3 } from "./lib/game.mjs";

// The near fighter cell starts 52 m out from the walls: inside a man's sight
// by day (56 m), well outside it at night (Defs.NIGHT_SIGHT).
const NEAR_CELL = v3(-6, -52);

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

/** The near cell's men (the far one starts 125 m out). */
async function nearCell() {
  const { soldiers } = await game.query("soldiers", { team: 1 });
  return soldiers.filter((s) => s.life === "ALIVE" && s.pos[1] > -90);
}

test("by day the walls see the near cell; at night they don't, until a star shell lights it", async () => {
  await game.load({ scenario: "flares", seed: 1, static: true, mood: "day" });
  await game.step(3);
  let cell = await nearCell();
  assert.ok(cell.some((s) => s.seen_by[0]), "by day the cell 52 m out is seen");

  await game.load({ scenario: "flares", seed: 1, static: true });
  const w = await game.query("world");
  assert.equal(w.dark, true, "the scenario is fought at night");
  await game.step(3);
  cell = await nearCell();
  assert.ok(cell.length >= 4, "the cell is there");
  assert.ok(!cell.some((s) => s.seen_by[0]), "at night nobody at the walls sees it");

  const { squads } = await game.query("squads", { team: 0, kind: "mortar_team" });
  const r = await game.order(0, "fire_mission", { squads: [squads[0].id], pos: NEAR_CELL, kind: "illum" });
  assert.equal(r.squads, 1, "the mortar team takes the fire mission");
  await game.step(14);
  const { flares } = await game.query("world");
  assert.ok(flares.length >= 1, "a flare is up");
  assert.ok(flares[0].height > 30 && flares[0].brightness > 0.5, `burning high over the field (${flares[0].height} m)`);
  const near = Math.hypot(flares[0].pos[0] - NEAR_CELL.v3[0], flares[0].pos[1] - NEAR_CELL.v3[1]);
  assert.ok(near < 40, `over the cell (${near.toFixed(0)} m off)`);
  cell = await nearCell();
  assert.ok(cell.some((s) => s.seen_by[0]), "in its light the cell is seen");
  const { counters } = await game.stats();
  assert.ok(counters.seen_by_flare >= 1, "picked out by the flare");
});

test("a flare drifts downwind and comes down as it burns", async () => {
  await game.load({ scenario: "flares", seed: 1, static: true });
  const { squads } = await game.query("squads", { team: 0, kind: "mortar_team" });
  await game.order(0, "fire_mission", { squads: [squads[0].id], pos: NEAR_CELL, kind: "illum" });
  await game.step(12);
  const a = (await game.query("world")).flares[0];
  await game.step(10);
  const b = (await game.query("world")).flares.find((f) => f.id === a.id);
  assert.ok(b, "still burning ten seconds on");
  // The wind blows toward +x (Fires.WIND).
  assert.ok(b.pos[0] > a.pos[0] + 5, `downwind (${a.pos[0]} -> ${b.pos[0]})`);
  assert.ok(b.height < a.height - 8, `and lower (${a.height} -> ${b.height} m)`);
  await game.step(40);
  const { flares } = await game.query("world");
  assert.ok(!flares.some((f) => f.id === a.id), "burnt out and gone within a minute");
});

test("the commander lights up a night attack", async () => {
  await game.load({ scenario: "flares", seed: 1 });
  await game.step(45);
  const { counters } = await game.stats();
  assert.ok(counters.ai_illum >= 1, "the commander called for illumination");
  assert.ok(counters.flare_burst >= 1, "a star shell burst");
  assert.ok(counters.seen_by_flare >= 1, "and the attackers were seen in its light");
});
