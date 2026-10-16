// The deliberate attack (scenario "attack"): two rifle squads and a gun team
// against a fighter cell holding a walled farmyard. Loaded with static: true
// nobody has been given orders, so these tests give them, as a commander would.

import { test } from "node:test";
import assert from "node:assert/strict";
import { Game, v3 } from "./lib/game.mjs";

const YARD = v3(-2, -42);

test("an assault on the yard is planned and carried", async () => {
  const game = await Game.start();
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
  assert.equal(await game.close(), 0);
});

test("a squad sent round the flank gets there", async () => {
  const game = await Game.start();
  await game.load({ scenario: "attack", seed: 3, static: true });
  const { squads } = await game.query("squads", { team: 0, kind: "rifle_squad" });
  const sq = squads[0];
  await game.order(0, "move", { squads: [sq.id], pos: v3(-40, 20) });
  await game.step(40);
  const { squads: after } = await game.query("squads", { ids: [sq.id] });
  const [x, z] = after[0].pos;
  const off = Math.hypot(x + 40, z - 20);
  assert.ok(off < 12, `the squad is ${off.toFixed(1)} m from where it was sent`);
  assert.equal(await game.close(), 0);
});
