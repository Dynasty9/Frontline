// Dugouts in the trench scenario's Rebel line: shelled, a squad holding the
// line goes down its dugout, leaving a sentry on the parapet, and stands to
// when the barrage lifts or the enemy comes on.
//
// One game serves the file; each test loads a fresh, seeded battle into it.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game, v3 } from "./lib/game.mjs";

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

// Mortar rounds on each Rebel squad holding the front line (an observer's
// demonstration barrage: no side fired it, so nobody is coming after it).
async function shellTheLine() {
  const { squads } = await game.query("squads", { team: 1 });
  const line = squads.filter((s) => s.order === "defend" && s.pos && Math.abs(s.pos[1] + 28) < 14);
  assert.ok(line.length >= 2, `squads hold the front line (${line.length})`);
  for (const sq of line) {
    await game.order(1, "demo_support", { peer: 1, kind: "mortars", pos: v3(sq.pos[0] + 6, sq.pos[1] - 14) });
  }
  return line;
}

test("a squad told to hold the trench line mans its fire steps", async () => {
  await game.load({ scenario: "trenches", seed: 3, static: true });
  await game.step(10);
  const { soldiers } = await game.query("soldiers", { team: 1 });
  const riflemen = soldiers.filter((s) => s.life === "ALIVE" && s.task === "");
  const down = riflemen.filter((s) => s.in_trench);
  assert.ok(down.length >= riflemen.length - 1, `${down.length} of ${riflemen.length} are down in the trench`);
});

test("shelled, a squad goes down its dugout and stands to when the barrage lifts", async () => {
  await game.load({ scenario: "trenches", seed: 3, static: true });
  await game.step(8);
  await shellTheLine();
  await game.step(14);
  let { counters } = await game.stats();
  assert.ok(counters.dugout_shelter >= 1, `a squad took shelter (${counters.dugout_shelter ?? 0})`);
  assert.ok(counters.dugout_in >= 2, `men went down the stairs (${counters.dugout_in ?? 0})`);
  const { squads } = await game.query("squads", { team: 1 });
  const below = squads.filter((s) => s.drill === "dugout");
  assert.ok(below.length >= 1, "a squad is sheltering");
  const { soldiers } = await game.query("soldiers", { team: 1 });
  for (const sq of below) {
    const men = soldiers.filter((s) => s.squad === sq.id && s.life !== "DEAD");
    const up = men.filter((s) => s.life === "ALIVE" && s.task !== "dugout");
    assert.ok(up.length >= 1, `${sq.name} leaves a sentry up`);
    assert.ok(men.some((s) => s.life === "HIDDEN" || s.task === "dugout"), `${sq.name} has men below or on the stairs`);
  }

  // the barrage ends: they come back up and man the line again
  await game.step(40);
  ({ counters } = await game.stats());
  assert.ok(counters.stand_to >= 1, "they stood to");
  const after = await game.query("soldiers", { team: 1 });
  const hidden = after.soldiers.filter((s) => s.life === "HIDDEN");
  assert.equal(hidden.length, 0, "nobody is left below");
  // (a squad with no dugout in reach moves out of the shellfire instead)
  const { squads: back } = await game.query("squads", { ids: below.map((s) => s.id) });
  for (const sq of back) {
    assert.notEqual(sq.drill, "dugout", `${sq.name} is out of the dugout`);
    assert.equal(sq.order, "defend", `${sq.name} holds the line again (${sq.order}/${sq.drill} at ${sq.pos})`);
  }
});

test("an order calls the men up out of the dugout", async () => {
  await game.load({ scenario: "trenches", seed: 3, static: true });
  await game.step(8);
  await shellTheLine();
  await game.step(14);
  const { squads } = await game.query("squads", { team: 1 });
  const sq = squads.find((s) => s.drill === "dugout");
  assert.ok(sq, "a squad is sheltering");
  const r = await game.order(1, "move", { squads: [sq.id], pos: v3(sq.pos[0], sq.pos[1] - 30) });
  assert.equal(r.squads, 1);
  await game.step(2);
  const { soldiers } = await game.query("soldiers", { team: 1 });
  const men = soldiers.filter((s) => s.squad === sq.id && s.life !== "DEAD");
  assert.ok(men.every((s) => s.life !== "HIDDEN"), "everyone came up");
  assert.ok(men.filter((s) => s.life === "ALIVE").length >= 2, "and they are moving off");
});

test("sent below by its commander, a squad stays down until ordered out", async () => {
  await game.load({ scenario: "trenches", seed: 3, static: true });
  await game.step(10);
  // find a dugout the way a player would: shell a squad, note where it goes, then try again by order
  await shellTheLine();
  await game.step(14);
  const { squads } = await game.query("squads", { team: 1 });
  const sq = squads.find((s) => s.drill === "dugout");
  assert.ok(sq, "a squad found a dugout");
  const { structures } = await game.query("structures", { kind: "trench" });
  // order it out, wait for the shelling to end, then send it back down by hand
  await game.order(1, "defend", { squads: [sq.id], pos: v3(sq.pos[0], sq.pos[1]), face: v3(0, 1) });
  await game.step(30);
  let entered = 0;
  for (const st of structures) {
    await game.order(1, "enter", { squads: [sq.id], target: st.id });
    await game.step(0.5);
    const { squads: now } = await game.query("squads", { ids: [sq.id] });
    if (now[0].drill === "dugout") {
      entered = st.id;
      break;
    }
  }
  assert.ok(entered, "an enter order on a dugout section sends it below");
  await game.step(40);
  const { squads: still } = await game.query("squads", { ids: [sq.id] });
  assert.equal(still[0].drill, "dugout", "with no shells falling it stays below");
  await game.order(1, "move", { squads: [sq.id], pos: v3(sq.pos[0], sq.pos[1] - 20) });
  await game.step(2);
  const { soldiers } = await game.query("soldiers", { team: 1 });
  assert.ok(soldiers.filter((s) => s.squad === sq.id).every((s) => s.life !== "HIDDEN"), "an order brings them up");
});
