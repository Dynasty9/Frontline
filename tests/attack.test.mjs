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
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { Game, ROOT, v3 } from "./lib/game.mjs";

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

// Force a wiped squad and free its bodies before the attack ends. Survival
// now depends on tighter cover selection, so a seed is not a reliable fixture.
test("a squad lost in the middle of an attack is struck off, and the attack ends without it", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://scripts/test/wiped_squad_test.tscn",
  ], { timeout: 120_000, maxBuffer: 2 * 1024 * 1024 });
  assert.match(stdout, /WIPEDSQUAD passed/);
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|TESTRUN failed/);
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
