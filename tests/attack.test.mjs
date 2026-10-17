// The deliberate attack (scenario "attack"): two rifle squads and a gun team
// against a fighter cell holding a walled farmyard. Loaded with static: true
// nobody has been given orders, so these tests give them, as a commander would.
//
// One game serves the whole file: each test loads a fresh battle into it (a
// seed replays the same fight in any game, so the tests don't depend on each
// other or on their order), and its exit code at the end says whether any of
// them hit a script error.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game, v3 } from "./lib/game.mjs";

const YARD = v3(-2, -42);

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

test("an assault on the yard is planned and carried", async () => {
  await game.load({ scenario: "attack", seed: 3, static: true });
  const { squads } = await game.query("squads", { team: 0 });
  const r = await game.order(0, "assault", { squads: squads.map((s) => s.id), pos: YARD, face: v3(0, -1) });
  assert.equal(r.squads, 3, "the order reaches all three");

  await game.step(60);
  const { counters } = await game.stats();
  assert.ok(counters.plan_assault >= 1, "they made a plan of attack");
  assert.ok(counters.t0_hits > 0, "and hit the enemy");
  const { soldiers } = await game.query("soldiers", { team: 1 });
  const fighting = soldiers.filter((s) => s.life === "ALIVE").length;
  assert.ok(fighting <= 2, `the cell is broken (${fighting} of 6 still fighting)`);
});

// With seed 2 the assault goes firm against the yard, and one rifle squad is
// whittled away (its last man joins the squad beside it) before the attack is
// called off. A squad struck off like that used to keep its dead and its place
// in the attack, and the attack's end ordered it with the rest: in an attack
// that dragged on until their bodies had been cleared away and freed (nine
// minutes), that reached into freed men and crashed the game. No scenario's
// attack lasts that long, so this follows the path rather than the crash: the
// squad is struck off mid-attack, and the attack ends without it, cleanly.
test("a squad lost in the middle of an attack is struck off, and the attack ends without it", async () => {
  await game.load({ scenario: "attack", seed: 2, static: true });
  const { squads } = await game.query("squads", { team: 0 });
  await game.order(0, "assault", { squads: squads.map((s) => s.id), pos: YARD, face: v3(0, -1) });

  let lostAt = -1;
  let endedAt = -1;
  for (let t = 5; t <= 150 && endedAt < 0; t += 5) {
    await game.step(5);
    const { counters } = await game.stats();
    if (lostAt < 0 && counters.plan_squad_lost >= 1) lostAt = t;
    if (counters.plan_failed >= 1 || counters.plan_won >= 1) endedAt = t;
  }
  assert.ok(lostAt > 0, "a squad was lost while the attack was on");
  assert.ok(endedAt >= lostAt, `the attack ended after it (lost by ${lostAt} s, ended by ${endedAt} s)`);
  const { squads: left } = await game.query("squads", { team: 0 });
  assert.equal(left.length, squads.length - 1, "the lost squad is struck off");
  assert.equal(game.errors, 0, "and nothing touched it afterwards");
});

test("a squad sent round the flank gets there", async () => {
  await game.load({ scenario: "attack", seed: 3, static: true });
  const { squads } = await game.query("squads", { team: 0, kind: "rifle_squad" });
  const sq = squads[0];
  await game.order(0, "move", { squads: [sq.id], pos: v3(-40, 20) });
  await game.step(40);
  const { squads: moved } = await game.query("squads", { ids: [sq.id] });
  const [x, z] = moved[0].pos;
  const off = Math.hypot(x + 40, z - 20);
  assert.ok(off < 12, `the squad is ${off.toFixed(1)} m from where it was sent`);
});
