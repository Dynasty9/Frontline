// Command at the lowest level: standing orders for one soldier, a squad or a
// vehicle (stance, fire discipline, target priority), a vehicle's smoke on
// call, and dropping only some of the men a carrier has aboard. Every order
// goes through World.execute_cmd as a commander gives it.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game, v3 } from "./lib/game.mjs";

const HOLD = 2;
const PRONE = 1;

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

async function team0Squads() {
  const { squads } = await game.query("squads", { team: 0 });
  return squads.map((s) => s.id);
}

// "cover": a rifle squad behind a row of walls, a fighter cell 50 m off
// across the open. Left alone, both sides fire within seconds.
test("a squad told to hold fire doesn't fire back, even under fire", async () => {
  await game.load({ scenario: "cover", seed: 1 });
  await game.step(20);
  const free = (await game.stats()).counters.t0_shots ?? 0;
  assert.ok(free > 0, `at will they fire (${free} rounds)`);

  await game.load({ scenario: "cover", seed: 1 });
  const r = await game.order(0, "roe", { squads: await team0Squads(), v: HOLD });
  assert.equal(r.squads, 1, "the order reaches the squad");
  const { soldiers } = await game.query("soldiers", { team: 0 });
  assert.ok(soldiers.every((s) => s.roe === HOLD), "every man has it");
  await game.step(20);
  const { counters } = await game.stats();
  assert.ok((counters.t1_shots ?? 0) > 0, "the enemy fired on them");
  assert.equal(counters.t0_shots ?? 0, 0, "they didn't fire a round back");
  assert.equal(counters.frag_auto ?? 0, 0, "nor throw a grenade");
});

test("return fire: they hold until they're shot at, then answer", async () => {
  await game.load({ scenario: "cover", seed: 1 });
  const { squads: cells } = await game.query("squads", { team: 1 });
  await game.order(0, "roe", { squads: await team0Squads(), v: 1 });
  await game.order(1, "roe", { squads: cells.map((s) => s.id), v: HOLD });
  await game.step(15);
  let { counters } = await game.stats();
  assert.equal(counters.t0_shots ?? 0, 0, "nobody shot at them, so they didn't start it");

  await game.order(1, "roe", { squads: cells.map((s) => s.id), v: 0 });
  await game.step(15);
  ({ counters } = await game.stats());
  assert.ok((counters.t1_shots ?? 0) > 0, "the enemy opened fire");
  assert.ok((counters.t0_shots ?? 0) > 0, "and they fired back");
});

test("men holding their fire still fight when they're overrun", async () => {
  await game.load({ scenario: "attack", seed: 3, static: true });
  await game.order(0, "roe", { squads: await team0Squads(), v: HOLD });
  const { squads } = await game.query("squads", { team: 0 });
  const [x, z] = squads[0].pos;
  // the fighter cell comes for them
  const { squads: cells } = await game.query("squads", { team: 1 });
  await game.order(1, "assault", { squads: cells.map((s) => s.id), pos: v3(x, z) });
  await game.step(60);
  const { counters } = await game.stats();
  assert.ok((counters.t0_shots ?? 0) > 0, "they opened fire once the enemy was on top of them");
});

test("one soldier told to get down lies down; the rest of his squad don't", async () => {
  await game.load({ scenario: "attack", seed: 3, static: true });
  const { soldiers } = await game.query("soldiers", { team: 0, kind: "rifleman" });
  const man = soldiers[0];
  await game.order(0, "stance", { soldier: man.id, v: PRONE });
  await game.step(4);
  const { soldiers: after } = await game.query("soldiers", { team: 0 });
  const him = after.find((s) => s.id === man.id);
  assert.equal(him.stance, PRONE, "he has the order");
  assert.equal(him.posture, "PRONE", "and is lying down");
  const mates = after.filter((s) => s.squad === man.squad && s.id !== man.id);
  assert.ok(mates.every((s) => s.stance === 0), "his mates keep their own judgement");
  assert.equal(him.task, "", "he stays in his squad's formation (no task of his own)");
});

test("a tank told to hold fire holds it; fire at will, it shoots", async () => {
  await game.load({ scenario: "tank", seed: 1 });
  const [tank] = (await game.query("vehicles", { team: 0, kind: "tank" })).vehicles;
  await game.order(0, "stop", { vehicles: [tank.id] });
  const r = await game.order(0, "roe", { vehicles: [tank.id], v: HOLD });
  assert.equal(r.vehicles, 1);
  await game.step(20);
  let { counters } = await game.stats();
  assert.equal(counters.t0_shots ?? 0, 0, "no machine-gun rounds");
  assert.equal(counters.cannon ?? 0, 0, "no main-gun rounds");
  assert.ok((counters.veh_held_fire ?? 0) > 0, "though it had a target");

  await game.order(0, "roe", { vehicles: [tank.id], v: 0 });
  await game.step(15);
  ({ counters } = await game.stats());
  assert.ok((counters.t0_shots ?? 0) + (counters.cannon ?? 0) > 0, "weapons free, it opens up");
});

test("a vehicle's smoke goes up when called, and it remembers its target priority", async () => {
  await game.load({ scenario: "tank", seed: 1 });
  const [tank] = (await game.query("vehicles", { team: 0, kind: "tank" })).vehicles;
  await game.order(0, "pop_smoke", { vehicles: [tank.id] });
  await game.order(0, "prio", { vehicles: [tank.id], v: 1 });
  await game.step(1);
  const [after] = (await game.query("vehicles", { ids: [tank.id] })).vehicles;
  assert.equal(after.smoke, tank.smoke - 1, "a salvo gone from the dischargers");
  assert.equal(after.prio, 1, "armour first");
  const { counters } = await game.stats();
  assert.equal(counters.veh_smoke_ordered, 1);
});

test("a carrier drops some of its men, or one squad of two, and keeps the rest", async () => {
  await game.load({ scenario: "mounted", seed: 1, static: true });
  const { vehicles } = await game.query("vehicles", { team: 0, kind: "ifv" });
  const [one, two] = vehicles.sort((a, b) => a.pos[0] - b.pos[0]);
  assert.equal(one.passengers, 4);
  assert.equal(two.pax.length, 2, "the second carries two squads");

  await game.order(0, "dismount", { vehicles: [one.id], n: 2 });
  await game.step(6);
  let [v1] = (await game.query("vehicles", { ids: [one.id] })).vehicles;
  assert.equal(v1.passengers, 2, "two got out and two stayed aboard");
  const sid = v1.pax[0][0];
  const { soldiers } = await game.query("soldiers", { team: 0 });
  const squad = soldiers.filter((s) => s.squad === sid);
  assert.equal(squad.filter((s) => s.riding === 0 && s.life === "ALIVE").length, 2, "two of the squad on the ground");

  const [atSid] = two.pax[1];
  await game.order(0, "dismount", { vehicles: [two.id], squad: atSid });
  await game.step(6);
  const [v2] = (await game.query("vehicles", { ids: [two.id] })).vehicles;
  assert.deepEqual(v2.pax.map((p) => p[0]), [two.pax[0][0]], "only the other squad is still aboard");

  await game.order(0, "dismount", { vehicles: [one.id] });
  await game.step(2);
  [v1] = (await game.query("vehicles", { ids: [one.id] })).vehicles;
  assert.equal(v1.passengers, 0, "and the rest when told");
});
