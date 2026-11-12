// Play vs AI's adviser (scripts/game/adviser.gd): a new commander who sits
// still is pointed at the nearest town in the missions' lettered style, and
// told quietly when squads stand idle or supply piles up. It runs in the
// player's own view, so the test plays a skirmish (you against the AI
// commander) with play, and asks it what it's showing.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";

const ACTIVE = 1; // MissionDirector.ACTIVE

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

async function adviser() {
  return (await game.query("adviser")).adviser;
}

test("a commander who does nothing is pointed at a town, then nudged about idle squads and supply", async (t) => {
  await game.load({ skirmish: true, play: true, seed: 4 });
  await game.step(3);
  let a = await adviser();
  assert.ok(a, "Play vs AI has an adviser");
  assert.equal(a.on, true);
  assert.ok(a.objs.length >= 1 && a.objs.length <= 2, `one or two suggestions (${a.objs.length})`);
  const [first] = a.objs;
  assert.equal(first[0], "A", "lettered like a mission's");
  assert.match(first[1], /^Take the (village|town) of \S/, "it names the place");
  assert.equal(first[2], ACTIVE);
  assert.ok(Array.isArray(first[4]), "it has a place on the map, for the ring and the minimap");
  t.diagnostic(`suggests: ${a.objs.map((o) => `${o[0]} ${o[1]}`).join(" / ")}`);

  // it says nothing at once: words wait until something has gone begging a while
  assert.equal(a.word, "", "quiet at the start");

  // two minutes and more with every squad standing where it started
  const said = new Set();
  for (let i = 0; i < 20 && !(said.has("idle") && said.has("supply")); i++) {
    await game.step(10);
    a = await adviser();
    for (const k of Object.keys(a.said)) said.add(k);
    if (a.word) t.diagnostic(`t=${(await game.query("world")).t.toFixed(0)} ${a.kind}: ${a.word}`);
  }
  assert.ok(said.has("idle"), `it noticed the idle squads (said ${[...said]})`);
  assert.ok(said.has("supply"), `it noticed the supply going unspent (said ${[...said]})`);
  assert.equal(a.said.idle, 1, "and said each only once in that time");

  const { counters } = await game.stats();
  assert.ok(counters.adviser_suggest >= 1);
  assert.ok(counters.adviser_idle >= 1);
});

test("Settings > Interface > Adviser off hides it all", async () => {
  await game.load({ skirmish: true, play: true, seed: 4 });
  await game.step(3);
  assert.ok((await adviser()).objs.length >= 1);
  await game.send("console", { line: "set adviser false" });
  await game.step(2);
  const a = await adviser();
  assert.equal(a.on, false);
  assert.deepEqual(a.objs, [], "no suggestions");
  assert.equal(a.word, "", "and no words");
  await game.send("console", { line: "set adviser true" });
});

test("missions, scenarios and AI battles have none", async () => {
  await game.load({ scenario: "attack", seed: 3, play: true });
  assert.equal((await adviser()), null, "a scenario");
  await game.load({ mission: "bootcamp", play: true });
  assert.equal((await adviser()), null, "a mission");
});
