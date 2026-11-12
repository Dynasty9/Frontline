// Command by intent (Delegation): squads handed to the XO with an intent carry
// it out on their own, and come back to you when you order them or take them
// back. The "attack" scenario: two rifle squads and a gun team against a
// fighter cell in a walled farmyard, loaded with play so they're yours.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game, v3 } from "./lib/game.mjs";

const YARD = v3(-2, -42);
const YOU = 1;

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

async function mine() {
  await game.load({ scenario: "attack", seed: 3, static: true, play: true });
  const { squads } = await game.query("squads", { team: 0 });
  return squads;
}

test("a platoon told to take the yard plans the attack, takes it and holds it", async () => {
  const squads = await mine();
  const ids = squads.map((s) => s.id);
  await game.send("order", { peer: YOU, t: "delegate", intent: "take", squads: ids, pos: YARD });
  let { squads: now } = await game.query("squads", { ids });
  assert.deepEqual(now.map((s) => s.intent), ["take", "take", "take"], "all three are delegated");

  await game.step(150);
  const { counters } = await game.stats();
  assert.ok(counters.delegate_take >= 1, "the intent was given");
  assert.ok(counters.plan_assault >= 1, "the XO planned a deliberate attack");
  const { soldiers } = await game.query("soldiers", { team: 1 });
  const fighting = soldiers.filter((s) => s.life === "ALIVE").length;
  assert.ok(fighting <= 1, `the cell is broken (${fighting} still fighting)`);
  assert.ok(counters.delegate_taken >= 1, "the XO reports the objective taken");
  ({ squads: now } = await game.query("squads", { ids }));
  const holding = now.filter((s) => s.alive > 0 && s.intent !== "");
  assert.ok(holding.length >= 1, "they're still carrying out the intent");
  for (const s of holding) {
    const off = Math.hypot(s.pos[0] - YARD.v3[0], s.pos[1] - YARD.v3[1]);
    assert.ok(off < 40, `${s.name} consolidates on the yard (${off.toFixed(0)} m off)`);
  }
});

test("squads told to hold a sector dig in across it", async () => {
  const squads = await mine();
  const rifle = squads.filter((s) => s.kind === "rifle_squad").map((s) => s.id);
  const sector = v3(30, 10);
  await game.send("order", { peer: YOU, t: "delegate", intent: "hold", squads: rifle, pos: sector, face: v3(0, -1) });
  await game.step(40);
  let { squads: now } = await game.query("squads", { ids: rifle });
  for (const s of now) {
    assert.equal(s.order, "defend", `${s.name} digs in`);
    assert.ok(Math.hypot(s.pos[0] - 30, s.pos[1] - 10) < 30, `${s.name} is in the sector`);
  }
  assert.deepEqual(now.map((s) => s.intent), ["hold", "hold"]);
});

test("ordering a delegated squad yourself takes it back, and so does Take back", async () => {
  const squads = await mine();
  const ids = squads.map((s) => s.id);
  await game.send("order", { peer: YOU, t: "delegate", intent: "reserve", squads: ids, pos: v3(0, 40) });
  await game.step(2);
  await game.send("order", { peer: YOU, t: "move", squads: [ids[0]], pos: v3(-30, 20) });
  await game.send("order", { peer: YOU, t: "take_back", squads: [ids[1]] });
  const { squads: now } = await game.query("squads", { ids });
  assert.deepEqual(now.map((s) => s.intent), ["", "", "reserve"], "the first two are yours again, the third still in reserve");
  const { counters } = await game.stats();
  assert.equal(counters.delegate_released, 2, "each was released once");
});

test("the reserve goes to help a squad that's pinned in a fight", async () => {
  const squads = await mine();
  const rifles = squads.filter((s) => s.kind === "rifle_squad").map((s) => s.id);
  const gun = squads.find((s) => s.kind === "mg_team").id;
  // one rifle squad attacks on its own (and gets stuck in); the other waits in reserve behind it
  await game.send("order", { peer: YOU, t: "delegate", intent: "reserve", squads: [rifles[1], gun], pos: v3(10, 30) });
  await game.send("order", { peer: YOU, t: "assault", squads: [rifles[0]], pos: YARD });
  await game.step(120);
  const { counters } = await game.stats();
  assert.ok(counters.delegate_reserve_committed >= 1, "the reserve was committed");
});

test("an ambush is laid where it was asked for", async () => {
  const squads = await mine();
  const rifle = squads.find((s) => s.kind === "rifle_squad").id;
  await game.send("order", { peer: YOU, t: "delegate", intent: "ambush", squads: [rifle], pos: v3(-30, -10), face: v3(1, 0) });
  await game.step(4);
  const { counters } = await game.stats();
  assert.ok(counters.ambush_set_out >= 1, "the squad set out to lay it");
  const { squads: now } = await game.query("squads", { ids: [rifle] });
  assert.equal(now[0].intent, "ambush");
});

test("an AI unit can't be delegated by the AI, nor an enemy squad by you", async () => {
  const squads = await mine();
  const { squads: enemy } = await game.query("squads", { team: 1 });
  await game.send("order", { peer: YOU, t: "delegate", intent: "hold", squads: [enemy[0].id], pos: v3(0, 0) });
  await game.send("order", { team: 0, t: "delegate", intent: "hold", squads: [squads[0].id], pos: v3(0, 0) });
  const { squads: e2 } = await game.query("squads", { ids: [enemy[0].id, squads[0].id] });
  assert.deepEqual(e2.map((s) => s.intent), ["", ""]);
});
